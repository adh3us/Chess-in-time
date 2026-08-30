import 'dart:async';
import 'package:flutter/material.dart';
import 'local_chess_engine.dart';
import 'fischer_clock.dart';
import 'board_theme.dart';
import 'piece_icons.dart';
import 'auth_gate.dart';
import 'gameros_profile_service.dart';
import 'online_match_service.dart';
import 'supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — FASE 3
/// Extiende la pantalla de la Fase 2 con: selector de modalidad de tiempo,
/// reloj Fischer en vivo (con alerta bajo 30 segundos), y botón "Rendirse"
/// con confirmación. Reusa el motor y el tablero de las fases anteriores
/// sin modificarlos.
/// ---------------------------------------------------------------------------

/// Colores de relleno/contorno del set de piezas propio (piece_icons.dart).
/// Un solo tratamiento para las 6 figuras y las dos piezas, en cualquier
/// tema de tablero -- nada de glifos de fuente, nada de placas de fondo.
Color _pieceFill(PieceColor color) => color == PieceColor.white ? Colors.white : const Color(0xFF1A1A1A);
Color _pieceOutline(PieceColor color) => color == PieceColor.white ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

const Map<PieceType, int> _pieceValue = {
  PieceType.pawn: 1,
  PieceType.knight: 3,
  PieceType.bishop: 3,
  PieceType.rook: 5,
  PieceType.queen: 9,
  PieceType.king: 0,
};

const Map<PieceType, int> _startCount = {
  PieceType.pawn: 8,
  PieceType.knight: 2,
  PieceType.bishop: 2,
  PieceType.rook: 2,
  PieceType.queen: 1,
  PieceType.king: 1,
};

/// Piezas capturadas por cada color y diferencial de material (Fase 4),
/// derivados de comparar el tablero actual contra el conteo inicial — no
/// hace falta que el motor lleve su propio historial de capturas.
class _Material {
  final List<PieceType> capturedByWhite; // piezas negras que blancas capturó
  final List<PieceType> capturedByBlack; // piezas blancas que negras capturó
  final int diff; // positivo = blancas arriba en material
  const _Material(this.capturedByWhite, this.capturedByBlack, this.diff);
}

_Material _computeMaterial(LocalChessEngine engine) {
  final onBoard = {PieceColor.white: <PieceType, int>{}, PieceColor.black: <PieceType, int>{}};
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      final p = engine.board[r][c];
      if (p == null) continue;
      onBoard[p.color]![p.type] = (onBoard[p.color]![p.type] ?? 0) + 1;
    }
  }
  final capturedByWhite = <PieceType>[];
  final capturedByBlack = <PieceType>[];
  var diff = 0;
  for (final entry in _startCount.entries) {
    final type = entry.key;
    final missingBlack = entry.value - (onBoard[PieceColor.black]![type] ?? 0);
    final missingWhite = entry.value - (onBoard[PieceColor.white]![type] ?? 0);
    capturedByWhite.addAll(List.filled(missingBlack, type));
    capturedByBlack.addAll(List.filled(missingWhite, type));
    diff += (missingBlack - missingWhite) * _pieceValue[type]!;
  }
  return _Material(capturedByWhite, capturedByBlack, diff);
}

/// Dibuja una pieza en el tablero, en cualquier tema.
///
/// Por pedido de Lucas: se abandona por completo el glifo Unicode de
/// ajedrez y la placa circular de fondo (las dos técnicas anteriores, que
/// dieron problemas de contraste una y otra vez). Ahora es el set propio
/// de piece_icons.dart -- formas vectoriales simples dibujadas a mano, con
/// relleno y contorno bajo control total. Un solo tratamiento en los 5
/// temas de tablero.
Widget _pieceGlyph(ChessPiece piece) {
  return PieceIcon(
    type: piece.type,
    fill: _pieceFill(piece.color),
    outline: _pieceOutline(piece.color),
    size: 28,
  );
}

