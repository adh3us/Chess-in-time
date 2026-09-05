import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Comunidad (Estilo Clash Royale)
///
/// Integrado con la comunidad central de Gameros.
/// Refleja noticias, actividades, eventos y discusiones del ecosistema Gameros
/// aplicadas a Chess in Time y viceversa.
/// ---------------------------------------------------------------------------
class ComunidadTab extends StatelessWidget {
  const ComunidadTab({super.key});

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
                        color: Colors.pinkAccent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    size: 64,
                    color: Color(0xFFF472B6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Comunidad Gameros',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'El espacio de encuentro de los jugadores de Chess in Time y Gameros.\n'
                  'Noticias, eventos especiales, torneos comunitarios y novedades oficiales del ecosistema.',
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
                      const Icon(Icons.sync_rounded, color: Color(0xFFF472B6), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Sincronizado con la comunidad de Gameros',
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
