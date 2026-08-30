import 'fischer_clock.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 5: capa de datos para partidas online
///
/// Todo lo que toca la base pasa por acá: buscar rival, salir de la cola,
/// guardar el estado de una jugada, y cerrar la partida (ELO). Nada de UI.
/// ---------------------------------------------------------------------------

/// Las mismas 4 modalidades de fischer_clock.dart, pero con la clave de texto
/// que usa la base (`chess_in_time.partidas.modalidad`).
const Map<String, ClockModality> onlineModalidades = {
  'bullet': ClockModality.bullet,
  'blitz': ClockModality.blitz,
  'rapida': ClockModality.rapida,
  'clasica': ClockModality.clasica,
};

String modalidadKey(ClockModality m) =>
    onlineModalidades.entries.firstWhere((e) => e.value == m).key;

/// Llama a chess_in_time.buscar_partida(modalidad). Si había alguien
/// esperando, devuelve la partida ya armada (con los dos jugadores); si no,
/// deja al que llama en la cola y devuelve null -- hay que esperar a que
/// Realtime avise cuando otro jugador arme la partida.
Future<Map<String, dynamic>?> buscarPartida(String modalidad) async {
  final result = await supabase
      .schema('chess_in_time')
      .rpc('buscar_partida', params: {'p_modalidad': modalidad});
  if (result == null) return null;
  final partida = Map<String, dynamic>.from(result as Map);
  // Cuando la función SQL no encuentra rival, "no hay partida" a veces
  // viaja como una fila con todos los campos en null (en vez de un null
  // limpio) -- lo tratamos igual que un null real, si no el resto del
  // código intenta armar una partida vacía y revienta al leer el id.
  if (partida['id'] == null) return null;
  return partida;
}

Future<void> cancelarBusqueda() async {
  await supabase.schema('chess_in_time').rpc('cancelar_busqueda');
}

/// Fase 6: arma (o engancha con la ya armada por el rival) la partida para
/// un cruce puntual de torneo de Gameros -- a diferencia de buscarPartida(),
/// acá los dos jugadores ya están decididos de antemano por el bracket, no
/// hay cola ni azar de rival.
Future<Map<String, dynamic>> iniciarPartidaTorneo({
  required String torneoPartidaId,
  required String rivalUsuarioId,
  required String inscPropia,
  required String inscRival,
  required String tipoLlave,
}) async {
  final result = await supabase.schema('chess_in_time').rpc('iniciar_partida_torneo', params: {
    'p_torneo_partida_id': torneoPartidaId,
    'p_rival_usuario_id': rivalUsuarioId,
    'p_insc_propia': inscPropia,
    'p_insc_rival': inscRival,
    'p_tipo_llave': tipoLlave,
  });
  return Map<String, dynamic>.from(result as Map);
}

/// Fase 6: si `partida` viene de un cruce de torneo (torneo_partida_id no
/// nulo), reporta el resultado de vuelta a Gameros con la misma función que
/// ya usa el organizador/árbitro -- ahora también acepta la carga si viene
/// de uno de los dos jugadores Y existe esta partida ya terminada con un
/// resultado que coincide (ver chess_in_time_resultado_verificado en el
/// backend de Gameros). Si `partida` es de matchmaking libre (sin torneo),
/// no hace nada.
///
/// Se llama solo desde el cliente cuyo cerrarPartida() recién tuvo éxito --
/// el otro lado, que la encuentra ya terminada por polling, nunca reporta,
/// así evitamos una carrera de los dos reportando el mismo cruce a la vez.
Future<void> reportarResultadoTorneo(Map<String, dynamic> partida, String? ganadorUsuarioId) async {
  final torneoPartidaId = partida['torneo_partida_id'] as String?;
  if (torneoPartidaId == null) return;

  final tipoLlave = partida['torneo_tipo_llave'] as String;
  final inscBlancas = partida['torneo_insc_blancas'] as String;
  final inscNegras = partida['torneo_insc_negras'] as String;
  final blancas = partida['jugador_blancas'] as String;

  final String? inscGanador =
      ganadorUsuarioId == null ? null : (ganadorUsuarioId == blancas ? inscBlancas : inscNegras);

  if (tipoLlave == 'eliminacion_directa' || tipoLlave == 'eliminacion_doble') {
    // No hay tablas en estos dos formatos -- si empataron, no hay forma de
    // cargar ese resultado todavía (hace falta desempate, ver charla con Lucas).
    if (inscGanador == null) return;
    final rpc = tipoLlave == 'eliminacion_directa' ? 'cargar_resultado' : 'cargar_resultado_doble';
    await supabase.rpc(rpc, params: {'p_partida_id': torneoPartidaId, 'p_ganador_inscripcion_id': inscGanador});
    return;
  }

  // Sistema Suizo / Todos contra Todos: la función de Gameros pide
  // 'gana_a'/'gana_b'/'empate' relativo a inscripcion_a_id del cruce, no a
  // blancas/negras de acá -- hay que consultar cuál es cuál.
  final torneoPartida =
      await supabase.from('partidas').select('inscripcion_a_id').eq('id', torneoPartidaId).single();
  final esGanadorA = inscGanador != null && inscGanador == torneoPartida['inscripcion_a_id'];
  final resultado = inscGanador == null ? 'empate' : (esGanadorA ? 'gana_a' : 'gana_b');
  final rpc = tipoLlave == 'sistema_suizo' ? 'cargar_resultado_suizo' : 'cargar_resultado_todos_contra_todos';
  await supabase.rpc(rpc, params: {'p_partida_id': torneoPartidaId, 'p_resultado': resultado});
}

