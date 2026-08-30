import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'chess_game_screen.dart';
import 'supabase_config.dart';

/// En release, un error sin capturar durante el armado de una pantalla se ve
/// como un cuadro gris liso -- Flutter oculta el detalle a propósito para no
/// mostrarle una traza interna al usuario. Sin esto, esos errores quedan sin
/// ninguna pista de qué pasó realmente (mismo problema que tuvimos con el
/// login antes de agregarle el SnackBar de error).
void _reportFatalError(Object error, [StackTrace? stack]) {
  debugPrint('Error no manejado: $error\n$stack');
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text('Error: $error'), duration: const Duration(seconds: 10)),
  );
}

/// Fase 6: deep link de un cruce de torneo de Gameros
/// (io.supabase.chessintime://torneo?partida=...&rival=...&insc_propia=...
/// &insc_rival=...&tipo=...) -- lo abre Gameros desde el botón "Jugar en
/// Chess in Time" en la pantalla del torneo. Si falta algún parámetro (link
/// corrupto o de una versión vieja de Gameros), se ignora en vez de reventar.
void _handleTorneoDeepLink(Uri uri) {
  final params = uri.queryParameters;
  final torneoPartidaId = params['partida'];
  final rivalUsuarioId = params['rival'];
  final inscPropia = params['insc_propia'];
  final inscRival = params['insc_rival'];
  final tipoLlave = params['tipo'];
  if (torneoPartidaId == null || rivalUsuarioId == null || inscPropia == null || inscRival == null || tipoLlave == null) {
    return;
  }
  rootNavigatorKey.currentState?.push(MaterialPageRoute(
    builder: (_) => TorneoMatchScreen(
      torneoPartidaId: torneoPartidaId,
      rivalUsuarioId: rivalUsuarioId,
      inscPropia: inscPropia,
      inscRival: inscRival,
      tipoLlave: tipoLlave,
    ),
  ));
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initSupabase(onTorneoDeepLink: _handleTorneoDeepLink);
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        _reportFatalError(details.exception, details.stack);
      };
      runApp(const ChessInTimeApp());
    },
    (error, stack) => _reportFatalError(error, stack),
  );
}

class ChessInTimeApp extends StatelessWidget {
  const ChessInTimeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess in Time',
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      // Fase 7: login obligatorio como primera pantalla -- ver auth_gate.dart.
      home: const AuthGate(),
    );
  }
}
