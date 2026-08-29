import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Niveles de visualización del tablero
/// Tres niveles dentro del mismo estilo "liviano" de la Fase 4: sin imágenes,
/// sin sprites, sin assets externos — todo resuelto con color/gradiente/sombra
/// de Flutter puro. Cada nivel es más rico que el anterior, pero ninguno
/// toca la lógica del juego (motor y reglas quedan exactamente igual).
/// ---------------------------------------------------------------------------

enum BoardVisual { basico, medio, alto }

class BoardThemeConfig {
  final String label;
  final String description;
  final Color lightSquare;
  final Color darkSquare;
  final Gradient? lightSquareGradient;
  final Gradient? darkSquareGradient;
  final Color? lastMoveHighlight;
  final bool pieceShadow;
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
    this.pieceShadow = false,
    this.showCoordinates = false,
    this.framed = false,
    this.frameColor = Colors.transparent,
  });
}

final Map<BoardVisual, BoardThemeConfig> boardThemes = {
  BoardVisual.basico: BoardThemeConfig(
    label: 'Básico',
    description: 'El actual: dos colores lisos, sin marco ni sombras.',
    lightSquare: Colors.grey.shade100,
    darkSquare: Colors.grey.shade300,
  ),
  BoardVisual.medio: BoardThemeConfig(
    label: 'Medio',
    description: 'Casillas con leve degradé, sombra en las piezas y resalte de la última jugada.',
    lightSquare: const Color(0xFFEDE6D6),
    darkSquare: const Color(0xFF7C9473),
    lightSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFF3EEE1), const Color(0xFFE3D9C2)],
    ),
    darkSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF87A17C), const Color(0xFF6D8863)],
    ),
    lastMoveHighlight: const Color(0x664FC3F7),
    pieceShadow: true,
  ),
  BoardVisual.alto: BoardThemeConfig(
    label: 'Alto',
    description: 'Todo lo de Medio, más coordenadas a-h/1-8 y marco con relieve.',
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
    pieceShadow: true,
    showCoordinates: true,
    framed: true,
    frameColor: const Color(0xFF5D4630),
  ),
};
