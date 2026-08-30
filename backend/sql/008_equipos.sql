-- ============================================================================
-- CHESS IN TIME — Fase 7: modo Equipos (N vs N, tableros independientes)
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001-007.
--
-- Diseño elegido por Lucas: cada jugador de un equipo juega su propia
-- partida 1v1 normal contra alguien del equipo rival (mismo motor, mismo
-- reloj, mismo OnlineGameScreen de siempre) -- se arman con cola automática
-- por tamaño de equipo (2v2/3v3/4v4) + modalidad, igual que Ranked 1v1 pero
-- de a grupos. Al terminar cada tablero, se suman los resultados de todos
-- los tableros del partido para definir qué equipo ganó.
--
-- Qué hace:
--   1. `equipos_cola`: fila temporal por jugador mientras espera compañeros
--      de equipo y rivales -- igual que `cola_espera` del Ranked 1v1, sin
--      políticas de RLS (solo accesible por las funciones de abajo).
--   2. `partidas_equipo`: un partido de equipos -- los dos planteles y el
--      puntaje agregado. RLS: solo lo ven los 2*tamaño_equipo jugadores
--      que son parte de alguno de los dos equipos.
--   3. `partidas` suma `equipo_partida_id` -- a qué partidas_equipo
--      pertenece ese tablero puntual (null si es un juego normal).
--   4. buscar_partida_equipo(modalidad, tamaño_equipo): atómica -- si ya
--      hay tamaño_equipo*2 - 1 jugadores esperando esa combinación, arma
--      los dos equipos al azar y un tablero por cada par; si no, se anota
--      en la cola y devuelve null.
--   5. registrar_resultado_tablero_equipo(partida_id): se llama después de
--      cerrar cada tablero -- recalcula el puntaje agregado desde cero (no
--      hace falta llevar un flag de "ya sumé este tablero", simplemente
--      vuelve a sumar todos los tableros ya terminados) y cierra el
--      partido de equipos cuando terminaron todos los tableros.
-- ============================================================================

alter table chess_in_time.partidas add column if not exists equipo_partida_id uuid;

create table if not exists chess_in_time.equipos_cola (
  jugador uuid primary key references auth.users (id),
  modalidad text not null check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')),
  tamano_equipo int not null check (tamano_equipo in (2, 3, 4)),
  creada_en timestamptz not null default now()
);

alter table chess_in_time.equipos_cola enable row level security;

create table if not exists chess_in_time.partidas_equipo (
  id uuid primary key default gen_random_uuid(),
  modalidad text not null check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')),
  tamano_equipo int not null,
  equipo_a uuid[] not null,
  equipo_b uuid[] not null,
  puntos_a numeric not null default 0,
  puntos_b numeric not null default 0,
  tableros_terminados int not null default 0,
  estado text not null default 'en_curso' check (estado in ('en_curso', 'terminada')),
  ganador text check (ganador in ('a', 'b', 'empate')),
  creada_en timestamptz not null default now()
);

alter table chess_in_time.partidas_equipo enable row level security;

drop policy if exists partidas_equipo_select_participantes on chess_in_time.partidas_equipo;
create policy partidas_equipo_select_participantes on chess_in_time.partidas_equipo
  for select
  using (auth.uid() = any(equipo_a) or auth.uid() = any(equipo_b));

grant select on chess_in_time.partidas_equipo to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- buscar_partida_equipo: siempre incluye a quien llama -- si ya hay
-- tamaño_equipo*2 - 1 rivales/compañeros esperando la misma combinación de
-- modalidad y tamaño, arma el partido completo de una.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.buscar_partida_equipo(p_modalidad text, p_tamano_equipo int)
returns chess_in_time.partidas_equipo
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_necesarios int;
  v_otros uuid[];
  v_todos uuid[];
  v_equipo_a uuid[];
  v_equipo_b uuid[];
  v_partida_equipo chess_in_time.partidas_equipo%rowtype;
  v_base_ms int;
  v_incremento_ms int;
  v_blancas uuid;
  v_negras uuid;
  i int;
