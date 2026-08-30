import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Conexión a Supabase (Fase 5)
///
/// Mismo proyecto Supabase que usa Gameros (login compartido vía
/// auth.users), pero Chess in Time vive en su propio esquema de Postgres
/// (`chess_in_time`), separado de `public`. Acá solo se usa la anon key —
/// nunca la service_role — porque la seguridad real la da el RLS
/// (Row Level Security) configurado en cada tabla, no la clave en sí.
/// La anon key está pensada para vivir en el cliente, no es un secreto
/// como la service_role.
///
/// El manejo del "volver" del login de Google (el deep link
/// io.supabase.chessintime://login-callback) se hace a mano acá, con
/// detectSessionInUri desactivado: el paquete de Supabase lo maneja
/// automático por default, pero si el intercambio de sesión falla, el
/// error queda solo en un log interno que Lucas no puede ver -- por eso
/// se reportó "el login no hace nada" sin ninguna pista de qué pasó
/// realmente. Acá cualquier error queda visible en pantalla.
/// ---------------------------------------------------------------------------

const String supabaseUrl = 'https://bgwvtfgwhpinfotzyucn.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnd3Z0Zmd3aHBpbmZvdHp5dWNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3OTgyMTAsImV4cCI6MjEwMjM3NDIxMH0.P1j452eng44SBVn6uAJpWvkrqcEV3WNPIGATa6VhZAk';

/// Clave global del ScaffoldMessenger de la app, para poder mostrar un
/// SnackBar con el error del login sin importar en qué pantalla esté
/// el usuario cuando el navegador vuelve a la app.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  _listenForAuthDeepLinks();
}

SupabaseClient get supabase => Supabase.instance.client;

void _listenForAuthDeepLinks() {
  final appLinks = AppLinks();

  Future<void> handle(Uri? uri) async {
    if (uri == null || uri.scheme != 'io.supabase.chessintime') return;
    try {
      await supabase.auth.getSessionFromUrl(uri);
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('No se pudo completar el login: $e'), duration: const Duration(seconds: 8)),
      );
    }
  }

  appLinks.getInitialLink().then(handle);
  appLinks.uriLinkStream.listen(handle);
}