/// Motivo de cierre que no viene del motor de ajedrez (jaque mate/ahogado/
/// tablas), sino de la capa de partida: se acabó el tiempo, o alguien se rindió.
class _ForcedEnd {
  final String reason; // 'timeout' | 'resignation'
  final PieceColor loser;
  const _ForcedEnd(this.reason, this.loser);
}

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  ClockModality? _modality;
  LocalChessEngine? _engine;
  FischerClock? _clock;
  Position? _selected;
  List<Move> _legalForSelected = [];
  _ForcedEnd? _forcedEnd;
  BoardVisual _visual = BoardVisual.clasico;
  Move? _lastMove;

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  void _startGame(ClockModality modality) {
    final engine = LocalChessEngine();
    setState(() {
      _modality = modality;
      _engine = engine;
      _forcedEnd = null;
      _selected = null;
      _legalForSelected = [];
      _lastMove = null;
      _clock = FischerClock(
        modality: modality,
        active: engine.turn,
        onTick: () => setState(() {}),
        onTimeout: (loser) => setState(() => _forcedEnd = _ForcedEnd('timeout', loser)),
      )..start();
    });
  }

  bool get _gameOver => _forcedEnd != null || (_engine?.status ?? GameStatus.ongoing) != GameStatus.ongoing;

  void _selectSquare(Position pos) {
    final engine = _engine!;
    if (_gameOver) return;

    if (_selected != null) {
      final targets = _legalForSelected.where((m) => m.to == pos).toList();
      if (targets.isNotEmpty) {
        if (targets.first.promotion != null) {
          _askPromotion(pos);
          return;
        }
        _commit(targets.first);
        return;
      }
      if (_selected == pos) {
        setState(() {
          _selected = null;
          _legalForSelected = [];
        });
        return;
      }
    }

    final piece = engine.pieceAt(pos);
    if (piece != null && piece.color == engine.turn) {
      setState(() {
        _selected = pos;
        _legalForSelected = engine.legalMovesFrom(pos);
      });
    } else {
      setState(() {
        _selected = null;
        _legalForSelected = [];
      });
    }
  }

  void _commit(Move move) {
    _engine!.makeMove(move);
    _clock!.onMoveCommitted(); // congela el tiempo gastado, suma incremento, pasa el turno
    if (_engine!.status != GameStatus.ongoing) _clock!.stop();
    setState(() {
      _selected = null;
      _legalForSelected = [];
      _lastMove = move;
    });
  }

  Future<void> _askPromotion(Position to) async {
    final from = _selected!;
    final engine = _engine!;
    final choice = await showDialog<PieceType>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Coronar a...'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]
              .map((t) => IconButton(
                    iconSize: 36,
                    icon: PieceIcon(type: t, fill: _pieceFill(engine.turn), outline: _pieceOutline(engine.turn), size: 32),
                    onPressed: () => Navigator.of(ctx).pop(t),
                  ))
              .toList(),
        ),
      ),
    );
    if (choice == null) return;
    final move = _legalForSelected.firstWhere((m) => m.to == to && m.promotion == choice);
    _commit(move);
  }

  Future<void> _confirmResign() async {
    final engine = _engine!;
    final side = engine.turn == PieceColor.white ? 'Blancas' : 'Negras';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Rendirse?'),
        content: Text('$side van a perder la partida de inmediato. Esto no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Rendirse')),
        ],
      ),
    );
    if (confirmed == true) {
      _clock!.stop();
      setState(() => _forcedEnd = _ForcedEnd('resignation', engine.turn));
    }
  }

  BoxDecoration _squareDecoration(int r, int c, BoardThemeConfig theme, bool isSelected, bool isLastMove) {
    final isLight = (r + c).isEven;
    final gradient = isLight ? theme.lightSquareGradient : theme.darkSquareGradient;
    final color = isLight ? theme.lightSquare : theme.darkSquare;
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: theme.squareCornerRadius > 0 ? BorderRadius.circular(theme.squareCornerRadius) : null,
      border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
    );
  }

  String? _statusMessage() {
    if (_forcedEnd != null) {
      final winner = _forcedEnd!.loser == PieceColor.white ? 'Negras' : 'Blancas';
      return _forcedEnd!.reason == 'timeout'
          ? 'Se acabó el tiempo — ganan $winner'
          : 'Rendición — ganan $winner';
    }
    final engine = _engine!;
    switch (engine.status) {
      case GameStatus.checkmate:
        final winner = engine.turn == PieceColor.white ? 'Negras' : 'Blancas';
        return 'Jaque mate — ganan $winner';
      case GameStatus.stalemate:
        return 'Ahogado — tablas';
      case GameStatus.drawFiftyMoves:
        return 'Tablas por regla de 50 movimientos';
      case GameStatus.drawThreefoldRepetition:
        return 'Tablas por triple repetición';
      case GameStatus.drawInsufficientMaterial:
        return 'Tablas por material insuficiente';
      case GameStatus.ongoing:
        if (engine.inCheck(engine.turn)) {
          final side = engine.turn == PieceColor.white ? 'Blancas' : 'Negras';
          return 'Jaque a $side';
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modality == null || _engine == null || _clock == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Multijugador · Elegí modalidad')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Tablero', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BoardVisual.values.map((v) {
                final t = boardThemes[v]!;
                final selected = _visual == v;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _visual = v),
                  avatar: CircleAvatar(backgroundColor: t.darkSquare),
                  label: Text(t.label),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              boardThemes[_visual]!.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            const Text('Modalidad de tiempo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...ClockModality.all.map((m) => Card(
                  child: ListTile(
                    title: Text(m.label),
                    subtitle: const Text('Local, pasa y juega'),
                    onTap: () => _startGame(m),
                  ),
                )),
          ],
        ),
      );
    }

    final engine = _engine!;
    final clock = _clock!;
    final status = _statusMessage();
    final gameOver = _gameOver;
    final turnLabel = engine.turn == PieceColor.white ? 'Blancas' : 'Negras';

    return Scaffold(
      appBar: AppBar(
        title: Text(gameOver ? 'Partida terminada' : 'Turno: $turnLabel'),
      ),
      body: Column(
        children: [
          _ClockRow(clock: clock, running: !gameOver),
          _CapturedRow(material: _computeMaterial(engine)),
          if (status != null)
            Container(
              width: double.infinity,
              color: gameOver ? Colors.red.shade50 : Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(status, textAlign: TextAlign.center),
            ),
          Expanded(
            child: Center(
              child: _BoardArea(
                theme: boardThemes[_visual]!,
                boardBuilder: () => AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final r = index ~/ 8;
                      final c = index % 8;
                      final pos = Position(r, c);
                      final piece = engine.pieceAt(pos);
                      final isSelected = _selected == pos;
                      final isLastMove = _lastMove != null && (_lastMove!.from == pos || _lastMove!.to == pos);
                      final targetMove = _legalForSelected.where((m) => m.to == pos).toList();
                      final isTarget = targetMove.isNotEmpty;
                      final isCapture = isTarget && (piece != null || targetMove.first.isEnPassant);
                      final theme = boardThemes[_visual]!;

                      return GestureDetector(
                        onTap: gameOver ? null : () => _selectSquare(pos),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(decoration: _squareDecoration(r, c, theme, isSelected, isLastMove)),
                            if (isLastMove && theme.lastMoveHighlight != null)
                              Container(color: theme.lastMoveHighlight),
                            if (piece != null) _pieceGlyph(piece),
                            if (isTarget)
                              isCapture
                                  ? Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.blueAccent, width: 3),
                                      ),
                                    )
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                    ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!gameOver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmResign,
                  icon: const Icon(Icons.flag, color: Colors.red),
                  label: const Text('Rendirse', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          if (gameOver)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _modality = null;
                  _engine = null;
                  _clock?.dispose();
                  _clock = null;
                  _forcedEnd = null;
                }),
                child: const Text('Nueva partida'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Envoltorio del tablero que agrega, según el tema elegido, coordenadas
/// a-h/1-8 y un marco con relieve — puramente decorativo, no toca la
/// grilla de juego que le pasan por [boardBuilder].
class _BoardArea extends StatelessWidget {
  final BoardThemeConfig theme;
  final Widget Function() boardBuilder;
  const _BoardArea({required this.theme, required this.boardBuilder});

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const _ranks = ['8', '7', '6', '5', '4', '3', '2', '1'];

  @override
  Widget build(BuildContext context) {
    final grid = boardBuilder();

    Widget content = grid;
    if (theme.showCoordinates) {
      // Márgenes simétricos en las 4 puntas (aunque solo izquierda/abajo
      // lleven texto) para que el tablero en sí quede centrado — antes las
      // etiquetas solo restaban espacio de un lado y corrían la grilla
      // hacia arriba/derecha.
      const labelThickness = 16.0;
      content = AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Positioned(
              left: labelThickness,
              right: labelThickness,
              top: labelThickness,
              bottom: labelThickness,
              child: grid,
            ),
            Positioned(
              left: 0,
              width: labelThickness,
              top: labelThickness,
              bottom: labelThickness,
              child: Column(
                children: _ranks
                    .map((r) => Expanded(
                          child: Center(child: Text(r, style: TextStyle(fontSize: 10, color: theme.frameColor))),
                        ))
                    .toList(),
              ),
            ),
            Positioned(
              left: labelThickness,
              right: labelThickness,
              bottom: 0,
              height: labelThickness,
              child: Row(
                children: _files
                    .map((f) => Expanded(
                          child: Center(child: Text(f, style: TextStyle(fontSize: 10, color: theme.frameColor))),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    if (theme.framed) {
      content = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.frameColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: content,
      );
    }

    return content;
  }
}

class _CapturedRow extends StatelessWidget {
  final _Material material;
  const _CapturedRow({required this.material});

  @override
  Widget build(BuildContext context) {
    final whiteLead = material.diff > 0 ? material.diff : 0;
    final blackLead = material.diff < 0 ? -material.diff : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(child: _side(material.capturedByBlack, PieceColor.white, blackLead, Alignment.centerLeft)),
          Expanded(child: _side(material.capturedByWhite, PieceColor.black, whiteLead, Alignment.centerRight)),
        ],
      ),
    );
  }

  Widget _side(List<PieceType> captured, PieceColor capturedColor, int lead, Alignment align) {
    return Align(
      alignment: align,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          for (final t in captured)
            PieceIcon(type: t, fill: _pieceFill(capturedColor), outline: _pieceOutline(capturedColor), size: 14),
          if (lead > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '+$lead',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClockRow extends StatelessWidget {
  final FischerClock clock;
  final bool running;
  const _ClockRow({required this.clock, required this.running});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _clockChip('Negras', clock.remainingOf(PieceColor.black), clock.active == PieceColor.black && running),
          _clockChip('Blancas', clock.remainingOf(PieceColor.white), clock.active == PieceColor.white && running),
        ],
      ),
    );
  }

  Widget _clockChip(String label, Duration remaining, bool active) {
    final low = remaining.inSeconds <= 30;
    final bg = low ? Colors.red.shade100 : (active ? Colors.blue.shade100 : Colors.grey.shade200);
    final fg = low ? Colors.red.shade900 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: fg.withOpacity(0.7))),
          Text(formatClock(remaining), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 5: matchmaking online
///
/// Busca rival en la modalidad elegida (chess_in_time.buscar_partida). Si ya
/// hay alguien esperando, arranca la partida al toque; si no, se anota en la
/// cola y espera -- por Realtime, no por polling -- a que otro jugador la
/// arme (ve aparecer la fila en `partidas` gracias al RLS ya existente).
/// ---------------------------------------------------------------------------
class OnlineLobbyScreen extends StatefulWidget {
  final ClockModality modality;
  const OnlineLobbyScreen({super.key, required this.modality});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  Timer? _pollTimer;
  String? _error;
  bool _navigated = false;
  String _status = 'Preparando...';

  @override
  void initState() {
    super.initState();
    // Se pospone al primer frame ya dibujado a propósito: así, si algo
    // revienta más adelante, sabemos que por lo menos esta pantalla (con
    // "Preparando...") llegó a pintarse -- útil para descartar que el
    // problema sea de la navegación en sí, y no de lo que viene después.
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  Future<void> _buscar() async {
    if (!mounted) return;
    setState(() => _status = 'Calculando modalidad...');
    final String key;
    try {
      key = modalidadKey(widget.modality);
    } catch (e, st) {
      if (mounted) setState(() => _error = 'Error calculando modalidad: $e\n$st');
      return;
    }
    if (mounted) setState(() => _status = 'Consultando rival...');
    try {
      final partida = await buscarPartida(key);
      if (!mounted) return;
      if (partida != null) {
        _goToGame(partida);
        return;
      }
      setState(() => _status = 'Buscando rival...');
      // Nadie esperando todavía en esta modalidad: reintentamos cada 2
      // segundos hasta que otro jugador llame a buscar_partida y nos
      // empareje (buscar_partida borra cualquier fila vieja propia de la
      // cola antes de reintentar, así que no se acumulan filas fantasma).
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _reintentar(key));
    } catch (e, st) {
      if (mounted) setState(() => _error = 'No se pudo buscar partida: $e\n$st');
    }
  }

  Future<void> _reintentar(String key) async {
    if (_navigated || !mounted) return;
    try {
      final partida = await buscarPartida(key);
      if (partida != null) _goToGame(partida);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo buscar partida: $e');
    }
  }

  void _goToGame(Map<String, dynamic> partida) {
    if (_navigated) return;
    _navigated = true;
    _pollTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OnlineGameScreen(partida: partida)),
    );
  }

  Future<void> _cancelar() async {
    await cancelarBusqueda();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(title: Text('Jugar online · ${widget.modality.label}')),
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
                      Text(_status),
                      const SizedBox(height: 24),
                      OutlinedButton(onPressed: _cancelar, child: const Text('Cancelar')),
                    ],
                  ),
          ),
        ),
      );
    } catch (e, st) {
      // Red de seguridad final: si incluso armar esta pantalla revienta,
      // que se vea el motivo en vez de quedar todo gris sin ninguna pista.
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SelectableText('Error armando la pantalla: $e\n$st'),
          ),
        ),
      );
    }
  }
}

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 5: partida online
///
/// Mismo tablero/reloj/HUD que el juego local, pero las jugadas se validan
/// igual en los dos dispositivos y se sincronizan por Realtime en vez de
/// compartir pantalla. El estado del reloj viaja en la fila de `partidas`
/// (tiempo restante de cada lado) en vez de vivir solo en memoria.
/// ---------------------------------------------------------------------------
class OnlineGameScreen extends StatefulWidget {
  final Map<String, dynamic> partida;
  const OnlineGameScreen({super.key, required this.partida});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final String _partidaId;
  late final PieceColor _myColor;
  late final String _opponentId;
  late final LocalChessEngine _engine;
  FischerClock? _clock;
  Timer? _pollTimer;
  Position? _selected;
  List<Move> _legalForSelected = [];
  Move? _lastMove;
  bool _terminada = false;
  String? _endMessage;
  bool _sending = false;
  String? _opponentName;

