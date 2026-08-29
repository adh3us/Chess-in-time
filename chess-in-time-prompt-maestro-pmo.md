# PROMPT MAESTRO DE INICIALIZACIÓN — PMO GAME DEV: CHESS IN TIME
*(v6 — Fase 8 pausada)*

**Instrucciones de uso:** pegar este documento junto con el Prompt Maestro general de Gameros — idealmente dentro de **Claude Code** (Desktop u otra superficie), ya que de acá en adelante la ejecución (crear el proyecto Flutter, correr `dart test`, `flutter run`, git) se hace ahí, no en un chat de claude.ai. Reemplaza a la v5.

**Historial de cambios de esta versión:**
- **Fase 8 (Jugadas Preparadas) pasa a pausada**, igual que la Fase 7 — la base de datos (8a) queda entregada y no se toca; la mecánica (8b) no se construye por ahora.

**Cambios de versiones anteriores (v2→v5):** nombre `Ajedrez 1806` → `Chess in Time`; botón "Rendirse" en Fase 3; Fase 4 simplificada sin arte, luego generalizada a sistema de Temas; Fase 6 ampliada a integración completa con Gameros y después a actividad general (`registrar_actividad_juego`); navegación en 5 Módulos; ELO propio confirmado; Fase 7 (Bughouse) creada y luego pausada; Fase 8 (Jugadas Preparadas) sacada del Backlog, base de datos entregada, mecánica definida; infraestructura de ejecución resuelta (repo en la cuenta de GitHub de Gameros, ejecución vía Claude Code); Fases 2 y 3 confirmadas por Lucas.

---

## 0. Contexto del Ecosistema Gameros

- Chess in Time es una **app Flutter independiente**: repositorio propio (alojado en la misma cuenta de GitHub que Gameros, agrupado como sub-proyecto de la línea de juegos), pipeline propio, ficha propia en Play Store. No vive dentro del código de Gameros.
- Comparte con Gameros el **mismo proyecto Supabase** — mismo `auth.users` (login con la cuenta de Gameros), y a través de la base: torneos, matchmaking, clanes, búsqueda, y a futuro wallet/fichas.
- Todo lo propio del motor de ajedrez (tablero, reloj, PGN, estado de partida en curso, y ahora el ELO) vive en su propio esquema de Postgres — **`chess_in_time`** (antes `ajedrez`), separado de `public`, que es de Gameros.
- **Decisiones cerradas para este proyecto:**
  - Sin cobro de inscripción ni premio en fichas en v1 — se juega por trofeos y reputación hasta que la Wallet de Gameros exista.
  - **ELO propio de ajedrez, además de la reputación integrada de Gameros** *(revierte la decisión "sin ELO propio" de la v3)*. Los dos sistemas conviven con alcance distinto — ver Fase 5.
  - El sistema de torneos, matchmaking, clanes y búsqueda **es el mismo de Gameros**, nunca una versión paralela propia de Chess in Time — la app solo le suma pantallas propias para operarlo.
  - Pendiente de confirmar más adelante: si el tema visual final sigue siendo la temática colonial 1806 (Invasiones Inglesas) o cambia junto con el nuevo nombre — no bloquea nada hoy.
- **Navegación de la app — Sistema de Módulos:**
  1. **Perfil Jugador** — perfil de Gameros; al configurar el juego "Ajedrez" trae la reputación/nivel de Gameros **y** el ELO propio de Chess in Time. *(Fases 5 y 6.)*
  2. **Equipo** — mismo módulo Clan que ya existe en Gameros, reusado tal cual. *(Fase 6.)*
  3. **Jugar** — matchmaking individual + partida vía deep link desde un torneo de Gameros. *(Fases 5 y 6.)*
  4. **Dobles** — Bughouse, dos tableros con pase de piezas. *(Fase 7, nueva, fuera del alcance de las Fases 1-6.)*
  5. **Torneos** — crear/listar/unirse, mismas tablas de Gameros. *(Fase 6.)*

---

## 1. PROJECT CHARTER & ROLES

