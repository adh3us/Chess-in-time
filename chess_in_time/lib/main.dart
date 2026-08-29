import 'package:flutter/material.dart';
import 'chess_game_screen.dart';
import 'supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ChessInTimeApp());
}

class ChessInTimeApp extends StatelessWidget {
  const ChessInTimeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess in Time',
      home: const ChessGameScreen(),
    );
  }
}
