import 'package:flutter/material.dart';
import '../equipos_screen.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Equipo / Clanes (Estilo Clash Royale)
///
/// Integrado al sistema de clanes de Gameros. Muestra la misma información
/// de clanes que Gameros: si un usuario crea un clan para Chess in Time en
/// Gameros, impacta directamente aquí y viceversa.
/// También da acceso directo al modo de partidas N vs N por equipos (Fase 7).
/// ---------------------------------------------------------------------------
class EquipoTab extends StatelessWidget {
  const EquipoTab({super.key});

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
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 64,
                    color: Color(0xFFFBBF24),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Equipo / Clanes',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sincronizado con el sistema de clanes de Gameros.\n'
                  'Cualquier clan creado en Gameros para Chess in Time se refleja aquí automáticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                // Botón destacado para acceder al modo de partidas por equipos N vs N
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EquiposScreen()),
                    );
                  },
                  icon: const Icon(Icons.groups_rounded, size: 22),
                  label: const Text(
                    'Jugar Partida por Equipos (N vs N)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
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
                      const Icon(Icons.sync_rounded, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Integración con public.clanes de Gameros',
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
