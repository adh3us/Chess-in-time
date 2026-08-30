import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'auth_gate.dart';
import 'chess_game_screen.dart';
import 'fischer_clock.dart';
import 'gameros_profile_service.dart';
import 'online_match_service.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 7: partida privada (invitar a un amigo)
///
/// Tercer camino online, además del matchmaking libre (Ranked 1v1) y los
/// cruces de torneo: acá los dos jugadores se conocen y quedan en jugar, así
/// que en vez de emparejar al azar arman juntos una sala con un código para
/// compartir (adentro del juego, o por un link externo tipo WhatsApp).
/// ---------------------------------------------------------------------------
class PrivateMatchScreen extends StatelessWidget {
  const PrivateMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partida privada')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Jugá con un amigo puntual: uno crea la sala y elige el reloj (o '
            'sin reloj), el otro se une con el código o el link, y arrancan '
            'cuando los dos estén listos.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Crear sala'),
              subtitle: const Text('Elegís el reloj y compartís el código.'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CrearSalaScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: const Text('Unirme con un código'),
              subtitle: const Text('Alguien ya te compartió una sala.'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnirseSalaScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class CrearSalaScreen extends StatefulWidget {
  const CrearSalaScreen({super.key});

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  bool _creando = false;
  String? _error;

  Future<void> _crear(String? modalidadKey) async {
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      final sala = await crearSalaPrivada(modalidadKey);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SalaLobbyScreen(sala: sala)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo crear la sala: $e');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sala · Elegí el reloj')),
      body: _creando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                ...ClockModality.all.map((m) => Card(
                      child: ListTile(
                        title: Text(m.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _crear(modalidadKey(m)),
                      ),
                    )),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.all_inclusive),
                    title: const Text('Sin reloj'),
                    subtitle: const Text('Nadie pierde por tiempo -- termina por jaque mate, tablas o rendición.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _crear(null),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Se une a una sala por código. `codigoInicial` viene del deep link
/// (io.supabase.chessintime://sala?codigo=XXXXXX) -- si está presente, se
/// intenta unir directo sin que el usuario tenga que tipear nada.
class UnirseSalaScreen extends StatefulWidget {
  final String? codigoInicial;
  const UnirseSalaScreen({super.key, this.codigoInicial});

  @override
  State<UnirseSalaScreen> createState() => _UnirseSalaScreenState();
}

class _UnirseSalaScreenState extends State<UnirseSalaScreen> {
  final _codigoController = TextEditingController();
  bool _uniendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.codigoInicial != null) {
      _codigoController.text = widget.codigoInicial!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unirse());
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      setState(() => _error = 'Escribí el código de la sala.');
      return;
    }
    if (supabase.auth.currentUser == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (!mounted || supabase.auth.currentUser == null) return;
    }
    setState(() {
      _uniendo = true;
      _error = null;
    });
    try {
      final sala = await unirseSalaPrivada(codigo);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SalaLobbyScreen(sala: sala)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo unir a la sala: $e');
    } finally {
      if (mounted) setState(() => _uniendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a una sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _codigoController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Código de la sala', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            if (_uniendo)
              const CircularProgressIndicator()
            else
              FilledButton(onPressed: _unirse, child: const Text('Unirme')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sala de espera: se refresca sola por polling y también con el botón
/// "Actualizar" -- útil apenas se crea la sala, cuando el anfitrión todavía
/// no sabe si el otro ya tocó el link. Una vez que los dos están adentro,
/// cualquiera de los dos puede arrancar la partida.
class SalaLobbyScreen extends StatefulWidget {
  final Map<String, dynamic> sala;
  const SalaLobbyScreen({super.key, required this.sala});

  @override
  State<SalaLobbyScreen> createState() => _SalaLobbyScreenState();
}

class _SalaLobbyScreenState extends State<SalaLobbyScreen> {
  late Map<String, dynamic> _sala;
  Timer? _pollTimer;
  bool _actualizando = false;
  bool _iniciando = false;
  String? _error;
  String? _invitadoNombre;
  bool _navegado = false;

  @override
  void initState() {
    super.initState();
    _sala = widget.sala;
    _cargarNombreInvitado();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refrescar(mostrarError: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarNombreInvitado() async {
    final invitadoId = _sala['invitado'] as String?;
    if (invitadoId == null) return;
    final perfil = await obtenerPerfilGameros(invitadoId);
    if (mounted && perfil?.nombreParaMostrar != null) {
      setState(() => _invitadoNombre = perfil!.nombreParaMostrar);
    }
  }

  Future<void> _refrescar({bool mostrarError = true}) async {
    if (_navegado || !mounted) return;
    if (mostrarError) setState(() => _actualizando = true);
    try {
      final sala = await obtenerSalaPrivada(_sala['id'] as String);
      if (sala == null || !mounted) return;
      final teniaInvitado = _sala['invitado'] != null;
      setState(() => _sala = sala);
      if (!teniaInvitado && sala['invitado'] != null) _cargarNombreInvitado();
      final partidaId = sala['partida_id'] as String?;
      if (partidaId != null) await _entrarAPartida(partidaId);
    } catch (e) {
      if (mostrarError && mounted) setState(() => _error = 'No se pudo actualizar: $e');
    } finally {
      if (mostrarError && mounted) setState(() => _actualizando = false);
    }
  }

  Future<void> _iniciar() async {
    setState(() {
      _iniciando = true;
      _error = null;
    });
    try {
      final partida = await iniciarPartidaPrivada(_sala['id'] as String);
      await _entrarAPartida(partida['id'] as String, partidaYaCargada: partida);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo iniciar la partida: $e');
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _entrarAPartida(String partidaId, {Map<String, dynamic>? partidaYaCargada}) async {
    if (_navegado || !mounted) return;
    final partida = partidaYaCargada ?? await obtenerPartida(partidaId);
    if (partida == null || !mounted || _navegado) return;
    _navegado = true;
    _pollTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OnlineGameScreen(partida: partida)),
    );
  }

  Future<void> _compartir() async {
    final codigo = _sala['codigo'] as String;
    final link = 'io.supabase.chessintime://sala?codigo=$codigo';
    await SharePlus.instance.share(
      ShareParams(
        text: 'Jugamos una partida en Chess in Time -- entrá con el código $codigo o abrí este link: $link',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codigo = _sala['codigo'] as String;
    final invitado = _sala['invitado'] as String?;
    final modalidad = _sala['modalidad'] as String?;
    final labels = {'bullet': 'Bullet', 'blitz': 'Blitz', 'rapida': 'Rápida', 'clasica': 'Clásica'};
    final reloj = modalidad == null ? 'Sin reloj' : (labels[modalidad] ?? modalidad);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sala privada'),
        actions: [
          IconButton(
            icon: _actualizando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _actualizando ? null : () => _refrescar(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Código de la sala', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(codigo, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _compartir, icon: const Icon(Icons.share), label: const Text('Compartir')),
            const SizedBox(height: 24),
            Text('Reloj: $reloj', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Vos'),
            ),
            ListTile(
              leading: Icon(invitado == null ? Icons.hourglass_empty : Icons.check_circle,
                  color: invitado == null ? Colors.grey : Colors.green),
              title: Text(invitado == null ? 'Esperando al invitado...' : (_invitadoNombre ?? 'Invitado conectado')),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            if (_iniciando)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: invitado == null ? null : _iniciar,
                child: const Text('Iniciar partida'),
              ),
          ],
        ),
      ),
    );
  }
}
