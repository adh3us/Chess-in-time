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

/// Clave global del Navigator, para poder abrir una pantalla nueva (Fase 6:
/// deep link de un cruce de torneo de Gameros) sin importar en qué pantalla
/// esté el usuario en ese momento -- mismo motivo que rootScaffoldMessengerKey.
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> initSupabase({void Function(Uri uri)? onTorneoDeepLink}) async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  _listenForAuthDeepLinks(onTorneoDeepLink: onTorneoDeepLink);
}

SupabaseClient get supabase => Supabase.instance.client;

void _listenForAuthDeepLinks({void Function(Uri uri)? onTorneoDeepLink}) {
  final appLinks = AppLinks();

  Future<void> handle(Uri? uri) async {
    if (uri == null || uri.scheme != 'io.supabase.chessintime') return;
    // Fase 6: el mismo esquema también trae el deep link de un cruce de
    // torneo de Gameros (io.supabase.chessintime://torneo?...) -- se
    // distingue por el host, y no tiene nada que ver con el login.
    if (uri.host == 'torneo') {
      onTorneoDeepLink?.call(uri);
      return;
    }
    // Justo al volver del navegador puede haber un corte de red de un
    // instante (reconexión de WiFi, etc.). AuthRetryableFetchException es
    // la forma en que Supabase marca ese tipo de error de red como algo
    // que vale la pena reintentar, a diferencia de un error real de auth.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await supabase.auth.getSessionFromUrl(uri);
        return;
      } on AuthRetryableFetchException {
        if (attempt == maxAttempts) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo conectar para completar el login. Revisá tu conexión a internet y probá de nuevo.',
              ),
              duration: Duration(seconds: 8),
            ),
          );
          return;
        }
        await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('No se pudo completar el login: $e'), duration: const Duration(seconds: 8)),
        );
        return;
      }
    }
  }

  appLinks.getInitialLink().then(handle);
  appLinks.uriLinkStream.listen(handle);
}
