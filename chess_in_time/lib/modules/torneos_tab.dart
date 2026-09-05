import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Torneos (Estilo Clash Royale)
///
/// Integrado con el sistema de torneos de Gameros (public.torneos).
/// Lo que muestra y crea Gameros para Chess in Time se refleja en el juego
/// y viceversa. Al terminar una partida de torneo, el resultado verificado
/// se reporta automáticamente al bracket de Gameros.
/// ---------------------------------------------------------------------------
class TorneosTab extends StatelessWidget {
  const TorneosTab({super.key});

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
                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: Color(0xFFC084FC),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Torneos Gameros',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Integrado al módulo central de torneos de Gameros.\n'
                  'Los torneos creados para Chess in Time se sincronizan bidireccionalmente: podés inscribirte, ver cruces y jugar tus partidas con reporte automático de resultados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey.shade800),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFC084FC), size: 24),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Reporte Automático Verificado',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las partidas de torneo cerradas en Chess in Time actualizan los cruces de Gameros sin necesidad de juez ni árbitro.',
                        style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                      ),
                    ],
                  ),
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
                      const Icon(Icons.sync_rounded, color: Color(0xFFC084FC), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Mismas funciones y tablas que Gameros',
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
