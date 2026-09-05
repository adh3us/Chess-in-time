import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Niveles de visualización del tablero
/// 5 opciones dentro del mismo estilo "liviano" de la Fase 4: sin imágenes,
/// sin sprites, sin assets externos — todo resuelto con color/gradiente de
/// Flutter puro. Ninguna toca la lógica del juego (motor y reglas quedan
/// exactamente igual).
///
/// Piezas: las 6 figuras se dibujan a mano (piece_icons.dart), el mismo set
/// en los 5 temas — el tema acá solo define el tablero (colores, marco,
/// coordenadas). Separar "tablero" de "piezas" evitó repetir el problema de
/// contraste de los intentos anteriores, que mezclaban las dos cosas.
/// ---------------------------------------------------------------------------

enum BoardVisual { clasico, verde, madera, azul, contraste }

/// Notificador reactivo global para el tema activo del tablero, configurable desde SettingsScreen.
final ValueNotifier<BoardVisual> activeBoardTheme = ValueNotifier<BoardVisual>(BoardVisual.clasico);

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
  final double squareCornerRadius;

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
    this.squareCornerRadius = 0,
  });
}

final Map<BoardVisual, BoardThemeConfig> boardThemes = {
  BoardVisual.clasico: const BoardThemeConfig(
    label: 'Clásico',
    description: 'El de siempre: dos colores lisos, sin marco ni sombras.',
    lightSquare: Color(0xFFF5F5F5),
    darkSquare: Color(0xFFE0E0E0),
  ),
  BoardVisual.verde: const BoardThemeConfig(
    label: 'Verde Torneo',
    description: 'El verde/crema clásico de torneo, esquinas redondeadas.',
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
    squareCornerRadius: 4,
  ),
  BoardVisual.madera: BoardThemeConfig(
    label: 'Madera',
    description: 'Degradé cálido de madera, coordenadas a-h/1-8 y marco con relieve.',
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
  BoardVisual.azul: BoardThemeConfig(
    label: 'Azul Moderno',
    description: 'Paleta fría azul/gris, casillas redondeadas, look plano minimalista.',
    lightSquare: const Color(0xFFE8EDF2),
    darkSquare: const Color(0xFF5C7A99),
    lightSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFF0F4F8), const Color(0xFFDCE4EC)],
    ),
    darkSquareGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF6B8CAD), const Color(0xFF4A6483)],
    ),
    lastMoveHighlight: const Color(0x66FFC107),
    squareCornerRadius: 8,
  ),
  BoardVisual.contraste: const BoardThemeConfig(
    label: 'Alto Contraste',
    description: 'Negro/blanco puro — pensado para máxima visibilidad.',
    lightSquare: Color(0xFFFAFAFA),
    darkSquare: Color(0xFF1A1A1A),
    lastMoveHighlight: Color(0x99FFD600),
    showCoordinates: true,
    framed: true,
    frameColor: Color(0xFF000000),
  ),
};
