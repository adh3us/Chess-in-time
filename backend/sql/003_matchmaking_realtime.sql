-- ============================================================================
-- CHESS IN TIME — Fase 5: matchmaking online + tiempo real
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001 y 002.
--
-- Qué hace:
--   1. Tabla cola_espera: fila temporal por jugador mientras busca rival para
--      una modalidad. Nadie la toca directo (RLS sin políticas = acceso
--      denegado por default) -- solo las dos funciones de abajo, que corren
--      SECURITY DEFINER.
--   2. buscar_partida(modalidad): atómica -- si hay alguien esperando en esa
--      modalidad, arma la partida con los dos (colores al azar) y lo saca de
--      la cola; si no hay nadie, deja al que llama esperando y devuelve null.
--      El otro jugador se entera de la partida armada por Realtime (ve
--      aparecer la fila en `partidas`, filtrado por el RLS que ya existe).
--   3. cancelar_busqueda(): salir de la cola sin jugar.
--   4. Habilita Realtime sobre `partidas` (fuera de `public` no viene
--      prendido por default) -- el RLS existente sigue aplicando, cada
--      jugador solo recibe eventos de sus propias partidas.
-- ============================================================================

create table if not exists chess_in_time.cola_espera (
  jugador uuid primary key references auth.users (id),
  modalidad text not null check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')),
  creada_en timestamptz not null default now()
);

-- RLS habilitado sin políticas: nadie accede directo a esta tabla (ni para
-- leer), solo las funciones SECURITY DEFINER de abajo, que corren con los
-- permisos del dueño y no dependen de estas políticas.
alter table chess_in_time.cola_espera enable row level security;

-- ----------------------------------------------------------------------------
-- buscar_partida: intenta emparejar con quien esté esperando en la misma
-- modalidad; si no hay nadie, se anota en la cola y devuelve null.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.buscar_partida(p_modalidad text)
returns chess_in_time.partidas
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_rival uuid;
  v_blancas uuid;
  v_negras uuid;
  v_base_ms int;
  v_incremento_ms int;
  v_partida chess_in_time.partidas%rowtype;
begin
  if p_modalidad not in ('bullet', 'blitz', 'rapida', 'clasica') then
    raise exception 'Modalidad inválida: %', p_modalidad;
  end if;

  case p_modalidad
    when 'bullet' then v_base_ms := 60000; v_incremento_ms := 0;
    when 'blitz' then v_base_ms := 180000; v_incremento_ms := 2000;
    when 'rapida' then v_base_ms := 600000; v_incremento_ms := 0;
    when 'clasica' then v_base_ms := 1800000; v_incremento_ms := 0;
  end case;

  -- Por si quedó una búsqueda anterior colgada (se fue de la app sin cancelar).
  delete from chess_in_time.cola_espera where jugador = auth.uid();

  select jugador into v_rival
  from chess_in_time.cola_espera
  where modalidad = p_modalidad and jugador <> auth.uid()
  order by creada_en
  limit 1
  for update skip locked;

  if v_rival is null then
    insert into chess_in_time.cola_espera (jugador, modalidad) values (auth.uid(), p_modalidad);
    return null;
  end if;

  delete from chess_in_time.cola_espera where jugador = v_rival;

  if random() < 0.5 then
    v_blancas := auth.uid();
    v_negras := v_rival;
  else
    v_blancas := v_rival;
    v_negras := auth.uid();
  end if;

  insert into chess_in_time.partidas (
    jugador_blancas, jugador_negras, modalidad,
    tiempo_restante_blancas_ms, tiempo_restante_negras_ms, incremento_ms
  ) values (
    v_blancas, v_negras, p_modalidad,
    v_base_ms, v_base_ms, v_incremento_ms
  )
  returning * into v_partida;

  return v_partida;
end;
$$;

grant execute on function chess_in_time.buscar_partida(text) to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- cancelar_busqueda: salir de la cola sin jugar (botón "Cancelar" mientras espera).
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.cancelar_busqueda()
returns void
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
begin
  delete from chess_in_time.cola_espera where jugador = auth.uid();
end;
$$;

grant execute on function chess_in_time.cancelar_busqueda() to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- Realtime sobre partidas: el RLS ya existente (partidas_select_participantes)
-- sigue aplicando a los eventos -- cada jugador solo ve las suyas.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'chess_in_time'
      and tablename = 'partidas'
  ) then
    alter publication supabase_realtime add table chess_in_time.partidas;
  end if;
end
$$;