- **Nombre del Proyecto:** Chess in Time.
- **Área:** Desarrollo de Juegos de Gameros (proyecto autónomo, con su propio plan de fases).
- **CEO de Gameros y a cargo de la ejecución de este proyecto:** Lucas. No tiene conocimientos de programación — ejecuta el proyecto a través de Claude (u otra IA). Valida cada entregable y decide sobre negocio, marca y legales.
- **Autor de la Especificación Funcional (EF) original:** Víctor (Rey Torus). Fuente de la mecánica del juego y los hitos técnicos que estructuraron el documento original — no ejecuta las conversaciones ni valida los entregables día a día.
- **Tech Lead & Ejecutor Full-Stack:** Claude. Arquitectura, código, testing y documentación técnica — con guías de validación siempre literales y paso a paso, sin dar por sentada jerga de programación.
- **Equipo core de Gameros:** dueño del esquema `public` y de todo lo que Chess in Time necesita del lado de Gameros para conectarse (ver Fase 6).
- **Filosofía de Desarrollo:** *"Primero simple y funcionando, después completo"*.
- **Marco de Trabajo:** entrega continua por Fases/Hitos. Cada fase termina con un entregable testeable por Lucas antes de pasar a la siguiente.

---

## 2. STACK TECNOLÓGICO Y ARQUITECTURA

- **Cliente / UI / Motor:** Flutter (Dart puro para el motor lógico; Flutter para UI).
- **Backend / Persistencia:** Supabase (mismo proyecto que Gameros) — PostgreSQL + Realtime + Auth.
- **Reglas de Ingeniería:**
  1. Motor lógico desacoplado: Dart puro, sin dependencias externas.
  2. Aislamiento de esquema: todo lo propio de Chess in Time vive en el esquema `chess_in_time` — nunca en `public`.
  3. Seguridad: RLS en toda tabla, permisos acotados al rol `chess_in_time_app` (nunca la `service_role key` — siempre `anon key`), escrituras críticas vía RPCs `SECURITY DEFINER`.
  4. El cierre de una partida de torneo no escribe directo sobre las tablas de Gameros — llama a `reportar_resultado_partida_externa` (contrato en Fase 6).

---

## 3. MATRIZ DE HITOS

```
[F1: Motor FIDE] → [F2: Tablero Local] → [F3: Reloj + Rendirse] → [F4: UI Básica] → [F5: Backend Propio + ELO] → [F6: Integración Completa con Gameros] → [F7: Dobles/Bughouse — PAUSADA] → [F8: Jugadas Preparadas — PAUSADA]
```

---

### ✅ FASE 1: Motor Lógico de Ajedrez FIDE (Dart Puro) — **ENTREGADA**

- Motor completo: movimientos legales, jaque, jaque mate, ahogado, triple repetición, 50 movimientos, material insuficiente, enroque, captura al paso, coronación, FEN y PGN.
- **Entregado:** `local_chess_engine.dart` + `chess_engine_test.dart` (26 casos).
- **Validación:** verificado contra `python-chess` (perft exacto en 5 posiciones estándar, +350.000 posiciones revisadas) y los 26 escenarios puntuales de los tests, uno por uno, en un oráculo paralelo en Python — ver `INFORME-VALIDACION-FASE1.md`.
- **Pendiente:** corrida real de `dart test` en un entorno con Flutter instalado, para el OK 100% formal.

---

### ✅ FASE 2: Tablero Interactivo Local ("Pass & Play") — **CONFIRMADA por Lucas tras probar el demo**

- Tablero 8x8, Tap-to-Move con casillas legales iluminadas.
- Modal de coronación. Indicador de turno. Alertas de jaque/jaque mate.
- **Entregable:** partida 1v1 local completa, pasando el mismo teléfono.
- **DoD:** imposible hacer una jugada ilegal desde la UI; respuesta táctil fluida.

---

### ✅ FASE 3: Reloj Fischer & Controles de Tiempo — **ENTREGADA y CONFIRMADA por Lucas tras probar el demo**

- `FischerClock`: tiempo base + incremento. Pausa/reanudación/cambio automático. Timeout con victoria al rival. Alerta bajo 30 segundos. Selector de modalidad (Bullet/Blitz/Rápida/Clásica).
- **Agregado en el repaso: botón "Rendirse"** — disponible en cualquier momento de la partida, pide confirmación antes de cerrar (para evitar un toque accidental), y al confirmar la partida termina con el rival como ganador, igual que un timeout.
- **DoD:** descuento exacto, incremento correcto, corte instantáneo en 00:00, **y** rendirse cierra la partida de inmediato asignando la victoria al rival, sin poder deshacerse una vez confirmado.

