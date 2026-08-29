# Chess in Time — Kickoff para Claude Code

**Instrucción de autonomía:** resolvé todo lo que puedas sin pedirme nada — instalar Flutter, el SDK de Android, crear un emulador si no hay ningún dispositivo conectado, crear el repo en GitHub vía `gh` CLI, etc. Preguntame únicamente en los puntos donde de verdad haga falta una acción mía (por ejemplo, un login de GitHub que pida abrir el navegador, o si `gh` no está autenticado en esta máquina). El resto, resolvelo vos y contame al final qué hiciste.

Pegá este documento junto con la carpeta completa de este zip en Claude Code (viene con el prompt maestro y los archivos de código ya corregidos entre sí).

**Nota de procedencia — por qué existe este zip y no los anteriores:** antes de este paquete, cada fase (1, 2, 3, 8) se entregó en su propio zip por separado, en un chat sin Flutter instalado, así que los archivos de esos zips referenciaban paquetes Dart entre sí que nunca llegaron a existir de verdad (`package:chess_in_time_engine/...`). Este zip es la versión corregida y consolidada — los mismos archivos, con las referencias arregladas para vivir juntos en un solo proyecto Flutter. **Usá este zip, no los anteriores.**

## Contexto en una línea

Chess in Time es una app de ajedrez en Flutter, independiente pero con base de datos compartida con el proyecto Gameros. Hasta ahora el motor y la UI se armaron y validaron fase por fase en otro chat (sin Flutter instalado ahí), así que este es el primer compile real. El contexto completo está en `chess-in-time-prompt-maestro-pmo.md`.

## Lo que tenés que hacer, en orden

1. **Crear el repositorio.** Alojalo en la misma cuenta de GitHub que ya usa el proyecto Gameros (repo propio, nombre `chess-in-time`, no fusionado con el repo de Gameros).

2. **Crear el proyecto Flutter** dentro de ese repo:
   ```
   flutter create chess_in_time
   ```

3. **Copiar estos 5 archivos** (ya vienen con los imports corregidos para este proyecto) a las carpetas correspondientes del proyecto recién creado:
   - `lib/local_chess_engine.dart` → el motor de ajedrez (Fase 1).
   - `lib/chess_game_screen.dart` → la pantalla de juego completa: tablero, reloj y rendirse (Fase 2 + Fase 3 juntas).
   - `lib/fischer_clock.dart` → el reloj (Fase 3).
   - `lib/opening_book.dart` → base de 63 aperturas conocidas (Fase 8a — todavía sin pantalla propia, se deja cargado en el proyecto para cuando se construya la Fase 8b; no hace falta wirearlo a `main.dart` todavía).
   - `test/chess_engine_test.dart` → la suite de pruebas del motor (Fase 1, 26 casos).

   **Nota:** la Fase 2 original tenía una pantalla propia (`chess_board_screen.dart`, sin reloj) que quedó afuera de este paquete a propósito — `chess_game_screen.dart` ya incluye exactamente esa misma funcionalidad de tablero, más el reloj y el botón de rendirse encima. No hace falta la versión vieja.

   Además, `backend/aperturas_seed.sql` no va dentro del proyecto Flutter — es la semilla SQL para cuando se toque el Supabase real en la Fase 5/6. Guardalo en el repo, en una carpeta `backend/` o `sql/` al mismo nivel que el proyecto Flutter, no adentro de `lib/`.

4. **Agregar la dependencia de testing.** En el `pubspec.yaml` que generó `flutter create`, agregar bajo `dev_dependencies:`
   ```yaml
   test: ^1.25.0
   ```

5. **Editar `lib/main.dart`** para que la app arranque directo en la pantalla de juego completa:
   ```dart
   import 'package:flutter/material.dart';
   import 'chess_game_screen.dart';

   void main() => runApp(const ChessInTimeApp());

   class ChessInTimeApp extends StatelessWidget {
     const ChessInTimeApp({super.key});
     @override
     Widget build(BuildContext context) {
       return MaterialApp(
         title: 'Chess in Time',
         home: const ChessGameScreen(),
       );
     }
   }
   ```

6. **Correr la suite de tests del motor:**
   ```
   flutter test test/chess_engine_test.dart
   ```
   Tiene que dar **26 tests en verde**. Si alguno falla, es la primera vez que se detecta un problema real — reportalo tal cual aparece en la consola, no lo "arregles" adivinando sin mostrar antes qué falló.

7. **Correr la app.** Si hay un celular Android conectado por USB o un emulador ya armado, usalo. **Si no hay ninguno de los dos, armá un emulador de Android vos mismo** (instalando Android Studio/el SDK si hace falta) en vez de frenar a preguntar — es una de las cosas que podés resolver sin intervención de Lucas.
   ```
   flutter run
   ```
   Tiene que abrir directo en el selector de modalidad (Bullet/Blitz/Rápida/Clásica) de la Fase 3, y desde ahí una partida jugable con tablero, reloj y botón de rendirse.

8. **Confirmar a Lucas** con capturas o una descripción de qué pasó en los pasos 6 y 7 antes de seguir con cualquier fase nueva — este es justo el primer compile real del proyecto, la idea es confirmarlo antes de seguir sumando código encima.

## Qué NO hacer todavía

- No toques el esquema `chess_in_time` de Supabase ni nada de Gameros — eso es Fase 5/6, más adelante.
- No implementes tema visual ni Ajedrez960 — están fuera de alcance por ahora (ver el prompt maestro).
- No sigas con la Fase 4 hasta que el paso 6 y 7 de acá arriba estén confirmados funcionando.
