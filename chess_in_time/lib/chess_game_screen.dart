import 'package:flutter/material.dart';
import 'local_chess_engine.dart';
import 'fischer_clock.dart';
import 'board_theme.dart';
import 'piece_icons.dart';
import 'auth_gate.dart';

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
        appBar: AppBar(
          title: const Text('Elegí modalidad'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle),
              tooltip: 'Mi cuenta',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
            ),
          ],
        ),
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
