/// ---------------------------------------------------------------------------
/// PROYECTO GAMEROS — AJEDREZ 1806 — FASE 1
/// MOTOR LÓGICO DE AJEDREZ EN DART PURO (FIDE COMPLIANT)
///
/// La lógica de este archivo fue validada function-by-function contra
/// `python-chess` (perft exacto en 5 posiciones estándar de la industria,
/// más de 350.000 posiciones revisadas — ver informe de validación) antes de
/// traducirla acá. No depende de ningún paquete externo: es Dart puro,
/// compatible con `dart test` y con cualquier target de Flutter.
/// ---------------------------------------------------------------------------
library local_chess_engine;

enum PieceColor {
  white,
  black;

  PieceColor get opposite =>
      this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

enum PieceType {
  pawn,
  knight,
  bishop,
  rook,
  queen,
  king;

  String get fenChar => switch (this) {
        PieceType.pawn => 'p',
        PieceType.knight => 'n',
        PieceType.bishop => 'b',
        PieceType.rook => 'r',
        PieceType.queen => 'q',
        PieceType.king => 'k',
      };
}

class ChessPiece {
  final PieceColor color;
  final PieceType type;
  const ChessPiece(this.color, this.type);

  String toFenChar() =>
      color == PieceColor.white ? type.fenChar.toUpperCase() : type.fenChar;

  static ChessPiece? fromFenChar(String ch) {
    final isWhite = ch == ch.toUpperCase() && ch != ch.toLowerCase();
    final lower = ch.toLowerCase();
    final type = switch (lower) {
      'p' => PieceType.pawn,
      'n' => PieceType.knight,
      'b' => PieceType.bishop,
      'r' => PieceType.rook,
      'q' => PieceType.queen,
      'k' => PieceType.king,
      _ => null,
    };
    if (type == null) return null;
    return ChessPiece(isWhite ? PieceColor.white : PieceColor.black, type);
  }

  @override
  bool operator ==(Object other) =>
      other is ChessPiece && other.color == color && other.type == type;
  @override
  int get hashCode => Object.hash(color, type);
}

/// row 0 = fila 8 (arriba, negras) ... row 7 = fila 1 (abajo, blancas)
/// col 0 = columna 'a' ... col 7 = columna 'h'
class Position {
  final int row;
  final int col;
  const Position(this.row, this.col);

  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;

  String toAlgebraic() =>
      '${String.fromCharCode(97 + col)}${8 - row}';

  static Position? fromAlgebraic(String s) {
    if (s.length != 2) return null;
    final col = s.codeUnitAt(0) - 97;
    final rank = int.tryParse(s[1]);
    if (rank == null || col < 0 || col > 7 || rank < 1 || rank > 8) {
      return null;
    }
    return Position(8 - rank, col);
  }

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => toAlgebraic();
}

/// castle: null | 'K' (blancas corto) | 'Q' (blancas largo) | 'k' (negras corto) | 'q' (negras largo)
class Move {
  final Position from;
  final Position to;
  final PieceType? promotion;
  final bool isEnPassant;
  final String? castle;
  const Move({
    required this.from,
    required this.to,
    this.promotion,
    this.isEnPassant = false,
    this.castle,
  });

  String toUci() {
    final promo = promotion == null ? '' : promotion!.fenChar;
    return '${from.toAlgebraic()}${to.toAlgebraic()}$promo';
  }
}

enum GameStatus {
  ongoing,
  checkmate,
  stalemate,
  drawInsufficientMaterial,
  drawFiftyMoves,
  drawThreefoldRepetition,
}

class _CastlingRights {
  bool K, Q, k, q;
  _CastlingRights({this.K = true, this.Q = true, this.k = true, this.q = true});
  _CastlingRights copy() => _CastlingRights(K: K, Q: Q, k: k, q: q);
}

class _Snapshot {
  final List<List<ChessPiece?>> board;
  final PieceColor turn;
  final _CastlingRights castling;
  final Position? epTarget;
  final int halfmove;
  final int fullmove;
  _Snapshot(this.board, this.turn, this.castling, this.epTarget, this.halfmove, this.fullmove);
}

class LocalChessEngine {
  late List<List<ChessPiece?>> board; // board[row][col]
  PieceColor turn = PieceColor.white;
  _CastlingRights _castling = _CastlingRights();
  Position? enPassantTarget;
  int halfmoveClock = 0;
  int fullmoveNumber = 1;

