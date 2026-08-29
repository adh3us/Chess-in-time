-- ============================================================================
-- CHESS IN TIME — Fase 5: esquema propio, separado de `public` (Gameros)
-- ============================================================================
-- Correr esto una sola vez en el SQL Editor de Supabase (Dashboard del
-- proyecto gAmeros App → SQL Editor → pegar todo → Run).
--
-- Qué hace:
--   1. Crea el esquema `chess_in_time` (nunca se toca `public`).
--   2. Tabla `partidas`: estado de cada partida en curso o terminada.
--   3. Tabla `ratings`: ELO propio de Chess in Time, separado por modalidad
--      de tiempo (bullet/blitz/rapida/clasica), inicial 1200.
--   4. Rol `chess_in_time_app`, acotado — sin acceso a nada de Gameros.
--   5. RLS en las dos tablas: cada jugador solo ve/actualiza sus propias
--      partidas y su propio rating.
--
-- Reusa `auth.users` de Supabase (login compartido con Gameros) — no crea
-- ninguna tabla de usuarios propia.
-- ============================================================================

create schema if not exists chess_in_time;

-- ----------------------------------------------------------------------------
-- Tabla: partidas
-- ----------------------------------------------------------------------------
create table if not exists chess_in_time.partidas (
  id uuid primary key default gen_random_uuid(),
  jugador_blancas uuid not null references auth.users (id),
  jugador_negras uuid not null references auth.users (id),
  modalidad text not null check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')),
  current_fen text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  pgn_moves text not null default '',
  turn_color text not null default 'white' check (turn_color in ('white', 'black')),
  tiempo_restante_blancas_ms integer not null,
  tiempo_restante_negras_ms integer not null,
  incremento_ms integer not null default 0,
  estado text not null default 'en_curso' check (estado in ('en_curso', 'terminada')),
  ganador uuid references auth.users (id),
  motivo_fin text check (motivo_fin in ('jaque_mate', 'ahogado', 'timeout', 'resignation', 'tablas_acordadas', 'tablas_repeticion', 'tablas_50_movimientos', 'material_insuficiente')),
  creada_en timestamptz not null default now(),
  actualizada_en timestamptz not null default now()
);

create index if not exists partidas_jugador_blancas_idx on chess_in_time.partidas (jugador_blancas);
create index if not exists partidas_jugador_negras_idx on chess_in_time.partidas (jugador_negras);
create index if not exists partidas_estado_idx on chess_in_time.partidas (estado);

-- ----------------------------------------------------------------------------
-- Tabla: ratings (ELO propio, separado por modalidad de tiempo)
-- ----------------------------------------------------------------------------
create table if not exists chess_in_time.ratings (
  jugador uuid not null references auth.users (id),
  modalidad text not null check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')),
  rating integer not null default 1200,
  partidas_jugadas integer not null default 0,
  actualizada_en timestamptz not null default now(),
  primary key (jugador, modalidad)
);

-- ----------------------------------------------------------------------------
-- Trigger: mantener actualizada_en al día en partidas
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.set_actualizada_en()
returns trigger
language plpgsql
as $$
begin
  new.actualizada_en = now();
  return new;
end;
$$;

drop trigger if exists partidas_set_actualizada_en on chess_in_time.partidas;
create trigger partidas_set_actualizada_en
  before update on chess_in_time.partidas
  for each row execute function chess_in_time.set_actualizada_en();

-- ----------------------------------------------------------------------------
-- Rol acotado para la app (nunca service_role, siempre a través de la anon
-- key + RLS). Sin acceso a nada de `public`/Gameros.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'chess_in_time_app') then
    create role chess_in_time_app nologin;
  end if;
end
$$;

grant usage on schema chess_in_time to chess_in_time_app, authenticated;
grant select, insert, update on chess_in_time.partidas to chess_in_time_app, authenticated;
grant select on chess_in_time.ratings to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- RLS: cada jugador solo ve/actualiza sus propias partidas y su propio rating
-- ----------------------------------------------------------------------------
alter table chess_in_time.partidas enable row level security;
alter table chess_in_time.ratings enable row level security;

drop policy if exists partidas_select_participantes on chess_in_time.partidas;
create policy partidas_select_participantes on chess_in_time.partidas
  for select
  using (auth.uid() = jugador_blancas or auth.uid() = jugador_negras);

drop policy if exists partidas_insert_participante on chess_in_time.partidas;
create policy partidas_insert_participante on chess_in_time.partidas
  for insert
  with check (auth.uid() = jugador_blancas or auth.uid() = jugador_negras);

drop policy if exists partidas_update_participantes on chess_in_time.partidas;
create policy partidas_update_participantes on chess_in_time.partidas
  for update
  using (auth.uid() = jugador_blancas or auth.uid() = jugador_negras);

drop policy if exists ratings_select_propio on chess_in_time.ratings;
create policy ratings_select_propio on chess_in_time.ratings
  for select
  using (auth.uid() = jugador);

-- ============================================================================
-- Fin de la migración inicial. Todavía faltan (próximos pasos, no en este
-- script): la función SECURITY DEFINER para cerrar partidas y actualizar el
-- ELO de forma atómica, y la sincronización en tiempo real vía Realtime.
-- ============================================================================
