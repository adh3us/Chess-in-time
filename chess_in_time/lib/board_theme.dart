import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Niveles de visualización del tablero
/// Dos niveles dentro del mismo estilo "liviano" de la Fase 4: sin imágenes,
/// sin sprites, sin assets externos — todo resuelto con color/gradiente de
/// Flutter puro. Ninguno toca la lógica del juego (motor y reglas quedan
/// exactamente igual), y ninguno toca cómo se dibujan las piezas — eso fue
/// la fuente de todos los problemas de contraste en el intento anterior con
/// 3 niveles (Medio se sacó por decisión de Lucas). Alto solo cambia el
/// tablero: colores, marco y coordenadas.
/// ---------------------------------------------------------------------------

enum BoardVisual { basico, alto }

class BoardThemeConfig {
  final String label;
  final String description;
  final Color lightSquare;
  final Color darkSquare;
  final Gradient? lightSquareGradient;
  final Gradient? darkSquareGradient;
  final Color? lastMoveHighlight;
  final bool showCoordinates;
  final bool framed;
  final Color frameColor;

  const BoardThemeConfig({
    required this.label,
    required this.description,
    required this.lightSquare,
    required this.darkSquare,
    this.lightSquareGradient,
    this.darkSquareGradient,
    this.lastMoveHighlight,
    this.showCoordinates = false,
    this.framed = false,
    this.frameColor = Colors.transparent,
  });
}

final Map<BoardVisual, BoardThemeConfig> boardThemes = {
  BoardVisual.basico: BoardThemeConfig(
    label: 'Básico',
    description: 'El clásico: dos colores lisos, sin marco ni sombras.',
    lightSquare: Colors.grey.shade100,
    darkSquare: Colors.grey.shade300,
  ),
  BoardVisual.alto: BoardThemeConfig(
    label: 'Alto',
    description: 'Casillas con degradé cálido, coordenadas a-h/1-8 y marco con relieve.',
    lightSquare: const Color(0xFFF0D9B5),
    darkSquare: const Color(0xFFB58863),
    lightSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFF7E6C8), const Color(0xFFE6C99A)],
    ),
    darkSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFC49A6C), const Color(0xFF9C6F44)],
    ),
    lastMoveHighlight: const Color(0x664FC3F7),
    showCoordinates: true,
    framed: true,
    frameColor: const Color(0xFF5D4630),
  ),
};
