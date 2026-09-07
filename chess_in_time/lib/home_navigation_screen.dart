import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';
import 'gameros_profile_service.dart';
import 'modules/amigos_tab.dart';
import 'modules/comunidad_tab.dart';
import 'modules/equipo_tab.dart';
import 'modules/jugar_tab.dart';
import 'modules/salas_tab.dart';
import 'modules/torneos_tab.dart';
import 'settings_screen.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Pantalla Inicial con Navegación Inferior (Estilo Clash Royale)
///
/// Contiene:
/// - Cabecera superior con botón de inicio de sesión con cuenta gAmeros y
///   engranaje de configuración.
/// - 6 módulos en la barra de navegación inferior:
///   1. Amigos (pendiente de sistema de amigos de Gameros)
///   2. Equipo (clanes de Gameros)
///   3. Jugar (matchmaking 1v1 con reloj 5 min y rank estilo Clash Royale)
///   4. Salas (partidas privadas)
///   5. Torneos (torneos de Gameros)
///   6. Comunidad (comunidad y noticias de Gameros)
/// ---------------------------------------------------------------------------
class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  // Pestaña inicial: 2 (Jugar), el corazón de la experiencia estilo Clash Royale.
  int _currentIndex = 2;

  final List<Widget> _tabs = const [
    AmigosTab(),
    EquipoTab(),
    JugarTab(),
    SalasTab(),
    TorneosTab(),
    ComunidadTab(),
  ];

  void _abrirConfiguracion() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _abrirCuentaOLogin(Session? session) {
    if (session == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, supabase.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        final user = session?.user;

        return Scaffold(
          backgroundColor: const Color(0xFF0B1120),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            elevation: 2,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.castle_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Chess in Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              // 1. Ícono para loguearse con cuenta gAmeros / ver perfil
              _buildAuthButton(user, session),

              // 2. Ícono engranaje para configuración
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Color(0xFF94A3B8), size: 24),
                tooltip: 'Configuración',
                onPressed: _abrirConfiguracion,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          bottomNavigationBar: _buildClashRoyaleBottomBar(),
        );
      },
    );
  }

  Widget _buildAuthButton(User? user, Session? session) {
    if (user == null) {
      return TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1E293B),
        ),
        onPressed: () => _abrirCuentaOLogin(session),
        icon: const Icon(Icons.login_rounded, size: 16),
        label: const Text(
          'gAmeros',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    }

    return FutureBuilder<GamerosProfile?>(
      future: obtenerPerfilGameros(user.id),
      builder: (context, snapshot) {
        final perfil = snapshot.data;
        final nombre = perfil?.nombreParaMostrar ?? user.email ?? 'Jugador';
        final letra = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';

        return InkWell(
          onTap: () => _abrirCuentaOLogin(session),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF10B981),
                  backgroundImage: perfil?.fotoUrl != null ? NetworkImage(perfil!.fotoUrl!) : null,
                  child: perfil?.fotoUrl == null
                      ? Text(letra, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    nombre,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClashRoyaleBottomBar() {
    final items = [
      (Icons.people_outline_rounded, Icons.people_alt_rounded, 'Amigos'),
      (Icons.shield_outlined, Icons.shield_rounded, 'Equipo'),
      (Icons.sports_esports_outlined, Icons.sports_esports_rounded, 'Jugar'),
      (Icons.meeting_room_outlined, Icons.meeting_room_rounded, 'Salas'),
      (Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Torneos'),
      (Icons.forum_outlined, Icons.forum_rounded, 'Comunidad'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(top: BorderSide(color: Colors.blueGrey.shade900, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = _currentIndex == index;
              final (inactiveIcon, activeIcon, label) = items[index];
              final isJugar = index == 2;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isJugar)
                        // Botón central "Jugar" más llamativo estilo Clash Royale
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                  ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.amberAccent : Colors.blueGrey.shade700,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: Icon(
                            isSelected ? activeIcon : inactiveIcon,
                            color: isSelected ? Colors.white : Colors.blueGrey.shade300,
                            size: 22,
                          ),
                        )
                      else
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSelected ? activeIcon : inactiveIcon,
                            color: isSelected ? const Color(0xFF38BDF8) : Colors.blueGrey.shade400,
                            size: 20,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isJugar ? const Color(0xFF10B981) : const Color(0xFF38BDF8))
                              : Colors.blueGrey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