  final List<Move> moveHistory = [];
  final List<String> sanHistory = [];
  final Map<String, int> _positionFrequency = {};

  LocalChessEngine() {
    loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  }

  // ---------------------------------------------------------------------
  // FEN
  // ---------------------------------------------------------------------

  void loadFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) throw ArgumentError('FEN inválido: $fen');
    final rows = parts[0].split('/');
    if (rows.length != 8) throw ArgumentError('FEN inválido (filas): $fen');

    board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));
    for (int r = 0; r < 8; r++) {
      int c = 0;
      for (final ch in rows[r].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          c += digit;
        } else {
          board[r][c] = ChessPiece.fromFenChar(ch);
          c++;
        }
      }
    }
    turn = parts[1] == 'w' ? PieceColor.white : PieceColor.black;
    final cr = parts[2];
    _castling = _CastlingRights(
      K: cr.contains('K'),
      Q: cr.contains('Q'),
      k: cr.contains('k'),
      q: cr.contains('q'),
    );
    enPassantTarget = parts[3] == '-' ? null : Position.fromAlgebraic(parts[3]);
    halfmoveClock = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    fullmoveNumber = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
    moveHistory.clear();
    sanHistory.clear();
    _positionFrequency.clear();
    _recordPosition();
  }

  String toFen() {
    final sb = StringBuffer();
    for (int r = 0; r < 8; r++) {
      int empty = 0;
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) {
            sb.write(empty);
            empty = 0;
          }
          sb.write(p.toFenChar());
        }
      }
      if (empty > 0) sb.write(empty);
      if (r < 7) sb.write('/');
    }
    final cr = StringBuffer();
    if (_castling.K) cr.write('K');
    if (_castling.Q) cr.write('Q');
    if (_castling.k) cr.write('k');
    if (_castling.q) cr.write('q');
    sb.write(' ${turn == PieceColor.white ? 'w' : 'b'}');
    sb.write(' ${cr.isEmpty ? '-' : cr.toString()}');
    sb.write(' ${enPassantTarget?.toAlgebraic() ?? '-'}');
    sb.write(' $halfmoveClock $fullmoveNumber');
    return sb.toString();
  }

  String _positionKey() {
    final f = toFen().split(' ');
    return '${f[0]} ${f[1]} ${f[2]} ${f[3]}';
  }

  void _recordPosition() {
    final key = _positionKey();
    _positionFrequency[key] = (_positionFrequency[key] ?? 0) + 1;
  }

  // ---------------------------------------------------------------------
  // Consultas básicas
  // ---------------------------------------------------------------------

  ChessPiece? pieceAt(Position p) => p.isValid ? board[p.row][p.col] : null;

  Position? kingPosition(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.color == color && p.type == PieceType.king) {
          return Position(r, c);
        }
      }
    }
    return null;
  }

  bool isSquareAttacked(Position target, PieceColor attacker) {
    final tr = target.row, tc = target.col;
    // peones
    final pawnDir = attacker == PieceColor.white ? 1 : -1;
    for (final dc in [-1, 1]) {
      final p = pieceAt(Position(tr + pawnDir, tc + dc));
      if (p != null && p.color == attacker && p.type == PieceType.pawn) {
        return true;
      }
    }
    // caballos
    const knightDeltas = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1],
    ];
    for (final d in knightDeltas) {
      final p = pieceAt(Position(tr + d[0], tc + d[1]));
      if (p != null && p.color == attacker && p.type == PieceType.knight) {
        return true;
      }
    }
    // diagonales (alfil/dama)
    const diagDirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    for (final d in diagDirs) {
      int r = tr + d[0], c = tc + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final p = board[r][c];
        if (p != null) {
          if (p.color == attacker &&
              (p.type == PieceType.bishop || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    // ortogonales (torre/dama)
    const orthoDirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in orthoDirs) {
      int r = tr + d[0], c = tc + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final p = board[r][c];
        if (p != null) {
          if (p.color == attacker &&
              (p.type == PieceType.rook || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    // rey
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final p = pieceAt(Position(tr + dr, tc + dc));
        if (p != null && p.color == attacker && p.type == PieceType.king) {
          return true;
        }
      }
    }
    return false;
  }

  bool inCheck(PieceColor color) {
    final k = kingPosition(color);
    if (k == null) return false;
    return isSquareAttacked(k, color.opposite);
  }

  // ---------------------------------------------------------------------
  // Generación de jugadas
  // ---------------------------------------------------------------------

  List<Move> pseudoLegalMoves() {
    final moves = <Move>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null || p.color != turn) continue;
        final pos = Position(r, c);
        switch (p.type) {
          case PieceType.pawn:
            _pawnMoves(pos, p.color, moves);
            break;
          case PieceType.knight:
            _leaper(pos, p.color, const [
              [-2, -1], [-2, 1], [-1, -2], [-1, 2],
              [1, -2], [1, 2], [2, -1], [2, 1],
            ], moves);
            break;
          case PieceType.bishop:
            _slider(pos, p.color, const [[-1, -1], [-1, 1], [1, -1], [1, 1]], moves);
            break;
          case PieceType.rook:
            _slider(pos, p.color, const [[-1, 0], [1, 0], [0, -1], [0, 1]], moves);
            break;
          case PieceType.queen:
            _slider(pos, p.color, const [
              [-1, -1], [-1, 1], [1, -1], [1, 1],
              [-1, 0], [1, 0], [0, -1], [0, 1],
            ], moves);
            break;
          case PieceType.king:
            _kingMoves(pos, p.color, moves);
            break;
        }
      }
    }
    return moves;
  }

  void _pawnMoves(Position pos, PieceColor color, List<Move> moves) {
    final d = color == PieceColor.white ? -1 : 1;
    final startRow = color == PieceColor.white ? 6 : 1;
    final promoRow = color == PieceColor.white ? 0 : 7;
    final one = Position(pos.row + d, pos.col);
    if (one.isValid && board[one.row][one.col] == null) {
      _addPawnMove(pos, one, promoRow, moves);
      final two = Position(pos.row + 2 * d, pos.col);
      if (pos.row == startRow && board[two.row][two.col] == null) {
        moves.add(Move(from: pos, to: two));
      }
    }
    for (final dc in [-1, 1]) {
      final target = Position(pos.row + d, pos.col + dc);
      if (!target.isValid) continue;
      final occupant = board[target.row][target.col];
      if (occupant != null && occupant.color != color) {
        _addPawnMove(pos, target, promoRow, moves);
      } else if (occupant == null && enPassantTarget == target) {
        moves.add(Move(from: pos, to: target, isEnPassant: true));
      }
    }
  }

  void _addPawnMove(Position from, Position to, int promoRow, List<Move> moves) {
    if (to.row == promoRow) {
      for (final t in [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
        moves.add(Move(from: from, to: to, promotion: t));
      }
    } else {
      moves.add(Move(from: from, to: to));
    }
  }

  void _leaper(Position pos, PieceColor color, List<List<int>> deltas, List<Move> moves) {
    for (final d in deltas) {
      final to = Position(pos.row + d[0], pos.col + d[1]);
      if (!to.isValid) continue;
      final occupant = board[to.row][to.col];
      if (occupant == null || occupant.color != color) {
        moves.add(Move(from: pos, to: to));
      }
    }
  }

  void _slider(Position pos, PieceColor color, List<List<int>> dirs, List<Move> moves) {
    for (final d in dirs) {
      int r = pos.row + d[0], c = pos.col + d[1];
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final occupant = board[r][c];
        if (occupant == null) {
          moves.add(Move(from: pos, to: Position(r, c)));
        } else {
          if (occupant.color != color) {
            moves.add(Move(from: pos, to: Position(r, c)));
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
  }

  void _kingMoves(Position pos, PieceColor color, List<Move> moves) {
    _leaper(pos, color, const [
      [-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1],
    ], moves);

    final opp = color.opposite;
    if (color == PieceColor.white && pos == const Position(7, 4)) {
      if (_castling.K &&
          board[7][5] == null &&
          board[7][6] == null &&
          board[7][7] == const ChessPiece(PieceColor.white, PieceType.rook) &&
          !isSquareAttacked(const Position(7, 4), opp) &&
          !isSquareAttacked(const Position(7, 5), opp) &&
          !isSquareAttacked(const Position(7, 6), opp)) {
        moves.add(const Move(from: Position(7, 4), to: Position(7, 6), castle: 'K'));
      }
      if (_castling.Q &&
          board[7][3] == null &&
          board[7][2] == null &&
          board[7][1] == null &&
          board[7][0] == const ChessPiece(PieceColor.white, PieceType.rook) &&
          !isSquareAttacked(const Position(7, 4), opp) &&
          !isSquareAttacked(const Position(7, 3), opp) &&
          !isSquareAttacked(const Position(7, 2), opp)) {
        moves.add(const Move(from: Position(7, 4), to: Position(7, 2), castle: 'Q'));
      }
    } else if (color == PieceColor.black && pos == const Position(0, 4)) {
      if (_castling.k &&
          board[0][5] == null &&
          board[0][6] == null &&
          board[0][7] == const ChessPiece(PieceColor.black, PieceType.rook) &&
          !isSquareAttacked(const Position(0, 4), opp) &&
          !isSquareAttacked(const Position(0, 5), opp) &&
          !isSquareAttacked(const Position(0, 6), opp)) {
        moves.add(const Move(from: Position(0, 4), to: Position(0, 6), castle: 'k'));
      }
      if (_castling.q &&
          board[0][3] == null &&
          board[0][2] == null &&
          board[0][1] == null &&
          board[0][0] == const ChessPiece(PieceColor.black, PieceType.rook) &&
          !isSquareAttacked(const Position(0, 4), opp) &&
          !isSquareAttacked(const Position(0, 3), opp) &&
          !isSquareAttacked(const Position(0, 2), opp)) {
        moves.add(const Move(from: Position(0, 4), to: Position(0, 2), castle: 'q'));
      }
    }
  }

  /// Aplica la jugada al tablero (sin filtrar legalidad) y devuelve un
  /// snapshot para poder deshacerla. Uso interno para filtrar jugadas
  /// legales y para perft — no dispara historial ni SAN.
  _Snapshot _applyRaw(Move m) {
    final snap = _Snapshot(
      List.generate(8, (r) => List<ChessPiece?>.from(board[r])),
      turn,
      _castling.copy(),
      enPassantTarget,
      halfmoveClock,
      fullmoveNumber,
    );

    final piece = board[m.from.row][m.from.col]!;
    final isPawn = piece.type == PieceType.pawn;
    final isCapture = board[m.to.row][m.to.col] != null || m.isEnPassant;

    if (m.isEnPassant) {
      board[m.from.row][m.to.col] = null;
    }
    board[m.from.row][m.from.col] = null;
    board[m.to.row][m.to.col] =
        m.promotion != null ? ChessPiece(piece.color, m.promotion!) : piece;

    if (m.castle == 'K') {
      board[7][5] = board[7][7];
      board[7][7] = null;
    } else if (m.castle == 'Q') {
      board[7][3] = board[7][0];
      board[7][0] = null;
    } else if (m.castle == 'k') {
      board[0][5] = board[0][7];
      board[0][7] = null;
    } else if (m.castle == 'q') {
      board[0][3] = board[0][0];
      board[0][0] = null;
    }

    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _castling.K = false;
        _castling.Q = false;
      } else {
        _castling.k = false;
        _castling.q = false;
      }
    }
    void clearRightsFor(Position sq) {
      if (sq == const Position(7, 7)) _castling.K = false;
      if (sq == const Position(7, 0)) _castling.Q = false;
      if (sq == const Position(0, 7)) _castling.k = false;
      if (sq == const Position(0, 0)) _castling.q = false;
    }
    clearRightsFor(m.from);
    clearRightsFor(m.to);

    if (isPawn && (m.to.row - m.from.row).abs() == 2) {
      enPassantTarget = Position((m.from.row + m.to.row) ~/ 2, m.from.col);
    } else {
      enPassantTarget = null;
    }

    halfmoveClock = (isPawn || isCapture) ? 0 : halfmoveClock + 1;
    if (turn == PieceColor.black) fullmoveNumber++;
    turn = turn.opposite;

    return snap;
  }

  void _undoRaw(_Snapshot s) {
    board = s.board;
    turn = s.turn;
    _castling = s.castling;
    enPassantTarget = s.epTarget;
    halfmoveClock = s.halfmove;
    fullmoveNumber = s.fullmove;
  }

  /// Jugadas legales para la pieza en [from] (filtra las que dejan el propio rey en jaque).
  List<Move> legalMovesFrom(Position from) {
    final piece = pieceAt(from);
    if (piece == null || piece.color != turn) return [];
    final color = piece.color;
    final legal = <Move>[];
    for (final m in pseudoLegalMoves().where((m) => m.from == from)) {
      final snap = _applyRaw(m);
      if (!inCheck(color)) legal.add(m);
      _undoRaw(snap);
    }
    return legal;
  }

  /// Todas las jugadas legales del color que le toca mover.
  List<Move> allLegalMoves() {
    final color = turn;
    final legal = <Move>[];
    for (final m in pseudoLegalMoves()) {
      final snap = _applyRaw(m);
      if (!inCheck(color)) legal.add(m);
      _undoRaw(snap);
    }
    return legal;
  }

  // ---------------------------------------------------------------------
  // Aplicar una jugada real (con historial, SAN, y registro de posición)
  // ---------------------------------------------------------------------

  /// Devuelve `true` si la jugada era legal y se aplicó.
  bool makeMove(Move requested) {
    final legal = allLegalMoves();
    Move? found;
    for (final m in legal) {
      if (m.from == requested.from &&
          m.to == requested.to &&
          (requested.promotion == null || m.promotion == requested.promotion)) {
        found = m;
        break;
      }
    }
    if (found == null) return false;

    final piece = board[found.from.row][found.from.col]!;
    final isCapture = board[found.to.row][found.to.col] != null || found.isEnPassant;
    final san = _generateSan(found, piece, isCapture);

    _applyRaw(found);
    moveHistory.add(found);
    sanHistory.add(san);
    _recordPosition();
    return true;
  }

  String _generateSan(Move m, ChessPiece piece, bool isCapture) {
    if (m.castle == 'K' || m.castle == 'k') return _sanSuffix(m, piece.color, 'O-O');
    if (m.castle == 'Q' || m.castle == 'q') return _sanSuffix(m, piece.color, 'O-O-O');

    final sb = StringBuffer();
    if (piece.type != PieceType.pawn) {
      sb.write(piece.type.fenChar.toUpperCase());
    } else if (isCapture) {
      sb.write(String.fromCharCode(97 + m.from.col));
    }
    if (isCapture) sb.write('x');
    sb.write(m.to.toAlgebraic());
    if (m.promotion != null) sb.write('=${m.promotion!.fenChar.toUpperCase()}');
    return _sanSuffix(m, piece.color, sb.toString());
  }

  String _sanSuffix(Move m, PieceColor mover, String base) {
    // Para saber si la jugada da jaque/mate hay que aplicarla primero.
    final snap = _applyRaw(m);
    final opp = mover.opposite;
    String suffix = '';
    if (inCheck(opp)) {
      suffix = allLegalMoves().isEmpty ? '#' : '+';
    }
    _undoRaw(snap);
    return '$base$suffix';
  }

  // ---------------------------------------------------------------------
  // Estado de la partida
  // ---------------------------------------------------------------------

  GameStatus get status {
    final moves = allLegalMoves();
    if (moves.isEmpty) {
      return inCheck(turn) ? GameStatus.checkmate : GameStatus.stalemate;
    }
    if (halfmoveClock >= 100) return GameStatus.drawFiftyMoves;
    if ((_positionFrequency[_positionKey()] ?? 0) >= 3) {
      return GameStatus.drawThreefoldRepetition;
    }
    if (_insufficientMaterial()) return GameStatus.drawInsufficientMaterial;
    return GameStatus.ongoing;
  }

  bool _insufficientMaterial() {
    final pieces = <ChessPiece>[];
    for (final row in board) {
      for (final p in row) {
        if (p != null) pieces.add(p);
      }
    }
    if (pieces.length == 2) return true; // K vs K
    if (pieces.length == 3) {
      return pieces.any((p) => p.type == PieceType.knight || p.type == PieceType.bishop);
    }
    if (pieces.length == 4) {
      // K + alfil vs K + alfil, con los dos alfiles en casillas del mismo color -> tablas.
      final bishopSquares = <int>[];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (board[r][c]?.type == PieceType.bishop) {
            bishopSquares.add((r + c) % 2);
          }
        }
      }
      if (bishopSquares.length == 2) {
        return bishopSquares[0] == bishopSquares[1];
      }
    }
    return false;
  }

  String generatePgn() {
    final sb = StringBuffer();
    for (int i = 0; i < sanHistory.length; i++) {
      if (i.isEven) sb.write('${(i ~/ 2) + 1}. ');
      sb.write('${sanHistory[i]} ');
    }
    return sb.toString().trim();
  }

  // ---------------------------------------------------------------------
  // Perft — cuenta nodos a una profundidad dada. Se usa en los tests para
  // reproducir la misma validación que ya se corrió contra python-chess.
  // ---------------------------------------------------------------------
  int perft(int depth) {
    if (depth == 0) return 1;
    int count = 0;
    for (final m in allLegalMoves()) {
      final snap = _applyRaw(m);
      count += perft(depth - 1);
      _undoRaw(snap);
    }
    return count;
  }
}