---

### 🔄 FASE 4 (simplificada): UI Básica del Tablero — **redefinida en el repaso**

*Reemplaza a la "Temática 1806 & HUD Colonial" original — se separa la funcionalidad del arte.*

- **Objetivo:** una interfaz simple, sin trabajo de arte, que permita probar de punta a punta que el tablero, las piezas, el reloj y el HUD básico funcionan juntos — antes de invertir tiempo en gráfica final.
- **Alcance:** piezas con símbolos estándar de ajedrez (los caracteres Unicode ♔♕♖♗♘♙ o formas geométricas simples), tablero con dos colores lisos, HUD mínimo (nombre de cada jugador, reloj, piezas capturadas en texto/símbolos simples, diferencial de material). Sin marco decorativo, sin sprites, sin animaciones especiales.
- **Entregable:** el juego completo (tablero + reloj + rendirse) jugable de punta a punta, visualmente simple pero sin ningún elemento roto o a medio hacer.
- **DoD:** una partida completa se puede jugar sin confusión visual — se entiende de quién es cada pieza, de quién es el turno, y el estado del reloj, aunque no tenga estética elaborada.
- **Trabajo futuro (fuera de esta fase, sin fecha todavía) — generalizado a un Sistema de Temas:** en vez de un único reskin fijo, se construye una capa de "Tema" intercambiable sobre esta misma UI básica (piezas, tablero, HUD, sonidos), de forma que se puedan sumar varios temas con el tiempo — el colonial 1806 es un candidato, pero no el único. Cada Tema es, en la práctica, un set de assets + configuración visual que se activa sin tocar la lógica del juego.

---

### ✅ FASE 5 (ampliada): Backend Propio (esquema `chess_in_time`), Multijugador Online & ELO

- Tabla `chess_in_time.partidas` (jugador de blancas, jugador de negras, `current_fen`, `pgn_moves`, `turn_color`, control de tiempo, `estado`, ganador, motivo de fin — incluye `resignation` para el botón de la Fase 3). RLS: cada jugador solo ve/actualiza sus propias partidas.
- Sincronización en tiempo real de jugadas y reloj vía Supabase Realtime.
- Función propia (interna al esquema, todavía sin tocar Gameros) para cerrar la partida y fijar el motivo: jaque mate, timeout, abandono, tablas.
- **Nuevo — ELO propio de ajedrez** (agregado en el repaso de módulos):
  - Tabla `chess_in_time.ratings` (jugador, modalidad, rating actual, cantidad de partidas jugadas).
  - Rating inicial: **1200**. Fórmula Elo estándar: `nuevo = viejo + K × (resultado_real − resultado_esperado)`, con `esperado = 1 / (1 + 10^((rival − propio) / 400))`.
  - `K = 40` durante las primeras 30 partidas de un jugador en esa modalidad (período provisional), `K = 20` después.
  - **Un rating separado por modalidad de tiempo** (Bullet/Blitz/Rápida/Clásica) — estándar de la industria, la habilidad no es la misma en cada una.
  - Se actualiza en **toda partida jugada en la app**, sea casual o de torneo — a diferencia de la reputación de Gameros, que solo se actualiza cuando la partida pertenece a un torneo (Fase 6). Es una asimetría intencional: la reputación de Gameros mide trayectoria en torneos, el ELO mide nivel de juego general.
- **Entregable:** partida online completa entre dos cuentas/dispositivos, sincronizada, con el ELO de los dos jugadores actualizándose al terminar.
- **DoD:** latencia controlada, reconexión fluida, registro inmutable en `chess_in_time.partidas`, y el cálculo de ELO da el mismo resultado que la fórmula estándar verificada a mano en al menos 3 casos de prueba.

---

### 🔄 FASE 6 (ampliada): Integración Completa con el Ecosistema Gameros — **redefinida en el repaso**

*Ya no es solo "recibir el resultado de una partida" — Chess in Time pasa a ser un segundo cliente completo del sistema social de Gameros.*

**Camino "desde Gameros":**
- Torneo de ajedrez creado en Gameros → botón **"Jugar en Chess in Time"** → deep link (`gameros-chessintime://partida/<id>`, sin token en la URL) → la partida se juega en la app → el resultado vuelve solo al bracket de Gameros vía `reportar_resultado_partida_externa` (doble confirmación entre los dos jugadores; si no coinciden, la `Partida` queda `en_disputa`).

