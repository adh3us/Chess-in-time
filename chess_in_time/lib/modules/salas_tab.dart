import 'package:flutter/material.dart';
import '../private_match_screen.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Salas (Estilo Clash Royale)
///
/// Integrado con el sistema de salas de Gameros: lo que muestra y crea
/// Gameros para Chess in Time se refleja en el juego y viceversa.
/// Conecta con el sistema de salas privadas de la Fase 7 (crear sala con código,
/// unirse con código, invitar amigos o jugar sin reloj).
/// ---------------------------------------------------------------------------
class SalasTab extends StatelessWidget {
  const SalasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    size: 64,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Salas Privadas',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Crea una sala personalizada o únete con un código de invitación.\n'
                  'Totalmente integrado con Gameros: partidas sincronizadas entre ambas plataformas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CrearSalaScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: const Text('Crear Sala', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2DD4BF),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const UnirseSalaScreen()),
                          );
                        },
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text('Unirse a Sala', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueGrey.shade800),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded, color: Color(0xFF2DD4BF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Sincronizado con esquema chess_in_time.salas_privadas',
                        style: TextStyle(
                          color: Colors.blueGrey.shade300,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
