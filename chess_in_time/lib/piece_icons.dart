import 'package:flutter/material.dart';
import 'local_chess_engine.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Set de piezas propio, dibujado a mano
///
/// Se abandona el glifo Unicode de ajedrez (♔♕♖♗♘♙ / ♚♛♜♝♞♟) por completo:
/// esa fue la fuente de todos los problemas de contraste anteriores (el
/// glifo blanco es un contorno hueco sin relleno por diseño, y sus trazos
/// internos son impredecibles para cualquier técnica de contorno o placa
/// de fondo). Acá cada pieza es una forma vectorial simple, propia, sin
/// depender de ninguna fuente — relleno y contorno bajo control total, así
/// que el contraste queda garantizado en cualquier paleta de tablero.
/// Sin imágenes ni assets externos: es Flutter puro (CustomPainter).
/// ---------------------------------------------------------------------------

class PieceIcon extends StatelessWidget {
  final PieceType type;
  final Color fill;
  final Color outline;
  final double size;

  const PieceIcon({
    super.key,
    required this.type,
    required this.fill,
    required this.outline,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PieceIconPainter(type: type, fill: fill, outline: outline)),
    );
  }
}

class _PieceIconPainter extends CustomPainter {
  final PieceType type;
  final Color fill;
  final Color outline;
  _PieceIconPainter({required this.type, required this.fill, required this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    for (final part in _partsFor(type, w, h)) {
      canvas.drawPath(part, fillPaint);
      canvas.drawPath(part, strokePaint);
    }
  }

  List<Path> _partsFor(PieceType type, double w, double h) {
    switch (type) {
      case PieceType.pawn:
        return [
          Path()..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.32), width: w * 0.34, height: w * 0.34)),
          Path()
            ..addPolygon([
              Offset(w * 0.34, h * 0.55),
              Offset(w * 0.66, h * 0.55),
              Offset(w * 0.78, h * 0.85),
              Offset(w * 0.22, h * 0.85),
            ], true),
        ];
      case PieceType.rook:
        return [
          Path()..addRect(Rect.fromLTWH(w * 0.24, h * 0.42, w * 0.52, h * 0.43)),
          Path()..addRect(Rect.fromLTWH(w * 0.2, h * 0.18, w * 0.15, h * 0.26)),
          Path()..addRect(Rect.fromLTWH(w * 0.425, h * 0.18, w * 0.15, h * 0.26)),
          Path()..addRect(Rect.fromLTWH(w * 0.65, h * 0.18, w * 0.15, h * 0.26)),
          Path()
            ..addPolygon([
              Offset(w * 0.2, h * 0.85),
              Offset(w * 0.8, h * 0.85),
              Offset(w * 0.72, h * 0.95),
              Offset(w * 0.28, h * 0.95),
            ], true),
        ];
      case PieceType.knight:
        return [
          Path()
            ..moveTo(w * 0.32, h * 0.9)
            ..lineTo(w * 0.28, h * 0.55)
            ..cubicTo(w * 0.18, h * 0.4, w * 0.26, h * 0.12, w * 0.52, h * 0.12)
            ..cubicTo(w * 0.72, h * 0.12, w * 0.86, h * 0.26, w * 0.82, h * 0.42)
            ..lineTo(w * 0.66, h * 0.36)
            ..lineTo(w * 0.7, h * 0.5)
            ..lineTo(w * 0.78, h * 0.9)
            ..close(),
        ];
      case PieceType.bishop:
        return [
          Path()..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.18), width: w * 0.14, height: w * 0.14)),
          Path()..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.42, height: h * 0.55)),
          Path()
            ..addPolygon([
              Offset(w * 0.28, h * 0.85),
              Offset(w * 0.72, h * 0.85),
              Offset(w * 0.62, h * 0.95),
              Offset(w * 0.38, h * 0.95),
            ], true),
        ];
      case PieceType.queen:
        return [
          for (final dx in [0.22, 0.37, 0.5, 0.63, 0.78])
            Path()..addOval(Rect.fromCenter(center: Offset(w * dx, h * 0.2), width: w * 0.15, height: w * 0.15)),
          Path()
            ..addPolygon([
              Offset(w * 0.26, h * 0.35),
              Offset(w * 0.74, h * 0.35),
              Offset(w * 0.66, h * 0.85),
              Offset(w * 0.34, h * 0.85),
            ], true),
          Path()
            ..addPolygon([
              Offset(w * 0.22, h * 0.85),
              Offset(w * 0.78, h * 0.85),
              Offset(w * 0.7, h * 0.94),
              Offset(w * 0.3, h * 0.94),
            ], true),
        ];
      case PieceType.king:
        return [
          Path()..addRect(Rect.fromLTWH(w * 0.46, h * 0.03, w * 0.08, h * 0.2)),
          Path()..addRect(Rect.fromLTWH(w * 0.37, h * 0.09, w * 0.26, h * 0.08)),
          Path()
            ..addPolygon([
              Offset(w * 0.27, h * 0.32),
              Offset(w * 0.73, h * 0.32),
              Offset(w * 0.66, h * 0.85),
              Offset(w * 0.34, h * 0.85),
            ], true),
          Path()
            ..addPolygon([
              Offset(w * 0.22, h * 0.85),
              Offset(w * 0.78, h * 0.85),
              Offset(w * 0.7, h * 0.94),
              Offset(w * 0.3, h * 0.94),
            ], true),
        ];
    }
  }

  @override
  bool shouldRepaint(covariant _PieceIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.fill != fill || oldDelegate.outline != outline;
}