**Camino "standalone" (nuevo en el repaso):**
- Login compartido: misma cuenta de Google/Supabase Auth que Gameros (requiere sumar el SHA-1 de Chess in Time al cliente OAuth de Google Cloud que ya usa Gameros).
- **Módulo Jugar — matchmaking rápido** (agregado en el repaso de módulos; se construye de forma iterativa, probando y ajustando en vez de especificarlo 100% de antemano — así lo pediste):
  - Partidas **clásicas** (posición inicial estándar — Ajedrez960 queda afuera por ahora, ver Backlog más abajo) con **2 minutos por jugador, sin incremento**.
  - Reloj tipo "stopper": cada jugador tiene su propia cuenta regresiva de 2:00; al hacer una jugada, tu reloj se detiene y arranca el del rival; si a alguien se le acaba el tiempo, pierde y gana el que le quedaba tiempo — es el mismo mecanismo de reloj de la Fase 3 (`FischerClock`), usado acá con incremento en 0. **No hace falta motor nuevo para esto** — es un preset de tiempo distinto sobre lo que ya está construido y validado, no una regla nueva.
  - El matchmaking empareja con un rival de **ELO similar** (usa el ELO de la Fase 5).
- **Clanes:** crear clan, invitar miembros, administrar — mismo sistema de Gameros, pantalla propia.
- **Búsqueda:** de jugadores y de clanes — mismo sistema de Gameros, pantalla propia.
- **Módulo Torneos** (detalle sumado en el repaso):
  - Crear, listar, unirse, ver reglas (formato, control de tiempo, premio) — mismas tablas de Gameros (`torneos`, `inscripciones`), pantalla propia.
  - **Reflejo bidireccional entre Gameros y Chess in Time:** un torneo creado desde cualquiera de las dos apps aparece en la otra automáticamente — esto no es trabajo nuevo, es una consecuencia directa de que las dos apps leen y escriben la misma tabla `torneos` de Gameros; no hace falta ninguna sincronización aparte.
  - **Arbitraje automático:** ya está cubierto por el contrato ya definido — `reportar_resultado_partida_externa` con doble confirmación *es* el juez automático de Gameros aplicado al ajedrez.
  - **Arbitraje manual:** para los casos que caen en disputa, se engancha al sistema de veedores que ya existe en Gameros (asignación de árbitro por matchmaking e invitación) — **dependencia externa a confirmar:** que ese sistema de veedores de Gameros ya sea genérico por juego (no específico de otro juego en particular), porque Chess in Time no construye uno propio.
  - **Fichas/premios:** siguen fuera de esta fase — se suman cuando la Wallet de Gameros exista (todavía no está desarrollada en el proyecto principal).
- **Actividad general (agregado — antes solo se reflejaban las partidas de torneo):**
  - **Toda partida, casual o de torneo, tiene que reflejarse en Gameros** — no solo las de torneo como decía la versión anterior de este documento.
  - Nueva función liviana del lado de Gameros: `registrar_actividad_juego(p_usuario_id, p_juego_id, p_resultado)`. A diferencia de `reportar_resultado_partida_externa` (que cierra una `Partida` de torneo que ya existe), esta no necesita ningún torneo detrás — cualquier partida de `chess_in_time.partidas` la llama al terminar, y solo suma a un contador de actividad general en el perfil de Gameros.
  - **Dependencia externa nueva:** el equipo core de Gameros tiene que construir y publicar `registrar_actividad_juego` — no existía en el contrato original.

**En los dos caminos:** es el mismo backend de Gameros por debajo — nunca una versión paralela de torneos/matchmaking/clanes propia de Chess in Time. Se mantiene la decisión de sin fichas en v1. La reputación de Gameros, el ELO propio (Fase 5) y ahora la actividad general conviven — este camino trae todo eso al módulo Perfil Jugador.

