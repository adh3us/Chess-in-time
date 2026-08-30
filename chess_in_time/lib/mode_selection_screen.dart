import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'chess_game_screen.dart';
import 'equipos_screen.dart';
import 'fischer_clock.dart';
import 'private_match_screen.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 7: pantalla de modos (offline/online)
///
/// Primera pantalla después de loguearse (login ahora obligatorio, ver
/// auth_gate.dart) -- reemplaza al viejo selector de modalidad como punto de
/// entrada de la app. Ese selector no desaparece: ahora vive adentro de
/// "Multijugador" (pasa y juega local), que sigue siendo exactamente igual.
/// ---------------------------------------------------------------------------
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  void _abrir(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess in Time'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Mi cuenta',
            onPressed: () => _abrir(context, const AccountScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Offline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.psychology_alt),
              title: const Text('Jugar solo'),
              subtitle: const Text('Tablero libre, sin reloj ni rival -- para practicar.'),
              onTap: () => _abrir(context, const SoloBoardScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_alt),
              title: const Text('Multijugador'),
              subtitle: const Text('Pasa y juega, los dos en el mismo dispositivo.'),
              onTap: () => _abrir(context, const ChessGameScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Online', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Con la misma cuenta de Gameros.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.public),
              title: const Text('Ranked 1v1'),
              subtitle: const Text('Matchmaking automático, con ELO propio.'),
              children: ClockModality.all
                  .map((m) => ListTile(
                        title: Text(m.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrir(context, OnlineLobbyScreen(modality: m)),
                      ))
                  .toList(),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Partida privada'),
              subtitle: const Text('Invitá a un amigo y acuerden el reloj antes de arrancar.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir(context, const PrivateMatchScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Equipos'),
              subtitle: const Text('Varios jugadores por lado, se suman los resultados.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir(context, const EquiposScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
