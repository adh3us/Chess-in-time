import 'package:supabase_flutter/supabase_flutter.dart';
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
  return Map<String, dynamic>.from(result as Map);
}

Future<void> cancelarBusqueda() async {
  await supabase.schema('chess_in_time').rpc('cancelar_busqueda');
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

/// Suscripción a los cambios de una partida puntual (INSERT para cuando te
/// emparejan mientras esperás, UPDATE para las jugadas del rival).
RealtimeChannel suscribirsePartida({
  required String channelName,
  required PostgresChangeEvent event,
  String? partidaId,
  required void Function(Map<String, dynamic> row) onChange,
}) {
  final channel = supabase.channel(channelName);
  channel.onPostgresChanges(
    event: event,
    schema: 'chess_in_time',
    table: 'partidas',
    filter: partidaId == null
        ? null
        : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: partidaId),
    callback: (payload) => onChange(payload.newRecord),
  );
  channel.subscribe();
  return channel;
}