/// Guarda el estado de la partida después de una jugada propia: posición,
/// historial (en notación UCI, separado por espacios), de quién es el turno
/// y cuánto tiempo le queda a cada uno.
Future<void> actualizarPartida({
  required String partidaId,
  required String currentFen,
  required String pgnMoves,
  required String turnColor,
  required int tiempoBlancasMs,
  required int tiempoNegrasMs,
}) async {
  await supabase.schema('chess_in_time').from('partidas').update({
    'current_fen': currentFen,
    'pgn_moves': pgnMoves,
    'turn_color': turnColor,
    'tiempo_restante_blancas_ms': tiempoBlancasMs,
    'tiempo_restante_negras_ms': tiempoNegrasMs,
  }).eq('id', partidaId);
}

/// Cierra la partida (motivo + ganador opcional) y dispara la actualización
/// de ELO del lado del servidor. Falla (a propósito) si la partida ya estaba
/// terminada -- por ejemplo si los dos clientes detectan el mismo final casi
/// al mismo tiempo -- así que el que llama debe ignorar ese error puntual.
Future<void> cerrarPartida({
  required String partidaId,
  required String motivo,
  String? ganador,
}) async {
  await supabase.schema('chess_in_time').rpc('cerrar_partida', params: {
    'p_partida_id': partidaId,
    'p_motivo': motivo,
    'p_ganador': ganador,
  });
}

/// El rating (por modalidad) del jugador logueado, para mostrar en "Mi
/// cuenta". Devuelve una fila por modalidad en la que ya jugó al menos una
/// partida cerrada -- si nunca jugó ninguna, la lista viene vacía (todavía
/// no tiene fila propia en `ratings`, arranca en 1200 recién con la primera).
Future<List<Map<String, dynamic>>> misRatings() async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final result = await supabase
      .schema('chess_in_time')
      .from('ratings')
      .select()
      .eq('jugador', uid)
      .order('modalidad');
  return List<Map<String, dynamic>>.from(result as List);
}

/// Trae el estado actual de una partida puntual. Se usa para refrescar por
/// polling (cada 2 segundos, ver OnlineLobbyScreen/OnlineGameScreen) en vez
/// de Realtime -- más simple y usa el mismo camino REST que ya funciona para
/// todo lo demás (ratings, buscar_partida), sin depender de un WebSocket.
Future<Map<String, dynamic>?> obtenerPartida(String partidaId) async {
  final result = await supabase
      .schema('chess_in_time')
      .from('partidas')
      .select()
      .eq('id', partidaId)
      .maybeSingle();
  if (result == null) return null;
  return Map<String, dynamic>.from(result);
}

/// ---------------------------------------------------------------------------
/// Fase 7: partidas privadas (invitar a un amigo)
///
/// Un tercer camino además del matchmaking libre y las partidas de torneo:
/// acá los dos jugadores se conocen y quedan en jugar, así que en vez de
/// emparejar al azar arman juntos una sala con un código para compartir.
/// ---------------------------------------------------------------------------

/// Crea una sala privada. `modalidad` puede ser null -- significa "sin
/// reloj" (ver sin_reloj en chess_in_time.partidas).
Future<Map<String, dynamic>> crearSalaPrivada(String? modalidad) async {
  final result = await supabase
      .schema('chess_in_time')
      .rpc('crear_sala_privada', params: {'p_modalidad': modalidad});
  return Map<String, dynamic>.from(result as Map);
}

/// Se une a una sala por código (no hace falta que la sala ya te conozca
/// como participante -- por eso es una función aparte y no un simple select,
/// ver la nota de RLS en 007_salas_privadas.sql).
Future<Map<String, dynamic>> unirseSalaPrivada(String codigo) async {
  final result = await supabase
      .schema('chess_in_time')
      .rpc('unirse_sala_privada', params: {'p_codigo': codigo});
  return Map<String, dynamic>.from(result as Map);
}

/// Estado actual de la sala, para el polling y el botón "Actualizar" de
/// SalaLobbyScreen.
Future<Map<String, dynamic>?> obtenerSalaPrivada(String salaId) async {
  final result = await supabase
      .schema('chess_in_time')
      .from('salas_privadas')
      .select()
      .eq('id', salaId)
      .maybeSingle();
  if (result == null) return null;
  return Map<String, dynamic>.from(result);
}

/// Arma la partida de la sala (una vez que los dos están adentro). Si el
/// rival ya la arrancó primero, devuelve la misma en vez de crear otra.
Future<Map<String, dynamic>> iniciarPartidaPrivada(String salaId) async {
  final result = await supabase
      .schema('chess_in_time')
      .rpc('iniciar_partida_privada', params: {'p_sala_id': salaId});
  return Map<String, dynamic>.from(result as Map);
}
