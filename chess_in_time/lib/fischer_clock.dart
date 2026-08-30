import 'dart:async';
import 'local_chess_engine.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — FASE 3
/// Reloj Fischer: tiempo base + incremento por jugada, con victoria automática
/// al rival si alguien llega a 00:00.
///
/// Diseño anti-drift: en vez de restar "1 segundo" en cada tick (que acumula
/// error si el dispositivo se traba un instante), el tiempo restante siempre
/// se calcula contra el reloj real del sistema (DateTime.now()) desde el
/// momento en que empezó el turno actual. Así el descuento es exacto incluso
/// si la UI se frena momentáneamente.
/// ---------------------------------------------------------------------------

class ClockModality {
  final String label;
  final Duration base;
  final Duration increment;
  const ClockModality(this.label, this.base, this.increment);

  static const bullet = ClockModality('Bullet · 1+0', Duration(minutes: 1), Duration.zero);
  static const blitz = ClockModality('Blitz · 3+2', Duration(minutes: 3), Duration(seconds: 2));
  static const rapida = ClockModality('Rápida · 10+0', Duration(minutes: 10), Duration.zero);
  static const clasica = ClockModality('Clásica · 30+0', Duration(minutes: 30), Duration.zero);

  static const all = [bullet, blitz, rapida, clasica];
}

class FischerClock {
  Duration whiteRemaining;
  Duration blackRemaining;
  final Duration increment;
  PieceColor active;
  DateTime _turnStartedAt = DateTime.now();
  Timer? _timer;
  bool _running = false;

  /// Se llama ~5 veces por segundo mientras el reloj corre, para refrescar la UI.
  final void Function() onTick;

  /// Se llama una única vez, cuando el jugador `active` llega a 00:00.
  final void Function(PieceColor loser) onTimeout;

  FischerClock({
    required ClockModality modality,
    required this.onTick,
    required this.onTimeout,
    this.active = PieceColor.white,
  })  : whiteRemaining = modality.base,
        blackRemaining = modality.base,
        increment = modality.increment;

  /// Reanuda un reloj a partir de un estado guardado (partida online): el
  /// tiempo restante de cada lado ya viene de la base, no de la modalidad.
  FischerClock.resume({
    required this.whiteRemaining,
    required this.blackRemaining,
    required this.increment,
    required this.active,
    required DateTime turnStartedAt,
    required this.onTick,
    required this.onTimeout,
  }) : _turnStartedAt = turnStartedAt;

  bool get isRunning => _running;

  /// Sobrescribe el estado del reloj con lo que acaba de llegar del rival
  /// (partida online): nuevos tiempos restantes y de quién es el turno
  /// ahora. Reinicia la cuenta desde este instante.
  void syncFromRemote({
    required Duration whiteRemaining,
    required Duration blackRemaining,
    required PieceColor active,
  }) {
    this.whiteRemaining = whiteRemaining;
    this.blackRemaining = blackRemaining;
    this.active = active;
    _turnStartedAt = DateTime.now();
  }

  /// Tiempo restante a mostrar en pantalla para `color`, calculado contra
  /// el reloj real (no acumula error de redondeo).
  Duration remainingOf(PieceColor color) {
    final stored = color == PieceColor.white ? whiteRemaining : blackRemaining;
    if (color != active || !_running) return stored;
    final elapsed = DateTime.now().difference(_turnStartedAt);
    final left = stored - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void start() {
    _running = true;
    _turnStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (remainingOf(active) <= Duration.zero && _running) {
        _running = false;
        _timer?.cancel();
        onTimeout(active);
      }
      onTick();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
  }

  /// Llamar justo después de que `active` completó una jugada legal:
  /// congela su tiempo gastado, suma el incremento, y le pasa el turno al rival.
  void onMoveCommitted() {
    final elapsed = DateTime.now().difference(_turnStartedAt);
    final spent = active == PieceColor.white ? whiteRemaining : blackRemaining;
    var left = spent - elapsed + increment;
    if (left.isNegative) left = Duration.zero;
    if (active == PieceColor.white) {
      whiteRemaining = left;
    } else {
      blackRemaining = left;
    }
    active = active.opposite;
    _turnStartedAt = DateTime.now();
  }

  void dispose() => _timer?.cancel();
}

String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
