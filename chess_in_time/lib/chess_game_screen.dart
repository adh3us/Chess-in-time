import 'package:flutter/material.dart';
import 'local_chess_engine.dart';
import 'fischer_clock.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — FASE 3
/// Extiende la pantalla de la Fase 2 con: selector de modalidad de tiempo,
/// reloj Fischer en vivo (con alerta bajo 30 segundos), y botón "Rendirse"
/// con confirmación. Reusa el motor y el tablero de las fases anteriores
/// sin modificarlos.
/// ---------------------------------------------------------------------------

const Map<PieceColor, Map<PieceType, String>> _symbols = {
  PieceColor.white: {
    PieceType.pawn: '♙', PieceType.knight: '♘', PieceType.bishop: '♗',
    PieceType.rook: '♖', PieceType.queen: '♕', PieceType.king: '♔',
  },
  PieceColor.black: {
    PieceType.pawn: '♟', PieceType.knight: '♞', PieceType.bishop: '♝',
    PieceType.rook: '♜', PieceType.queen: '♛', PieceType.king: '♚',
  },
};

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
                    icon: Text(_symbols[engine.turn]![t]!, style: const TextStyle(fontSize: 32)),
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

  Color _squareColor(int r, int c) => (r + c).isEven ? Colors.grey.shade100 : Colors.grey.shade300;

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
        appBar: AppBar(title: const Text('Elegí modalidad')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: ClockModality.all
              .map((m) => Card(
                    child: ListTile(
                      title: Text(m.label),
                      onTap: () => _startGame(m),
                    ),
                  ))
              .toList(),
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
        actions: [
          if (!gameOver)
            TextButton(
              onPressed: _confirmResign,
              child: const Text('Rendirse', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          _ClockRow(clock: clock, running: !gameOver),
          if (status != null)
            Container(
              width: double.infinity,
              color: gameOver ? Colors.red.shade50 : Colors.blue.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(status, textAlign: TextAlign.center),
            ),
          Expanded(
            child: Center(
              child: AspectRatio(
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
                    final targetMove = _legalForSelected.where((m) => m.to == pos).toList();
                    final isTarget = targetMove.isNotEmpty;
                    final isCapture = isTarget && (piece != null || targetMove.first.isEnPassant);

                    return GestureDetector(
                      onTap: gameOver ? null : () => _selectSquare(pos),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _squareColor(r, c),
                          border: isSelected ? Border.all(color: Colors.blueAccent, width: 2) : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (piece != null)
                              Text(_symbols[piece.color]![piece.type]!, style: const TextStyle(fontSize: 26)),
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
                      ),
                    );
                  },
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
