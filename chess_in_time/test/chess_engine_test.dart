import 'package:test/test.dart';
import 'package:chess_in_time/local_chess_engine.dart';

void main() {
  group('Posición inicial', () {
    test('20 jugadas legales para blancas al arranque', () {
      final e = LocalChessEngine();
      expect(e.allLegalMoves().length, 20);
    });

    test('FEN inicial se exporta igual a como se cargó', () {
      final e = LocalChessEngine();
      expect(e.toFen(), 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    });
  });

  group('Perft — validado contra python-chess (ver informe de validación)', () {
    // Estos números son el estándar de la industria para probar motores de
    // ajedrez (Chess Programming Wiki - Perft Results). Si alguno falla acá,
    // hay un bug real en la generación de jugadas o en el filtro de legalidad.
    test('posición inicial: perft(1)=20, perft(2)=400, perft(3)=8902', () {
      final e = LocalChessEngine();
      expect(e.perft(1), 20);
      expect(e.perft(2), 400);
      expect(e.perft(3), 8902);
    });

    test('Kiwipete (enroque + al paso + capturas): perft(1)=48, perft(2)=2039', () {
      final e = LocalChessEngine()
        ..loadFen('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      expect(e.perft(1), 48);
      expect(e.perft(2), 2039);
    });

    test('posición con promociones tempranas: perft(1)=14, perft(2)=191, perft(3)=2812', () {
      final e = LocalChessEngine()
        ..loadFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
      expect(e.perft(1), 14);
      expect(e.perft(2), 191);
      expect(e.perft(3), 2812);
    });

    test('enroque + promoción combinados: perft(1)=6, perft(2)=264', () {
      final e = LocalChessEngine()
        ..loadFen('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
      expect(e.perft(1), 6);
      expect(e.perft(2), 264);
    });
  });

  group('Jaque mate y ahogado', () {
    test('mate del pastor (Scholar\'s mate) se detecta como checkmate', () {
      final e = LocalChessEngine()
        ..loadFen('r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4');
      expect(e.status, GameStatus.checkmate);
    });

    test('mate del loco (Fool\'s mate) se detecta como checkmate', () {
      final e = LocalChessEngine()
        ..loadFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
      expect(e.status, GameStatus.checkmate);
    });

    test('posición de ahogado (sin jaque, sin jugadas) se detecta como stalemate', () {
      final e = LocalChessEngine()..loadFen('7k/5K2/6Q1/8/8/8/8/8 b - - 0 1');
      expect(e.status, GameStatus.stalemate);
    });

    test('posición inicial está en curso', () {
      final e = LocalChessEngine();
      expect(e.status, GameStatus.ongoing);
    });
  });

  group('Captura al paso', () {
    test('captura al paso disponible justo después del doble paso rival', () {
      final e = LocalChessEngine()
        ..loadFen('rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      final legal = e.allLegalMoves();
      final epMove = legal.where((m) =>
          m.isEnPassant && m.from == const Position(3, 4) && m.to == const Position(2, 5));
      expect(epMove.length, 1, reason: 'exf6 al paso debería ser una jugada legal');
    });

    test('la captura al paso desaparece si no se juega en el turno inmediato', () {
      final e = LocalChessEngine()
        ..loadFen('rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      // Blancas juegan otra cosa en vez de capturar al paso.
      e.makeMove(const Move(from: Position(6, 0), to: Position(5, 0))); // a3
      e.makeMove(const Move(from: Position(1, 0), to: Position(2, 0))); // a6 (negras)
      expect(e.enPassantTarget, isNull);
    });
  });

  group('Enroque', () {
    test('enroque corto blanco disponible con casillas libres y sin jaque', () {
      final e = LocalChessEngine()
        ..loadFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final legal = e.allLegalMoves();
      expect(legal.any((m) => m.castle == 'K'), isTrue);
    });

    test('enroque bloqueado si el rey pasa por una casilla atacada', () {
      // Torre negra en e8 hipotética no aplica; se arma un jaque de paso sobre f1.
      final e = LocalChessEngine()
        ..loadFen('4k3/8/8/8/8/5r2/8/R3K2R w KQ - 0 1');
      final legal = e.allLegalMoves();
      expect(legal.any((m) => m.castle == 'K'), isFalse,
          reason: 'la torre negra en f3 ataca f1, el rey no puede pasar por ahí');
    });

    test('enroque bloqueado si el rey está actualmente en jaque', () {
      final e = LocalChessEngine()
        ..loadFen('4k3/8/8/8/8/8/4r3/R3K2R w KQ - 0 1');
      final legal = e.allLegalMoves();
      expect(legal.any((m) => m.castle == 'K' || m.castle == 'Q'), isFalse);
    });
  });

  group('Coronación', () {
    test('un peón a un paso de coronar genera las 4 opciones de pieza', () {
      final e = LocalChessEngine()..loadFen('8/P6k/8/8/8/8/7K/8 w - - 0 1');
      final legal = e.allLegalMoves().where((m) => m.from == const Position(1, 0));
      final promos = legal.map((m) => m.promotion).toSet();
      expect(promos, {PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight});
    });
  });

  group('Material insuficiente', () {
    test('rey contra rey es tablas por material insuficiente', () {
      final e = LocalChessEngine()..loadFen('k7/8/8/8/8/8/8/7K w - - 0 1');
      expect(e.status, GameStatus.drawInsufficientMaterial);
    });

    test('rey + caballo contra rey es tablas por material insuficiente', () {
      final e = LocalChessEngine()..loadFen('k7/8/8/8/8/8/8/6NK w - - 0 1');
      expect(e.status, GameStatus.drawInsufficientMaterial);
    });

    test('rey + dama contra rey NO es material insuficiente', () {
      final e = LocalChessEngine()..loadFen('k7/8/8/8/8/8/8/6QK w - - 0 1');
      expect(e.status, isNot(GameStatus.drawInsufficientMaterial));
    });
  });

  group('Regla de los 50 movimientos', () {
    test('halfmoveClock en 100 dispara la tablas por 50 movimientos', () {
      final e = LocalChessEngine()
        ..loadFen('7k/8/8/8/8/8/8/R6K w - - 99 60');
      // Una jugada más de torre (sin captura, sin peón) llega a 100.
      e.makeMove(const Move(from: Position(7, 0), to: Position(7, 1)));
      expect(e.status, GameStatus.drawFiftyMoves);
    });

    test('una captura reinicia el contador de 50 movimientos', () {
      // Torre blanca en a3, peón negro en g3 (misma fila) — la torre lo puede capturar.
      final e = LocalChessEngine()
        ..loadFen('7k/8/8/8/8/R5p1/8/7K w - - 50 60');
      final aceptada = e.makeMove(const Move(from: Position(5, 0), to: Position(5, 6))); // Rxg3
      expect(aceptada, isTrue);
      expect(e.halfmoveClock, 0);
    });
  });

  group('Triple repetición', () {
    test('repetir la misma posición 3 veces dispara la tablas', () {
      final e = LocalChessEngine();
      // Caballos yendo y viniendo — misma posición se repite.
      for (int i = 0; i < 2; i++) {
        e.makeMove(const Move(from: Position(7, 1), to: Position(5, 2))); // Nb1-c3
        e.makeMove(const Move(from: Position(0, 1), to: Position(2, 2))); // Nb8-c6
        e.makeMove(const Move(from: Position(5, 2), to: Position(7, 1))); // Nc3-b1
        e.makeMove(const Move(from: Position(2, 2), to: Position(0, 1))); // Nc6-b8
      }
      expect(e.status, GameStatus.drawThreefoldRepetition);
    });
  });

  group('Jugadas ilegales', () {
    test('una pieza clavada contra su propio rey no tiene jugadas legales', () {
      // Torre negra en e8, caballo blanco en e2 (único bloqueo), rey blanco en e1.
      // El caballo está clavado: cualquier jugada suya expone el rey a la torre.
      final e = LocalChessEngine()..loadFen('4r3/8/8/8/8/8/4N3/4K3 w - - 0 1');
      expect(e.inCheck(PieceColor.white), isFalse,
          reason: 'el caballo todavía tapa el jaque');
      final legal = e.allLegalMoves();
      expect(legal.any((m) => m.from == const Position(6, 4)), isFalse,
          reason: 'el caballo clavado no debería tener ninguna jugada legal');
      expect(legal, isNotEmpty, reason: 'el rey sí debería poder moverse fuera de la columna e');
    });

    test('makeMove rechaza una jugada ilegal y no modifica el tablero', () {
      final e = LocalChessEngine();
      final fenAntes = e.toFen();
      final aceptada = e.makeMove(const Move(from: Position(6, 0), to: Position(3, 0))); // peón 3 casillas, ilegal
      expect(aceptada, isFalse);
      expect(e.toFen(), fenAntes);
    });
  });
}