begin
  if p_modalidad not in ('bullet', 'blitz', 'rapida', 'clasica') then
    raise exception 'Modalidad inválida: %', p_modalidad;
  end if;
  if p_tamano_equipo not in (2, 3, 4) then
    raise exception 'Tamaño de equipo inválido: %', p_tamano_equipo;
  end if;

  -- Por si quedó una búsqueda anterior colgada.
  delete from chess_in_time.equipos_cola where jugador = auth.uid();

  v_necesarios := p_tamano_equipo * 2 - 1;

  select array_agg(jugador) into v_otros
  from (
    select jugador
    from chess_in_time.equipos_cola
    where modalidad = p_modalidad and tamano_equipo = p_tamano_equipo
    order by creada_en
    limit v_necesarios
    for update skip locked
  ) t;

  if v_otros is null or array_length(v_otros, 1) < v_necesarios then
    insert into chess_in_time.equipos_cola (jugador, modalidad, tamano_equipo)
    values (auth.uid(), p_modalidad, p_tamano_equipo);
    return null;
  end if;

  delete from chess_in_time.equipos_cola where jugador = any(v_otros);

  -- Baraja antes de repartir en dos equipos -- si no, "quien llega último"
  -- (siempre quien llama, acá) quedaría siempre del mismo lado.
  select array_agg(x order by random()) into v_todos from unnest(array_append(v_otros, auth.uid())) as x;
  v_equipo_a := v_todos[1 : p_tamano_equipo];
  v_equipo_b := v_todos[p_tamano_equipo + 1 : p_tamano_equipo * 2];

  case p_modalidad
    when 'bullet' then v_base_ms := 60000; v_incremento_ms := 0;
    when 'blitz' then v_base_ms := 180000; v_incremento_ms := 2000;
    when 'rapida' then v_base_ms := 600000; v_incremento_ms := 0;
    when 'clasica' then v_base_ms := 1800000; v_incremento_ms := 0;
  end case;

  insert into chess_in_time.partidas_equipo (modalidad, tamano_equipo, equipo_a, equipo_b)
  values (p_modalidad, p_tamano_equipo, v_equipo_a, v_equipo_b)
  returning * into v_partida_equipo;

  for i in 1..p_tamano_equipo loop
    if random() < 0.5 then
      v_blancas := v_equipo_a[i];
      v_negras := v_equipo_b[i];
    else
      v_blancas := v_equipo_b[i];
      v_negras := v_equipo_a[i];
    end if;
    insert into chess_in_time.partidas (
      jugador_blancas, jugador_negras, modalidad,
      tiempo_restante_blancas_ms, tiempo_restante_negras_ms, incremento_ms,
      equipo_partida_id
    ) values (
      v_blancas, v_negras, p_modalidad,
      v_base_ms, v_base_ms, v_incremento_ms,
      v_partida_equipo.id
    );
  end loop;

  return v_partida_equipo;
end;
$$;

grant execute on function chess_in_time.buscar_partida_equipo(text, int) to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- cancelar_busqueda_equipo: salir de la cola sin jugar.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.cancelar_busqueda_equipo()
returns void
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
begin
  delete from chess_in_time.equipos_cola where jugador = auth.uid();
end;
$$;

grant execute on function chess_in_time.cancelar_busqueda_equipo() to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- registrar_resultado_tablero_equipo: se llama (desde el cliente) justo
-- después de que un tablero de equipos queda cerrado -- recalcula el
-- puntaje agregado desde cero a partir de todos los tableros de ese
-- partido que ya están terminados, y cierra el partido cuando no falta
-- ninguno. No hace nada si la partida no es de equipos, o si el partido ya
-- estaba cerrado.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.registrar_resultado_tablero_equipo(p_partida_id uuid)
returns void
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_partida chess_in_time.partidas%rowtype;
  v_pe chess_in_time.partidas_equipo%rowtype;
  v_total_tableros int;
  v_puntos_a numeric;
  v_puntos_b numeric;
begin
  select * into v_partida from chess_in_time.partidas where id = p_partida_id;
  if not found or v_partida.equipo_partida_id is null then return; end if;
  if v_partida.estado <> 'terminada' then return; end if;

  select * into v_pe from chess_in_time.partidas_equipo where id = v_partida.equipo_partida_id for update;
  if not found or v_pe.estado = 'terminada' then return; end if;

  select
    count(*) filter (where estado = 'terminada'),
    coalesce(sum(case
      when estado <> 'terminada' then 0
      when ganador is null then 0.5
      when ganador = any(v_pe.equipo_a) then 1
      else 0
    end), 0),
    coalesce(sum(case
      when estado <> 'terminada' then 0
      when ganador is null then 0.5
      when ganador = any(v_pe.equipo_b) then 1
      else 0
    end), 0)
  into v_total_tableros, v_puntos_a, v_puntos_b
  from chess_in_time.partidas
  where equipo_partida_id = v_pe.id;

  update chess_in_time.partidas_equipo
  set puntos_a = v_puntos_a,
      puntos_b = v_puntos_b,
      tableros_terminados = v_total_tableros,
      estado = case when v_total_tableros >= v_pe.tamano_equipo then 'terminada' else 'en_curso' end,
      ganador = case
        when v_total_tableros < v_pe.tamano_equipo then null
        when v_puntos_a > v_puntos_b then 'a'
        when v_puntos_b > v_puntos_a then 'b'
        else 'empate'
      end
  where id = v_pe.id;
end;
$$;

grant execute on function chess_in_time.registrar_resultado_tablero_equipo(uuid) to chess_in_time_app, authenticated;
