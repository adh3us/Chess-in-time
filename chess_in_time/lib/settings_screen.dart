import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'auth_gate.dart';
import 'board_theme.dart';
import 'chess_game_screen.dart';
import 'gameros_profile_service.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Pantalla de Configuración y Perfil
///
/// Accesible desde el ícono de engranaje en la cabecera superior.
/// Permite configurar:
/// - Perfil del usuario (nombre, email, ID de Gameros, foto/avatar).
/// - Compartir perfil con amigos (SharePlus).
/// - Temas visuales del tablero (5 temas con preview en tiempo real).
/// - Colores personalizados de acento.
/// - Redes sociales de la comunidad Gameros.
/// - Accesos a modos de juego offline (Jugar solo / Pass & Play).
/// - Cierre o inicio de sesión.
/// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Color _accentColor = const Color(0xFF10B981); // Verde Gameros por defecto

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión cerrada correctamente.')),
      );
    }
  }

  void _compartirPerfil(String id, String? nombre) {
    final mensaje = '¡Jugá ajedrez conmigo en Chess in Time (by Gameros)!\n'
        'Mi ID de jugador es: $id\n'
        'Descargá la app: https://github.com/adh3us/Chess-in-time/releases/download/latest-apk/app-release.apk';
    SharePlus.instance.share(ShareParams(text: mensaje));
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    final user = session?.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Configuración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. SECCIÓN DE PERFIL
          _buildSectionHeader('Perfil de Usuario', Icons.person_rounded),
          const SizedBox(height: 10),
          if (user != null)
            _buildUserProfileCard(user.id, user.email)
          else
            _buildLoginPromptCard(),

          const SizedBox(height: 24),

          // 2. TEMAS DEL TABLERO
          _buildSectionHeader('Temas del Tablero', Icons.palette_rounded),
          const SizedBox(height: 6),
          Text(
            'Elige la estética visual para las casillas y el tablero de juego.',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildBoardThemesSelector(),

          const SizedBox(height: 24),

          // 3. COLORES PERSONALIZADOS
          _buildSectionHeader('Color de Acento de la App', Icons.color_lens_rounded),
          const SizedBox(height: 12),
          _buildAccentColorPicker(),

          const SizedBox(height: 24),

          // 4. MODOS OFFLINE
          _buildSectionHeader('Modos de Práctica Offline', Icons.offline_bolt_rounded),
          const SizedBox(height: 10),
          _buildOfflineModes(),

          const SizedBox(height: 24),

          // 5. REDES SOCIALES Y COMUNIDAD
          _buildSectionHeader('Redes Sociales & Comunidad', Icons.share_rounded),
          const SizedBox(height: 10),
          _buildSocialMediaCard(),

          const SizedBox(height: 24),

          // 6. INFORMACIÓN DE VERSIÓN Y CIERRE DE SESIÓN
          if (user != null) ...[
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Cerrar Sesión de Gameros'),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Center(
            child: Text(
              'Chess in Time v1.0 • Ecosistema Gameros\nDesarrollado para Android',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accentColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileCard(String userId, String? email) {
    return FutureBuilder<GamerosProfile?>(
      future: obtenerPerfilGameros(userId),
      builder: (context, snapshot) {
        final perfil = snapshot.data;
        final nombre = perfil?.nombreParaMostrar ?? email ?? 'Jugador';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueGrey.shade800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF334155),
                    backgroundImage: perfil?.fotoUrl != null ? NetworkImage(perfil!.fotoUrl!) : null,
                    child: perfil?.fotoUrl == null
                        ? Text(
                            nombre.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email ?? 'Cuenta vinculada',
                          style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 24),
              // ID de Gameros
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID de Gameros:', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
                        const SizedBox(height: 2),
                        SelectableText(
                          userId,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 20),
                    tooltip: 'Copiar ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: userId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID de Gameros copiado al portapapeles.')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botón Compartir Perfil
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _compartirPerfil(userId, nombre),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir Perfil'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginPromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade800),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_circle_outlined, size: 48, color: Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          const Text(
            'Sin cuenta iniciada',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Conecta tu cuenta de Gameros para sincronizar partidas, ELO, clanes y torneos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Iniciar Sesión con Gameros'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardThemesSelector() {
    return ValueListenableBuilder<BoardVisual>(
      valueListenable: activeBoardTheme,
      builder: (context, currentVisual, _) {
        return Column(
          children: BoardVisual.values.map((visual) {
            final config = boardThemes[visual]!;
            final isSelected = visual == currentVisual;

            return GestureDetector(
              onTap: () => activeBoardTheme.value = visual,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _accentColor : Colors.blueGrey.shade800,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Mini preview del tablero (4 casillas: 2x2)
                    _buildMiniBoardPreview(config),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.blueGrey.shade100,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            config.description,
                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Radio<BoardVisual>(
                      value: visual,
                      groupValue: currentVisual,
                      activeColor: _accentColor,
                      onChanged: (val) {
                        if (val != null) activeBoardTheme.value = val;
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMiniBoardPreview(BoardThemeConfig config) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: config.framed ? config.frameColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      padding: config.framed ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSquare(config.lightSquare, config.lightSquareGradient, config.squareCornerRadius)),
                Expanded(child: _buildSquare(config.darkSquare, config.darkSquareGradient, config.squareCornerRadius)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSquare(config.darkSquare, config.darkSquareGradient, config.squareCornerRadius)),
                Expanded(child: _buildSquare(config.lightSquare, config.lightSquareGradient, config.squareCornerRadius)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquare(Color color, Gradient? gradient, double radius) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: radius > 0 ? BorderRadius.circular(radius / 2) : null,
      ),
    );
  }

  Widget _buildAccentColorPicker() {
    final colores = [
      (const Color(0xFF10B981), 'Verde Gameros'),
      (const Color(0xFF38BDF8), 'Azul Royal'),
      (const Color(0xFFFBBF24), 'Dorado Real'),
      (const Color(0xFFA855F7), 'Púrpura'),
      (const Color(0xFFF43F5E), 'Carmesí'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: colores.map((c) {
        final (color, nombre) = c;
        final isSelected = color.value == _accentColor.value;
        return GestureDetector(
          onTap: () => setState(() => _accentColor = color),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
                  ],
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
              const SizedBox(height: 4),
              Text(nombre, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 10)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOfflineModes() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoloBoardScreen()));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade800),
              ),
              child: const Column(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: Color(0xFF38BDF8), size: 28),
                  SizedBox(height: 6),
                  Text('Jugar Solo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Práctica libre', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChessGameScreen()));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade800),
              ),
              child: const Column(
                children: [
                  Icon(Icons.people_alt_rounded, color: Color(0xFFFBBF24), size: 28),
                  SizedBox(height: 6),
                  Text('Multijugador Local', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Pass & Play', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialMediaCard() {
    final redes = [
      (Icons.discord, 'Discord Oficial', 'Comunidad Gameros'),
      (Icons.language, 'Web Oficial', 'gameros.app'),
      (Icons.tag, 'X (Twitter)', '@gAmerosApp'),
      (Icons.camera_alt, 'Instagram', '@gameros_app'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade800),
      ),
      child: Column(
        children: redes.map((r) {
          final (icon, titulo, subtitulo) = r;
          return ListTile(
            dense: true,
            leading: Icon(icon, color: _accentColor, size: 22),
            title: Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(subtitulo, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12)),
            trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Abriendo enlace de $titulo ($subtitulo)...')),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
