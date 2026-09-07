import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Amigos (Estilo Clash Royale)
///
/// Pantalla inicial del módulo de Amigos. Por el momento permanece en blanco /
/// modo informativo a la espera de la implementación del sistema central de
/// amigos en la plataforma Gameros.
/// ---------------------------------------------------------------------------
class AmigosTab extends StatelessWidget {
  const AmigosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                        color: Colors.blueAccent.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    size: 64,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Amigos',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'El sistema de amigos está en desarrollo en la plataforma central de Gameros.\n'
                  'Una vez habilitado, podrás desafiar a tus amigos directamente desde aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
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
                      const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Próximamente — Fase Gameros Core',
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
