import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 6: heredar el perfil de Gameros
///
/// Gameros guarda el perfil de cada usuario en `public.usuarios` (username,
/// nombre para mostrar, foto), separado de `auth.users` -- Chess in Time no
/// tiene su propio sistema de perfiles, lee directo de ahí. Como comparten
/// el mismo proyecto Supabase y el mismo usuario logueado, no hace falta
/// ningún cambio de backend para esto: alcanza con `public`, que ya está
/// expuesto por default (a diferencia de `chess_in_time`, que hubo que
/// habilitar a mano).
/// ---------------------------------------------------------------------------

class GamerosProfile {
  final String id;
  final String? username;
  final String? nombreDisplay;
  final String? fotoUrl;
  const GamerosProfile({required this.id, this.username, this.nombreDisplay, this.fotoUrl});

  /// El nombre a mostrar: preferí el nombre público, si no hay usá el
  /// username, y si tampoco existe (nunca completó su perfil de Gameros)
  /// devolvé null para que quien llama decida el respaldo (ej: el email).
  String? get nombreParaMostrar {
    if (nombreDisplay != null && nombreDisplay!.trim().isNotEmpty) return nombreDisplay;
    if (username != null && username!.trim().isNotEmpty) return username;
    return null;
  }
}

/// Perfil de Gameros de un usuario puntual. Devuelve null si todavía no
/// completó su perfil en Gameros (usuario nuevo, o logueado solo en Chess
/// in Time) -- en ese caso quien llama debe mostrar un respaldo razonable
/// (el email, por ejemplo), nunca fallar.
Future<GamerosProfile?> obtenerPerfilGameros(String userId) async {
  try {
    final result = await supabase
        .from('usuarios')
        .select('id, username, nombre_display, foto_url')
        .eq('id', userId)
        .maybeSingle();
    if (result == null) return null;
    return GamerosProfile(
      id: result['id'] as String,
      username: result['username'] as String?,
      nombreDisplay: result['nombre_display'] as String?,
      fotoUrl: result['foto_url'] as String?,
    );
  } catch (_) {
    // Si el RLS de Gameros no deja leer el perfil de otro usuario (por
    // ejemplo, el rival en una partida online), no debe romper la pantalla
    // -- simplemente no se muestra nombre/foto heredados para ese caso.
    return null;
  }
}