  @override
  void initState() {
    super.initState();
    final row = widget.partida;
    _partidaId = row['id'] as String;
    final myId = supabase.auth.currentUser!.id;
    _myColor = row['jugador_blancas'] == myId ? PieceColor.white : PieceColor.black;
    _opponentId = _myColor == PieceColor.white ? row['jugador_negras'] as String : row['jugador_blancas'] as String;
    _engine = LocalChessEngine();
    _applyRow(row);
    // Nombre heredado del perfil de Gameros del rival, para no mostrar un
    // "Turno del rival" genérico -- si el RLS no deja leerlo, no pasa nada,
    // se sigue viendo el genérico.
    obtenerPerfilGameros(_opponentId).then((perfil) {
      if (mounted && perfil?.nombreParaMostrar != null) {
        setState(() => _opponentName = perfil!.nombreParaMostrar);
      }
    });
    // Se refresca por polling en vez de Realtime -- más simple y usa el
    // mismo camino REST que ya funciona para todo lo demás.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPartida());
  }

  Future<void> _pollPartida() async {
    if (!mounted) return;
    try {
      final row = await obtenerPartida(_partidaId);
      if (row != null && mounted) _applyRow(row);
    } catch (_) {
      // Un fallo puntual de red no debería tirar abajo la partida -- se
      // reintenta solo en el próximo tick.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clock?.dispose();
    super.dispose();
  }

  /// Aplica el estado que viene de la base (propio o del rival). Para no
  /// perder el historial de posiciones (necesario para la triple repetición
  /// y la regla de 50 movimientos), no recarga el FEN entero -- reproduce
  /// solo las jugadas nuevas con makeMove(), igual que el pasa-y-juega local.
  void _applyRow(Map<String, dynamic> row) {
    final uciMoves = (row['pgn_moves'] as String).split(' ').where((s) => s.isNotEmpty).toList();
    for (var i = _engine.moveHistory.length; i < uciMoves.length; i++) {
      final applied = _applyUci(uciMoves[i]);
      if (!applied) {
        // Desincronización rara: como red de seguridad, recargamos el FEN
        // (a costa de perder el historial de repetición desde acá).
        _engine.loadFen(row['current_fen'] as String);
        break;
      }
    }

    final active = row['turn_color'] == 'white' ? PieceColor.white : PieceColor.black;
    final whiteMs = row['tiempo_restante_blancas_ms'] as int;
    final blackMs = row['tiempo_restante_negras_ms'] as int;
    if (_clock == null) {
      _clock = FischerClock.resume(
        whiteRemaining: Duration(milliseconds: whiteMs),
        blackRemaining: Duration(milliseconds: blackMs),
        increment: Duration(milliseconds: row['incremento_ms'] as int),
        active: active,
        turnStartedAt: DateTime.now(),
        onTick: () => setState(() {}),
        onTimeout: _onLocalTimeout,
      );
    } else if (_clock!.active != active ||
        _clock!.whiteRemaining.inMilliseconds != whiteMs ||
        _clock!.blackRemaining.inMilliseconds != blackMs) {
      // Solo resincroniza si de verdad cambió algo (una jugada nueva) --
      // si no, un poll sin novedades reiniciaría el cronómetro cada vez y
      // el reloj nunca bajaría de verdad, porque syncFromRemote() vuelve a
      // marcar "el turno empieza ahora".
      _clock!.syncFromRemote(
        whiteRemaining: Duration(milliseconds: whiteMs),
        blackRemaining: Duration(milliseconds: blackMs),
        active: active,
      );
    }

    final terminada = row['estado'] == 'terminada';
    setState(() {
      _terminada = terminada;
      _endMessage = terminada ? _endMessageFor(row['motivo_fin'] as String?, row['ganador'] as String?) : null;
      if (_gameOver) {
        _clock!.stop();
      } else if (!_clock!.isRunning) {
        _clock!.start();
      }
    });
  }

  bool _applyUci(String uci) {
    final from = Position.fromAlgebraic(uci.substring(0, 2));
    final to = Position.fromAlgebraic(uci.substring(2, 4));
    if (from == null || to == null) return false;
    PieceType? promo;
    if (uci.length > 4) {
      promo = switch (uci[4]) {
        'q' => PieceType.queen,
        'r' => PieceType.rook,
        'b' => PieceType.bishop,
        'n' => PieceType.knight,
        _ => null,
      };
    }
    final legal = _engine.allLegalMoves().where((m) => m.from == from && m.to == to && m.promotion == promo);
    if (legal.isEmpty) return false;
    final move = legal.first;
    final ok = _engine.makeMove(move);
    if (ok) _lastMove = move;
    return ok;
  }

  String _endMessageFor(String? motivo, String? ganador) {
    final myId = supabase.auth.currentUser!.id;
    final soyGanador = ganador == myId;
    final huboGanador = ganador != null;
    final resultado = !huboGanador ? 'Tablas' : (soyGanador ? 'Ganaste' : 'Perdiste');
    final motivoLabel = switch (motivo) {
      'jaque_mate' => 'jaque mate',
      'ahogado' => 'ahogado',
      'timeout' => 'se acabó el tiempo',
      'resignation' => 'rendición',
      'tablas_acordadas' => 'tablas acordadas',
      'tablas_repeticion' => 'triple repetición',
      'tablas_50_movimientos' => 'regla de 50 movimientos',
      'material_insuficiente' => 'material insuficiente',
      _ => motivo ?? '',
    };
    return '$resultado — $motivoLabel';
  }

  bool get _gameOver => _terminada || _engine.status != GameStatus.ongoing;

  Future<void> _onLocalTimeout(PieceColor loser) async {
    if (_terminada) return;
    final ganador = loser == _myColor ? _opponentId : supabase.auth.currentUser!.id;
    try {
      await cerrarPartida(partidaId: _partidaId, motivo: 'timeout', ganador: ganador);
      await _reportarTorneo(ganador);
    } catch (_) {
      // El rival ya la cerró (por ejemplo, detectó el mismo timeout primero) -- ok, ignoramos.
    }
  }

  /// Fase 6: si esta partida viene de un cruce de torneo de Gameros, avisa
  /// el resultado allá también -- si no viene de un torneo (matchmaking
  /// libre), reportarResultadoTorneo() no hace nada. Va separado del try/catch
  /// de cerrarPartida() para no confundir un fallo acá con "ya la cerró el
  /// rival" -- en el peor caso el torneo no avanza solo y hay que revisarlo
  /// a mano, pero la partida en sí ya quedó cerrada y con ELO actualizado.
  Future<void> _reportarTorneo(String? ganador) async {
    try {
      await reportarResultadoTorneo(widget.partida, ganador);
    } catch (_) {}
  }

  Future<void> _selectSquare(Position pos) async {
    if (_gameOver || _engine.turn != _myColor || _sending) return;

    if (_selected != null) {
      final targets = _legalForSelected.where((m) => m.to == pos).toList();
      if (targets.isNotEmpty) {
        if (targets.first.promotion != null) {
          await _askPromotion(pos);
          return;
        }
        await _commit(targets.first);
        return;
      }
      if (_selected == pos) {
        setState(() {
          _selected = null;
          _legalForSelected = [];
        });
        return;
      }
    }

    final piece = _engine.pieceAt(pos);
    if (piece != null && piece.color == _engine.turn) {
      setState(() {
        _selected = pos;
        _legalForSelected = _engine.legalMovesFrom(pos);
      });
    } else {
      setState(() {
        _selected = null;
        _legalForSelected = [];
      });
    }
  }

  Future<void> _askPromotion(Position to) async {
    final choice = await showDialog<PieceType>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Coronar a...'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]
              .map((t) => IconButton(
                    iconSize: 36,
                    icon: PieceIcon(type: t, fill: _pieceFill(_myColor), outline: _pieceOutline(_myColor), size: 32),
                    onPressed: () => Navigator.of(ctx).pop(t),
                  ))
              .toList(),
        ),
      ),
    );
    if (choice == null) return;
    final move = _legalForSelected.firstWhere((m) => m.to == to && m.promotion == choice);
    await _commit(move);
  }

  Future<void> _commit(Move move) async {
    setState(() => _sending = true);
    _engine.makeMove(move);
    _clock!.onMoveCommitted();
    setState(() {
      _selected = null;
      _legalForSelected = [];
      _lastMove = move;
    });
    final pgn = _engine.moveHistory.map((m) => m.toUci()).join(' ');
    final turnColor = _engine.turn == PieceColor.white ? 'white' : 'black';
    try {
      await actualizarPartida(
        partidaId: _partidaId,
        currentFen: _engine.toFen(),
        pgnMoves: pgn,
        turnColor: turnColor,
        tiempoBlancasMs: _clock!.whiteRemaining.inMilliseconds,
        tiempoNegrasMs: _clock!.blackRemaining.inMilliseconds,
      );
      if (_engine.status != GameStatus.ongoing) {
        _clock!.stop();
        final motivo = switch (_engine.status) {
          GameStatus.checkmate => 'jaque_mate',
          GameStatus.stalemate => 'ahogado',
          GameStatus.drawFiftyMoves => 'tablas_50_movimientos',
          GameStatus.drawThreefoldRepetition => 'tablas_repeticion',
          GameStatus.drawInsufficientMaterial => 'material_insuficiente',
          GameStatus.ongoing => '',
        };
        String? ganador;
        if (_engine.status == GameStatus.checkmate) {
          // engine.turn ya pasó al que recibió el jaque mate -- perdió.
          ganador = _engine.turn == _myColor ? _opponentId : supabase.auth.currentUser!.id;
        }
        try {
          await cerrarPartida(partidaId: _partidaId, motivo: motivo, ganador: ganador);
          await _reportarTorneo(ganador);
        } catch (_) {
          // Ya la cerró el rival por otro camino -- ok.
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmResign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Rendirse?'),
        content: const Text('Vas a perder la partida de inmediato. Esto no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Rendirse')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await cerrarPartida(partidaId: _partidaId, motivo: 'resignation', ganador: _opponentId);
      await _reportarTorneo(_opponentId);
    } catch (_) {
      // Ya estaba terminada de otra forma (timeout casi simultáneo, etc).
    }
  }

  String? _statusMessage() {
    if (_endMessage != null) return _endMessage;
    if (_engine.status == GameStatus.checkmate) return 'Jaque mate';
    if (_engine.inCheck(_engine.turn)) return 'Jaque';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = boardThemes[BoardVisual.clasico]!;
    final gameOver = _gameOver;
    final status = _statusMessage();
    final myTurn = !gameOver && _engine.turn == _myColor;
    final rivalLabel = _opponentName ?? 'rival';
    final title = gameOver ? 'Partida terminada' : (myTurn ? 'Tu turno' : 'Turno de $rivalLabel');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (_clock != null) _ClockRow(clock: _clock!, running: !gameOver),
          _CapturedRow(material: _computeMaterial(_engine)),
          if (status != null)
            Container(
              width: double.infinity,
              color: gameOver ? Colors.red.shade50 : Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(status, textAlign: TextAlign.center),
            ),
          Expanded(
            child: Center(
              child: _BoardArea(
                theme: theme,
                boardBuilder: () => AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      // Las negras juegan desde su propia perspectiva: tablero girado 180°.
                      final flip = _myColor == PieceColor.black;
                      final r = flip ? 7 - index ~/ 8 : index ~/ 8;
                      final c = flip ? 7 - index % 8 : index % 8;
                      final pos = Position(r, c);
                      final piece = _engine.pieceAt(pos);
                      final isSelected = _selected == pos;
                      final isLastMove = _lastMove != null && (_lastMove!.from == pos || _lastMove!.to == pos);
                      final targetMove = _legalForSelected.where((m) => m.to == pos).toList();
                      final isTarget = targetMove.isNotEmpty;
                      final isCapture = isTarget && (piece != null || targetMove.first.isEnPassant);

                      return GestureDetector(
                        onTap: gameOver ? null : () => _selectSquare(pos),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(decoration: _squareDecorationFor(r, c, theme, isSelected, isLastMove)),
                            if (isLastMove && theme.lastMoveHighlight != null)
                              Container(color: theme.lastMoveHighlight),
                            if (piece != null) _pieceGlyph(piece),
                            if (isTarget)
                              isCapture
                                  ? Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.blueAccent, width: 3),
                                      ),
                                    )
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                    ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!gameOver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmResign,
                  icon: const Icon(Icons.flag, color: Colors.red),
                  label: const Text('Rendirse', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          if (gameOver)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Volver al inicio'),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _squareDecorationFor(int r, int c, BoardThemeConfig theme, bool isSelected, bool isLastMove) {
    final isLight = (r + c).isEven;
    final gradient = isLight ? theme.lightSquareGradient : theme.darkSquareGradient;
    final color = isLight ? theme.lightSquare : theme.darkSquare;
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: theme.squareCornerRadius > 0 ? BorderRadius.circular(theme.squareCornerRadius) : null,
      border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
    );
  }
}

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 7: Jugar solo (offline, sin rival ni reloj)
///
/// Tablero libre para practicar/analizar: mismo motor y reglas que el resto
/// de la app, pero sin FischerClock -- nadie pierde por tiempo, es solo para
/// mover piezas de los dos lados a gusto.
/// ---------------------------------------------------------------------------
class SoloBoardScreen extends StatefulWidget {
  const SoloBoardScreen({super.key});

  @override
  State<SoloBoardScreen> createState() => _SoloBoardScreenState();
}

class _SoloBoardScreenState extends State<SoloBoardScreen> {
  LocalChessEngine _engine = LocalChessEngine();
  Position? _selected;
  List<Move> _legalForSelected = [];
  Move? _lastMove;

  void _reiniciar() {
    setState(() {
      _engine = LocalChessEngine();
      _selected = null;
      _legalForSelected = [];
      _lastMove = null;
    });
  }

  void _selectSquare(Position pos) {
    if (_engine.status != GameStatus.ongoing) return;
    if (_selected != null) {
      final targets = _legalForSelected.where((m) => m.to == pos).toList();
      if (targets.isNotEmpty) {
        if (targets.first.promotion != null) {
          _askPromotion(pos);
          return;
        }
        _commit(targets.first);
        return;
      }
      if (_selected == pos) {
        setState(() {
          _selected = null;
          _legalForSelected = [];
        });
        return;
      }
    }
    final piece = _engine.pieceAt(pos);
    if (piece != null && piece.color == _engine.turn) {
      setState(() {
        _selected = pos;
        _legalForSelected = _engine.legalMovesFrom(pos);
      });
    } else {
      setState(() {
        _selected = null;
        _legalForSelected = [];
      });
    }
  }

  void _commit(Move move) {
    _engine.makeMove(move);
    setState(() {
      _selected = null;
      _legalForSelected = [];
      _lastMove = move;
    });
  }

  Future<void> _askPromotion(Position to) async {
    final engine = _engine;
    final choice = await showDialog<PieceType>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Coronar a...'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]
              .map((t) => IconButton(
                    iconSize: 36,
                    icon: PieceIcon(type: t, fill: _pieceFill(engine.turn), outline: _pieceOutline(engine.turn), size: 32),
                    onPressed: () => Navigator.of(ctx).pop(t),
                  ))
              .toList(),
        ),
      ),
    );
    if (choice == null) return;
    final move = _legalForSelected.firstWhere((m) => m.to == to && m.promotion == choice);
    _commit(move);
  }

  String? _statusMessage() {
    switch (_engine.status) {
      case GameStatus.checkmate:
        final winner = _engine.turn == PieceColor.white ? 'Negras' : 'Blancas';
        return 'Jaque mate — ganan $winner';
      case GameStatus.stalemate:
        return 'Ahogado — tablas';
      case GameStatus.drawFiftyMoves:
        return 'Tablas por regla de 50 movimientos';
      case GameStatus.drawThreefoldRepetition:
        return 'Tablas por triple repetición';
      case GameStatus.drawInsufficientMaterial:
        return 'Tablas por material insuficiente';
      case GameStatus.ongoing:
        if (_engine.inCheck(_engine.turn)) {
          final side = _engine.turn == PieceColor.white ? 'Blancas' : 'Negras';
          return 'Jaque a $side';
        }
        return null;
    }
  }

  BoxDecoration _squareDecoration(int r, int c, bool isSelected, bool isLastMove, BoardThemeConfig theme) {
    final isLight = (r + c).isEven;
    final gradient = isLight ? theme.lightSquareGradient : theme.darkSquareGradient;
    final color = isLight ? theme.lightSquare : theme.darkSquare;
    return BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: theme.squareCornerRadius > 0 ? BorderRadius.circular(theme.squareCornerRadius) : null,
      border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    final gameOver = engine.status != GameStatus.ongoing;
    final status = _statusMessage();
    final turnLabel = engine.turn == PieceColor.white ? 'Blancas' : 'Negras';
    final theme = boardThemes[BoardVisual.clasico]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Jugar solo · Turno: $turnLabel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reiniciar tablero', onPressed: _reiniciar),
        ],
      ),
      body: Column(
        children: [
          _CapturedRow(material: _computeMaterial(engine)),
          if (status != null)
            Container(
              width: double.infinity,
              color: gameOver ? Colors.red.shade50 : Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(status, textAlign: TextAlign.center),
            ),
          Expanded(
            child: Center(
              child: _BoardArea(
                theme: theme,
                boardBuilder: () => AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final r = index ~/ 8;
                      final c = index % 8;
                      final pos = Position(r, c);
                      final piece = engine.pieceAt(pos);
                      final isSelected = _selected == pos;
                      final isLastMove = _lastMove != null && (_lastMove!.from == pos || _lastMove!.to == pos);
                      final targetMove = _legalForSelected.where((m) => m.to == pos).toList();
                      final isTarget = targetMove.isNotEmpty;
                      final isCapture = isTarget && (piece != null || targetMove.first.isEnPassant);
                      return GestureDetector(
                        onTap: gameOver ? null : () => _selectSquare(pos),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(decoration: _squareDecoration(r, c, isSelected, isLastMove, theme)),
                            if (isLastMove && theme.lastMoveHighlight != null) Container(color: theme.lastMoveHighlight),
                            if (piece != null) _pieceGlyph(piece),
                            if (isTarget)
                              isCapture
                                  ? Container(
                                      margin: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.blueAccent, width: 3),
                                      ),
                                    )
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                    ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Fase 6: partida de torneo (deep link desde Gameros)
///
/// A diferencia de OnlineLobbyScreen (matchmaking libre, rival al azar), acá
/// los dos jugadores ya están decididos de antemano por el cruce del
/// bracket de Gameros -- solo hay que armar (o engancharse a) la partida
/// puntual de ese cruce y arrancar a jugar. Al terminar, el resultado se
/// reporta solo de vuelta a Gameros (ver reportarResultadoTorneo).
/// ---------------------------------------------------------------------------
class TorneoMatchScreen extends StatefulWidget {
  final String torneoPartidaId;
  final String rivalUsuarioId;
  final String inscPropia;
  final String inscRival;
  final String tipoLlave;

  const TorneoMatchScreen({
    super.key,
    required this.torneoPartidaId,
    required this.rivalUsuarioId,
    required this.inscPropia,
    required this.inscRival,
    required this.tipoLlave,
  });

  @override
  State<TorneoMatchScreen> createState() => _TorneoMatchScreenState();
}

class _TorneoMatchScreenState extends State<TorneoMatchScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _entrar());
  }

  Future<void> _entrar() async {
    if (supabase.auth.currentUser == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
      if (!mounted) return;
      if (supabase.auth.currentUser == null) {
        Navigator.of(context).pop();
        return;
      }
    }
    try {
      final partida = await iniciarPartidaTorneo(
        torneoPartidaId: widget.torneoPartidaId,
        rivalUsuarioId: widget.rivalUsuarioId,
        inscPropia: widget.inscPropia,
        inscRival: widget.inscRival,
        tipoLlave: widget.tipoLlave,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnlineGameScreen(partida: partida)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo iniciar la partida del torneo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partida de torneo')),
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
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Preparando la partida del torneo...'),
                  ],
                ),
        ),
      ),
    );
  }
}