- **Permisos:** rol `chess_in_time_app` acotado — `EXECUTE` en `reportar_resultado_partida_externa`, `registrar_actividad_juego`, y las funciones de matchmaking/clanes/torneos que correspondan, `SELECT` vía RLS estándar, nada de acceso a `usuarios`/`wallet` más allá de eso.
- **Dependencias externas a coordinar:** (1) el equipo core de Gameros tiene que marcar `motor = 'app_externa'` para "Ajedrez" en la tabla `juegos`, y tener publicadas `reportar_resultado_partida_externa` y `registrar_actividad_juego`; (2) el sistema de veedores/árbitros de Gameros (matchmaking de árbitro e invitación) tiene que ya existir y funcionar de forma genérica para cualquier juego, no solo para el original — sin eso, la fase no se puede completar.
- **Nota de alcance:** por ser una fase grande, al construirla en serio probablemente convenga entregarla en sub-bloques (primero matchmaking individual, después clanes, después torneos) para mantener el DoD verificable paso a paso — se define en el momento, no cambia el alcance total acá definido.
- **Entregable:** (a) un torneo de prueba creado en Gameros que se juega y cierra de punta a punta desde Chess in Time; (b) una partida armada íntegramente desde Chess in Time (matchmaking o clan propio) sin haber abierto Gameros en ningún momento, y que igual quede registrada como actividad en Gameros; (c) el módulo Perfil Jugador mostrando reputación de Gameros, ELO de Chess in Time y actividad general juntos, en la misma pantalla.
- **DoD:** los dos flujos funcionan sin ninguna escritura directa de Chess in Time sobre tablas de `public` que no sean a través de las funciones definidas.

---

### ⏸️ FASE 7 (pausada): Módulo "Dobles" — Bughouse (dos tableros)

*Agregada en el repaso de módulos, pero Lucas decidió no construirla por ahora. Se documentan las respuestas ya dadas a la mini-EF de reglas, para retomarla sin perder lo avanzado.*

- **Objetivo:** implementar Bughouse — dos tableros en simultáneo, dos parejas (una pareja por tablero, jugando cada una un color), donde una pieza capturada en un tablero pasa a la "reserva" del compañero en el otro tablero, quien puede colocarla ("drop") en una casilla vacía en vez de mover una pieza propia.
- **Trabajo de motor nuevo, no cubierto por la Fase 1** (sigue pendiente, no se toca mientras esté pausada):
  - Un tipo de jugada nuevo: "drop" (colocar una pieza de la reserva en una casilla vacía) — con sus propias restricciones (por ejemplo, un peón no se puede colocar en la primera ni última fila).
  - Una "reserva" de piezas disponibles por jugador, que crece cuando el compañero captura en el otro tablero.
  - Sincronización en tiempo real **entre los dos tableros**, no solo dentro de cada uno.
- **Mini-EF de reglas — respuestas ya dadas:**
  - **Tiempo:** si un tablero termina antes que el otro, el tiempo se corta para los dos — la pareja completa termina junto con el primer tablero que decide la partida.
  - **Comunicación entre compañeros:** vía la integración de Discord que ya usa Gameros — no se construye un chat propio de Chess in Time para esto.
  - **Todavía sin responder:** límite de tiempo por jugada individual (si lo hay).
- **Entregable / DoD:** a definir cuando se retome — no es prioridad ahora.

---

### ⏸️ FASE 8 (pausada): Jugadas Preparadas (Base de Aperturas)

*La base de datos (8a) ya está entregada y no se pierde nada de lo hecho — Lucas decidió pausar la mecánica (8b) por ahora, junto con la Fase 7. Salió del Backlog en su momento; fuente: teoría de ajedrez pública y de dominio general, nunca contenido extraído de libros con copyright específico.*

