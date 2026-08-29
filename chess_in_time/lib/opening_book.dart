/// ---------------------------------------------------------------------------
/// CHESS IN TIME — FASE 8a
/// Base de aperturas conocidas — fundamento del modo "Jugadas Preparadas".
///
/// Fuente: teoría de ajedrez de dominio público (nomenclatura y códigos ECO
/// estándar, usados en miles de publicaciones y bases de datos desde hace
/// décadas). No se copió ni se procesó contenido de ningún libro con copyright
/// específico — la secuencia de jugadas de una apertura es información fáctica
/// sobre el juego, no una obra protegida.
///
/// `moves` está en notación SAN, en el orden en que se juegan.
/// ---------------------------------------------------------------------------

class OpeningLine {
  final String eco; // Código ECO (Encyclopaedia of Chess Openings), estándar de la industria
  final String name;
  final List<String> moves;
  const OpeningLine(this.eco, this.name, this.moves);
}

const List<OpeningLine> openingBook = [
  // --- A: Aperturas de flanco y sistemas no clasificados en B-E ---
  OpeningLine('A00', 'Apertura Polaca (Sokolsky)', ['b4']),
  OpeningLine('A01', 'Apertura Larsen', ['b3']),
  OpeningLine('A02', 'Apertura Bird', ['f4']),
  OpeningLine('A04', 'Apertura Réti', ['Nf3']),
  OpeningLine('A10', 'Apertura Inglesa', ['c4']),
  OpeningLine('A13', 'Inglesa: Sistema Agincourt', ['c4', 'e6', 'Nf3']),
  OpeningLine('A45', 'Apertura de Peón Dama, Ataque Trompowsky', ['d4', 'Nf6', 'Bg5']),
  OpeningLine('A56', 'Defensa Benoni', ['d4', 'Nf6', 'c4', 'c5']),
  OpeningLine('A57', 'Gambito Benko', ['d4', 'Nf6', 'c4', 'c5', 'd5', 'b5']),
  OpeningLine('A80', 'Defensa Holandesa', ['d4', 'f5']),

  // --- B: Aperturas semiabiertas (excepto Francesa) y Siciliana ---
  OpeningLine('B00', 'Defensa Nimzowitsch (1...Cc6)', ['e4', 'Nc6']),
  OpeningLine('B01', 'Defensa Escandinava', ['e4', 'd5']),
  OpeningLine('B02', 'Defensa Alekhine', ['e4', 'Nf6']),
  OpeningLine('B06', 'Defensa Moderna', ['e4', 'g6']),
  OpeningLine('B07', 'Defensa Pirc', ['e4', 'd6', 'd4', 'Nf6']),
  OpeningLine('B10', 'Defensa Caro-Kann', ['e4', 'c6']),
  OpeningLine('B12', 'Caro-Kann: Ataque Avance', ['e4', 'c6', 'd4', 'd5', 'e5']),
  OpeningLine('B20', 'Defensa Siciliana', ['e4', 'c5']),
  OpeningLine('B21', 'Siciliana: Gambito Smith-Morra', ['e4', 'c5', 'd4', 'cxd4', 'c3']),
  OpeningLine('B22', 'Siciliana: Variante Alapin', ['e4', 'c5', 'c3']),
  OpeningLine('B23', 'Siciliana Cerrada', ['e4', 'c5', 'Nc3']),
  OpeningLine('B27', 'Siciliana: Sistema Hyperaccelerated Dragon', ['e4', 'c5', 'Nf3', 'g6']),
  OpeningLine('B30', 'Siciliana: Variante Rossolimo', ['e4', 'c5', 'Nf3', 'Nc6', 'Bb5']),
  OpeningLine('B32', 'Siciliana: Variante Sveshnikov', ['e4', 'c5', 'Nf3', 'Nc6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'e5']),
  OpeningLine('B40', 'Siciliana: Variante Kan', ['e4', 'c5', 'Nf3', 'e6', 'd4', 'cxd4', 'Nxd4', 'a6']),
  OpeningLine('B50', 'Siciliana: Sistema Cerrado con d3', ['e4', 'c5', 'Nf3', 'd6', 'd3']),
  OpeningLine('B70', 'Siciliana Dragón', ['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'g6']),
  OpeningLine('B90', 'Siciliana Najdorf', ['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'a6']),

  // --- C: Aperturas abiertas y Defensa Francesa ---
  OpeningLine('C00', 'Defensa Francesa', ['e4', 'e6']),
  OpeningLine('C02', 'Francesa: Variante de Avance', ['e4', 'e6', 'd4', 'd5', 'e5']),
  OpeningLine('C10', 'Francesa: Variante Rubinstein', ['e4', 'e6', 'd4', 'd5', 'Nc3', 'dxe4']),
  OpeningLine('C15', 'Francesa: Variante Winawer', ['e4', 'e6', 'd4', 'd5', 'Nc3', 'Bb4']),
  OpeningLine('C20', 'Apertura del Peón de Rey (genérica)', ['e4', 'e5']),
  OpeningLine('C23', 'Apertura del Alfil', ['e4', 'e5', 'Bc4']),
  OpeningLine('C25', 'Apertura Vienesa', ['e4', 'e5', 'Nc3']),
  OpeningLine('C30', 'Gambito de Rey', ['e4', 'e5', 'f4']),
  OpeningLine('C41', 'Defensa Philidor', ['e4', 'e5', 'Nf3', 'd6']),
  OpeningLine('C42', 'Defensa Petrov (Rusa)', ['e4', 'e5', 'Nf3', 'Nf6']),
  OpeningLine('C44', 'Apertura Escocesa (genérica)', ['e4', 'e5', 'Nf3', 'Nc6', 'd4']),
  OpeningLine('C45', 'Escocesa: Variante Clásica', ['e4', 'e5', 'Nf3', 'Nc6', 'd4', 'exd4', 'Nxd4']),
  OpeningLine('C50', 'Apertura Italiana (Giuoco Piano)', ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5']),
  OpeningLine('C51', 'Gambito Evans', ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'b4']),
  OpeningLine('C55', 'Ataque de los Dos Caballos', ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6']),
  OpeningLine('C57', 'Ataque Fried Liver / Traxler', ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6', 'Ng5']),
  OpeningLine('C60', 'Apertura Española (Ruy López)', ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']),
  OpeningLine('C65', 'Española: Defensa Berlinesa', ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'Nf6']),
  OpeningLine('C68', 'Española: Variante de Cambio', ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Bxc6']),
  OpeningLine('C78', 'Española: Variante Arkhangelsk', ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O', 'b5', 'Bb3', 'Bb7']),
  OpeningLine('C84', 'Española: Variante Cerrada', ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O', 'Be7']),

  // --- D: Aperturas de peón dama cerradas y semicerradas ---
  OpeningLine('D00', 'Apertura de Peón Dama (genérica)', ['d4', 'd5']),
  OpeningLine('D02', 'Sistema Londres', ['d4', 'd5', 'Nf3', 'Nf6', 'Bf4']),
  OpeningLine('D06', 'Gambito de Dama (genérico)', ['d4', 'd5', 'c4']),
  OpeningLine('D07', 'Gambito de Dama: Defensa Chigorin', ['d4', 'd5', 'c4', 'Nc6']),
  OpeningLine('D20', 'Gambito de Dama Aceptado', ['d4', 'd5', 'c4', 'dxc4']),
  OpeningLine('D30', 'Gambito de Dama Rehusado (genérico)', ['d4', 'd5', 'c4', 'e6']),
  OpeningLine('D31', 'GDR: Variante Semi-Eslava (preparación)', ['d4', 'd5', 'c4', 'e6', 'Nc3', 'c6']),
  OpeningLine('D35', 'GDR: Variante de Cambio', ['d4', 'd5', 'c4', 'e6', 'Nc3', 'Nf6', 'cxd5', 'exd5']),
  OpeningLine('D43', 'Defensa Semi-Eslava', ['d4', 'd5', 'c4', 'c6', 'Nc3', 'Nf6', 'Nf3', 'e6']),
  OpeningLine('D80', 'Defensa Grünfeld', ['d4', 'Nf6', 'c4', 'g6', 'Nc3', 'd5']),

  // --- E: Defensas Indias ---
  OpeningLine('E00', 'Sistema Catalán', ['d4', 'Nf6', 'c4', 'e6', 'g3']),
  OpeningLine('E12', 'Defensa India de Dama', ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'b6']),
  OpeningLine('E20', 'Defensa Nimzoindia', ['d4', 'Nf6', 'c4', 'e6', 'Nc3', 'Bb4']),
  OpeningLine('E60', 'Defensa India de Rey (genérica)', ['d4', 'Nf6', 'c4', 'g6']),
  OpeningLine('E70', 'India de Rey: Sistema Clásico', ['d4', 'Nf6', 'c4', 'g6', 'Nc3', 'Bg7', 'e4', 'd6']),
  OpeningLine('E90', 'India de Rey: Sistema Ortodoxo', ['d4', 'Nf6', 'c4', 'g6', 'Nc3', 'Bg7', 'e4', 'd6', 'Nf3', 'O-O']),
];

/// Devuelve las aperturas cuya línea principal empieza con el prefijo de
/// jugadas dado — útil para detectar, jugada a jugada, en qué apertura(s)
/// está entrando la partida en curso.
List<OpeningLine> matchingOpenings(List<String> sanMovesSoFar) {
  return openingBook.where((o) {
    if (sanMovesSoFar.length > o.moves.length) return false;
    for (var i = 0; i < sanMovesSoFar.length; i++) {
      if (sanMovesSoFar[i] != o.moves[i]) return false;
    }
    return true;
  }).toList();
}
