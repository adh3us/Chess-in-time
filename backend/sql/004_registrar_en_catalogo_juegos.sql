-- ============================================================================
-- CHESS IN TIME — Fase 6: alta en el catálogo de juegos de Gameros
-- ============================================================================
-- Correr en el SQL Editor de Supabase. Esto SÍ toca una tabla de Gameros
-- (`public.juegos`), no de `chess_in_time` -- es el catálogo compartido del
-- que ya leen matchmaking.dart, clanes.dart y torneos.dart para ofrecer un
-- juego en sus selectores. Sin esta fila, Chess in Time no puede aparecer
-- ahí (no es algo que se pueda arreglar desde el código de la app).
--
-- Columnas inferidas de cómo las usa el propio código de Gameros
-- (matchmaking.dart, torneos.dart, clanes.dart) -- no hay migraciones de
-- `public` en este repo para confirmarlas contra la definición real, así
-- que si esto falla por un nombre de columna o tipo distinto, avisame el
-- error exacto y lo ajusto.
--
-- admite_equipo se deja en false por ahora: el ajedrez acá es 1 contra 1
-- (Chess in Time todavía no tiene un modo de equipos). Se puede activar
-- más adelante sin tocar esta fila si se agrega esa modalidad.
-- ============================================================================

insert into public.juegos (
  nombre, activo, admite_individual, admite_equipo,
  tamano_equipo_default, tamanos_equipo_permitidos, tipos_competencia,
  orden
)
select
  'Ajedrez', true, true, false,
  null, '{}', array['eliminacion_directa', 'sistema_suizo', 'todos_contra_todos', 'eliminacion_doble'],
  coalesce((select max(orden) from public.juegos), 0) + 1
where not exists (
  select 1 from public.juegos where nombre = 'Ajedrez'
);
