import 'dart:async';
import 'package:flutter/material.dart';
import 'chess_game_screen.dart';
import 'fischer_clock.dart';
import 'online_match_service.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 7: modo Equipos (N vs N, tableros independientes)
///
/// Cada jugador de un equipo juega su propio tablero 1v1 normal contra
/// alguien del equipo rival (mismo OnlineGameScreen de siempre) -- se arman
/// por cola automática, igual que Ranked 1v1 pero de a grupos.
/// ---------------------------------------------------------------------------
class EquiposScreen extends StatelessWidget {
  const EquiposScreen({super.key});

  static const _tamanos = [2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Elegí cuántos jugadores por lado. Cada uno juega su propio '
            'tablero contra alguien del equipo rival, y se suman los '
            'resultados de todos los tableros para definir qué equipo ganó.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ..._tamanos.map((tamano) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.groups),
                  title: Text('${tamano}v$tamano'),
                  children: ClockModality.all
                      .map((m) => ListTile(
                            title: Text(m.label),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => EquiposLobbyScreen(modality: m, tamanoEquipo: tamano),
                            )),
                          ))
                      .toList(),
                ),
              )),
        ],
      ),
    );
  }
}

class EquiposLobbyScreen extends StatefulWidget {
  final ClockModality modality;
  final int tamanoEquipo;
  const EquiposLobbyScreen({super.key, required this.modality, required this.tamanoEquipo});

  @override
  State<EquiposLobbyScreen> createState() => _EquiposLobbyScreenState();
}

class _EquiposLobbyScreenState extends State<EquiposLobbyScreen> {
  Timer? _pollTimer;
  String? _error;
  bool _navegado = false;
  String _status = 'Buscando compañeros y rivales...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  Future<void> _buscar() async {
    if (!mounted) return;
    final key = modalidadKey(widget.modality);
    try {
      final partidaEquipo = await buscarPartidaEquipo(key, widget.tamanoEquipo);
      if (!mounted) return;
      if (partidaEquipo != null) {
        await _entrarAMiTablero(partidaEquipo['id'] as String);
        return;
      }
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _reintentar(key));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo buscar partido de equipos: $e');
    }
  }

  Future<void> _reintentar(String key) async {
    if (_navegado || !mounted) return;
    try {
      final partidaEquipo = await buscarPartidaEquipo(key, widget.tamanoEquipo);
      if (partidaEquipo != null) await _entrarAMiTablero(partidaEquipo['id'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo buscar partido de equipos: $e');
    }
  }

  Future<void> _entrarAMiTablero(String partidaEquipoId) async {
    if (_navegado || !mounted) return;
    setState(() => _status = 'Equipo completo -- armando tu tablero...');
    // El insert de los N tableros ya se hizo dentro de la misma transacción
    // que armó partidas_equipo, así que ya debería estar disponible -- el
    // reintento es solo por las dudas ante alguna demora de propagación.
    Map<String, dynamic>? miTablero;
    for (var intento = 0; intento < 5 && miTablero == null; intento++) {
      miTablero = await miTableroDeEquipo(partidaEquipoId);
      if (miTablero == null) await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    if (miTablero == null) {
      setState(() => _error = 'El partido de equipos se armó, pero no se encontró tu tablero. Probá de nuevo.');
      return;
    }
    _navegado = true;
    _pollTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OnlineGameScreen(partida: miTablero!)),
    );
  }

  Future<void> _cancelar() async {
    await cancelarBusquedaEquipo();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Equipos ${widget.tamanoEquipo}v${widget.tamanoEquipo} · ${widget.modality.label}')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(_status, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    OutlinedButton(onPressed: _cancelar, child: const Text('Cancelar')),
                  ],
                ),
        ),
      ),
    );
  }
}
