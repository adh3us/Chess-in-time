import 'dart:async';
import 'package:flutter/material.dart';
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

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initSupabase();
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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: const ChessGameScreen(),
    );
  }
}