- **Nota de propiedad intelectual, ya resuelta:** la secuencia de jugadas de una apertura conocida (por ejemplo, "Ruy López: 1.e4 e5 2.Cf3 Cc6 3.Ab5") es información fáctica sobre el juego — nadie es dueño de una secuencia de jugadas, así que se puede construir libremente. Lo que **no** se usa como fuente son los libros con copyright que Lucas compartió como referencia personal — su contenido curado (ejercicios, soluciones, comentarios) no se reproduce ni se procesa para esta base de datos.
- **Objetivo:** una base de datos de aperturas conocidas (nombre, código ECO, línea principal) que sirve de fundamento para el modo de jugadas preparadas.
- **Entregable Fase 8a (dato) — ENTREGADA, no se toca aunque la fase esté pausada:** `opening_book.dart` + semilla SQL con 63 aperturas conocidas, listas para cargar en `chess_in_time.aperturas` o embeberse en la app.
- **Fase 8b (mecánica) — definida, pero pausada, no se construye por ahora:** los dos modos quedan documentados para cuando se retome:
  1. **Preparación en partida en vivo:** el jugador elige de antemano una apertura de `opening_book.dart` para "memorizar". Mientras la partida (Módulo Jugar u otra) siga esa línea jugada por jugada, la interfaz confirma la jugada con un solo toque en vez de arrastrar la pieza — pensado para ahorrar segundos reales de reloj en el formato de 2 minutos. En cuanto la partida se desvía de la línea preparada, vuelve al Tap-to-Move normal de la Fase 2.
  2. **Modo estudio/práctica:** pantalla separada, sin reloj ni efecto en ninguna partida real, donde el jugador practica una apertura de la base contra jugadas de ejemplo.
  - **DoD 8b-i (preparación en vivo):** elegir una apertura, jugar sus primeros movimientos con confirmación de un toque, y que la app vuelva sola al Tap-to-Move normal apenas la partida real se aparta de la línea memorizada.
  - **DoD 8b-ii (estudio):** poder recorrer cualquiera de las 63 aperturas jugada por jugada, fuera de cualquier partida con reloj.

---

## 4. BACKLOG — Visión a futuro (sin fecha, no forma parte de las fases activas)

*Registrado para no perderlo, siguiendo el mismo criterio que usa el Prompt Maestro de Gameros con su propia visión a futuro (motor Unreal/Godot) — documentado, pero no arranca hasta que el resto esté funcionando.*

- **Ajedrez960 / Fischer Random en el Módulo Jugar:** posición inicial al azar entre las 960 variantes válidas conocidas. Técnicamente requiere generalizar el enroque del motor de la Fase 1 (hoy asume rey en e1/e8 y torres en a1/a8/h1/h8) para arrancar desde cualquier casilla de la primera fila — trabajo de motor nuevo, con su propia validación tipo perft antes de darlo por bueno.
- **Tutorial de jugadas (post-launch):** la base de aperturas de la Fase 8 puede servir de base para un tutorial/entrenador dentro de la app — planeado como actualización posterior al lanzamiento, no para la v1.

---

## 5. PROTOCOLO DE TRABAJO Y COMUNICACIÓN PMO

1. **Estado de Situación:** en qué Fase e Hito estamos.
2. **Entregable de Código:** completo, modular, listo para compilar/ejecutar — sin placeholders rotos.
3. **Guía de Validación para Lucas:** paso a paso corto y claro — qué tocar, qué mirar en pantalla. De acá en adelante la ejecución (crear proyecto, compilar, correr tests, git) se hace vía Claude Code, no tipeando comandos de terminal a mano — la guía indica qué pedirle a Claude Code, no comandos crudos.
4. **Solicitud de Pase de Fase:** esperar confirmación de Lucas antes de avanzar.
5. **Términos técnicos:** cualquier sigla o jerga (como "DoD") se explica en el momento en que aparece, no se asume conocida.
6. **En la Fase 6:** cualquier pieza que dependa del equipo core de Gameros se señala como dependencia externa, no se asume construida.

---

## 6. COMANDO DE INICIALIZACIÓN

Claude, confirmá que asimilaste: el nombre del proyecto es **Chess in Time**, que el repo vive en la misma cuenta de GitHub que Gameros (repo propio, no fusionado), que la ejecución de acá en adelante es vía **Claude Code** (no terminal literal), la navegación en 5 Módulos (Perfil Jugador, Equipo, Jugar, Dobles, Torneos), que hay **ELO propio de ajedrez además de** la reputación integrada y la actividad general de Gameros (Fase 6), que **toda partida** (casual o de torneo) se refleja en Gameros vía `registrar_actividad_juego`, que las **Fases 7 (Bughouse) y 8 (Jugadas Preparadas) están pausadas**, y que Lucas es quien ejecuta y valida cada fase — sin depender de Víctor para nada más allá de la EF original.

**Estado actual:** Fases 1, 2 y 3 entregadas y confirmadas. Fase 8a (base de aperturas) entregada, pero la Fase 8 completa queda pausada junto con la Fase 7 — no se avanza en ninguna de las dos por ahora. **Próximo paso real:** crear el repositorio y el proyecto Flutter de Chess in Time — hasta ahora todo lo entregado son archivos sueltos esperando ese proyecto.
