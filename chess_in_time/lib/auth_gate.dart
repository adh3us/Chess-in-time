import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gameros_profile_service.dart';
import 'mode_selection_screen.dart';
import 'online_match_service.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 5/7: login compartido con Gameros
///
/// Login con la misma cuenta que ya usa Gameros (comparten auth.users en el
/// mismo proyecto Supabase) — Chess in Time no tiene usuarios propios.
///
/// Desde la Fase 7, el login es obligatorio y es la primera pantalla de la
/// app (antes era opcional y el juego arrancaba directo en el selector
/// local): Chess in Time se lanza también como app independiente (APK
/// propia) dentro del ecosistema Gameros, así que necesita su propia puerta
/// de entrada, igual que Gameros la tiene para su propia app.
/// ---------------------------------------------------------------------------

/// Pantalla raíz: sin sesión activa muestra el login, con sesión pasa
/// directo a la pantalla de modos (offline/online).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, supabase.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        return session != null ? const ModeSelectionScreen() : const LoginScreen();
      },
    );
  }
}

/// Login obligatorio: mismas opciones que Gameros (email/contraseña propios
/// o Google), porque comparten el mismo auth.users -- quien ya tiene cuenta
/// de Gameros entra directo acá con la misma.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth({required bool isSignUp}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Completá email y contraseña.');
      return;
    }
    setState(() => _loading = true);
    try {
      if (isSignUp) {
        await supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'io.supabase.chessintime://login-callback',
        );
        if (supabase.auth.currentSession == null && mounted) {
          _showMessage(
            'Cuenta creada. Si tu proyecto pide confirmación por email, '
            'revisá tu correo antes de iniciar sesión.',
          );
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: password);
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.chessintime://login-callback',
      );
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.castle, size: 64, color: Color(0xFF3ECF8E)),
                const SizedBox(height: 16),
                Text(
                  'Chess in Time',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajedrez con reloj, del ecosistema Gameros.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : () => _handleAuth(isSignUp: true),
                  child: const Text('Registrarme'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _loading ? null : () => _handleAuth(isSignUp: false),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continuar con Google'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Con la misma cuenta de Gameros, si ya tenés una.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (_loading) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla "Mi cuenta", accesible desde la pantalla de modos una vez
/// logueado -- a diferencia de LoginScreen, acá siempre hay sesión (el
/// AuthGate no deja llegar hasta acá sin loguearse).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: session == null
          ? const Center(child: Text('Sesión cerrada.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _GamerosIdentity(userId: session.user.id, email: session.user.email),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton(onPressed: () => _signOut(context), child: const Text('Cerrar sesión')),
                ),
                const SizedBox(height: 32),
                const _MyRatings(),
              ],
            ),
    );
  }
}

/// Muestra el nombre y la foto heredados del perfil de Gameros (public.usuarios)
/// en vez del email crudo -- Chess in Time no pide un nombre propio, usa
/// directo el mismo perfil que ya armaste en Gameros. Si todavía no completaste
/// tu perfil ahí (usuario nuevo), cae de vuelta al email sin romper nada.
class _GamerosIdentity extends StatelessWidget {
  final String userId;
  final String? email;
  const _GamerosIdentity({required this.userId, required this.email});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GamerosProfile?>(
      future: obtenerPerfilGameros(userId),
      builder: (context, snapshot) {
        final perfil = snapshot.data;
        final nombre = perfil?.nombreParaMostrar ?? email ?? userId;
        return Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: perfil?.fotoUrl != null ? NetworkImage(perfil!.fotoUrl!) : null,
              child: perfil?.fotoUrl == null ? const Icon(Icons.account_circle, size: 56) : null,
            ),
            const SizedBox(height: 12),
            Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            if (perfil?.username != null && perfil!.nombreDisplay != null)
              Text('@${perfil.username}', style: TextStyle(color: Colors.grey.shade600)),
          ],
        );
      },
    );
  }
}

/// Rating ELO propio de Chess in Time por modalidad de tiempo -- separado del
/// de Gameros, arranca en 1200 y se actualiza solo cuando termina una partida
/// online real (chess_in_time.cerrar_partida).
class _MyRatings extends StatelessWidget {
  const _MyRatings();

  static const _labels = {
    'bullet': 'Bullet',
    'blitz': 'Blitz',
    'rapida': 'Rápida',
    'clasica': 'Clásica',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: misRatings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ratings = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis ratings', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (ratings.isEmpty)
              Text(
                'Todavía no jugaste ninguna partida online. Arrancás en 1200 en cada modalidad.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              ...ratings.map((r) => Card(
                    child: ListTile(
                      title: Text(_labels[r['modalidad']] ?? r['modalidad'] as String),
                      trailing: Text(
                        '${r['rating']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${r['partidas_jugadas']} partidas jugadas'),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
