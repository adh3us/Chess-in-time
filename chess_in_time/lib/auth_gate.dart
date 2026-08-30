import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'online_match_service.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 5: login compartido con Gameros
///
/// Login vía Google, con la misma cuenta que ya usa Gameros (comparten
/// auth.users en el mismo proyecto Supabase) — Chess in Time no tiene
/// usuarios propios.
///
/// A propósito NO tapa el juego local: la app sigue arrancando directo en
/// el selector de modalidad de siempre (Fases 1-4, sin login), y esta
/// pantalla se abre aparte desde un botón de cuenta. Recién cuando exista
/// una partida online de verdad tiene sentido pedir login antes de jugar.
/// ---------------------------------------------------------------------------

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.chessintime://login-callback',
      );
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        initialData: AuthState(AuthChangeEvent.initialSession, supabase.auth.currentSession),
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? supabase.auth.currentSession;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: session != null
                ? [
                    const Icon(Icons.account_circle, size: 64),
                    const SizedBox(height: 12),
                    Text(session.user.email ?? session.user.id, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Center(child: OutlinedButton(onPressed: _signOut, child: const Text('Cerrar sesión'))),
                    const SizedBox(height: 32),
                    const _MyRatings(),
                  ]
                : [
                    const Text(
                      'Iniciá sesión con la misma cuenta de Gameros para jugar online más adelante.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _signInWithGoogle,
                              icon: const Icon(Icons.login),
                              label: const Text('Iniciar sesión con Google'),
                            ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ],
                  ],
          );
        },
      ),
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
