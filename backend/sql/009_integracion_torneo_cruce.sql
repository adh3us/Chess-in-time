-- ============================================================================
-- CHESS IN TIME — Fase 6+: Contrato de integración Torneos Gameros ↔ Chess in Time
-- ============================================================================
-- Correr en el SQL Editor de Supabase después de 001 a 008.
--
-- Objetivo:
--   1. Reemplazar llamadas a funciones viejas o colisionadas (ej. reportar_resultado_partida_externa de Tetris)
--      por el contrato oficial unificado: public.reportar_resultado_cruce_torneo(
--        p_partida_id uuid,
--        p_ganador_inscripcion_id uuid,
--        p_empate boolean,
--        p_metadata jsonb
--      ).
--   2. Automatizar el reporte desde el servidor en chess_in_time.cerrar_partida:
--      - Si el motivo es determinista ('jaque_mate', 'ahogado', 'material_insuficiente',
--        'tablas_repeticion', 'tablas_50_movimientos'), el resultado se reporta INMEDIATAMENTE
--        a public.partidas del torneo en Gameros.
--      - Si el motivo es no determinista ('resignation', 'timeout', 'tablas_acordadas'),
--        se registra en chess_in_time.reportes_resultado_torneo y se exige doble confirmación
--        (coincidencia de reportes de ambos jugadores) antes de cerrar el cruce en Gameros.
--   3. Proporcionar la función chess_in_time.confirmar_resultado_torneo para que el segundo
--      jugador pueda confirmar y destrabar el cruce si la partida local ya fue cerrada.
-- ============================================================================

-- 1. Tabla de reportes para doble confirmación en partidas de torneo
create table if not exists chess_in_time.reportes_resultado_torneo (
  id uuid primary key default gen_random_uuid(),
  partida_id uuid not null references chess_in_time.partidas(id) on delete cascade,
  torneo_partida_id uuid not null,
  reporter_usuario_id uuid not null,
  ganador_usuario_id uuid,
  empate boolean not null default false,
  motivo text not null,
  creado_en timestamptz not null default now(),
  constraint reportes_resultado_torneo_partida_reporter_uniq unique (partida_id, reporter_usuario_id)
);

alter table chess_in_time.reportes_resultado_torneo enable row level security;

-- Solo los participantes de la partida pueden ver y cargar reportes
create policy "Participantes ven reportes de su cruce"
  on chess_in_time.reportes_resultado_torneo
  for select
  to authenticated
  using (
    exists (
      select 1 from chess_in_time.partidas p
      where p.id = reportes_resultado_torneo.partida_id
        and (p.jugador_blancas = auth.uid() or p.jugador_negras = auth.uid())
    )
  );

create policy "Participantes cargan su propio reporte"
  on chess_in_time.reportes_resultado_torneo
  for insert
  to authenticated
  with check (
    reporter_usuario_id = auth.uid()
    and exists (
      select 1 from chess_in_time.partidas p
      where p.id = reportes_resultado_torneo.partida_id
        and (p.jugador_blancas = auth.uid() or p.jugador_negras = auth.uid())
    )
  );

grant select, insert on chess_in_time.reportes_resultado_torneo to chess_in_time_app, authenticated;

-- 2. Función auxiliar interna para despachar el reporte oficial a Gameros
create or replace function chess_in_time._despachar_reporte_torneo(
  p_partida chess_in_time.partidas,
  p_motivo text,
  p_ganador uuid,
  p_doble_confirmacion boolean default false
)
returns void
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_ganador_insc uuid := null;
  v_es_empate boolean := false;
  v_metadata jsonb;
begin
  if p_partida.torneo_partida_id is null then
    return;
  end if;

  if p_ganador is not null then
    if p_ganador = p_partida.jugador_blancas then
      v_ganador_insc := p_partida.torneo_insc_blancas;
    elsif p_ganador = p_partida.jugador_negras then
      v_ganador_insc := p_partida.torneo_insc_negras;
    end if;
    v_es_empate := false;
  else
    v_es_empate := true;
  end if;

  v_metadata := jsonb_build_object(
    'juego', 'chess_in_time',
    'chess_partida_id', p_partida.id,
    'motivo', p_motivo,
    'doble_confirmacion', p_doble_confirmacion
  );

  -- Llamada al contrato oficial publicado en public por el equipo core de Gameros
  perform public.reportar_resultado_cruce_torneo(
    p_partida.torneo_partida_id,
    v_ganador_insc,
    v_es_empate,
    v_metadata
  );
exception
  when undefined_function then
    -- Si Gameros aún no desplegó la función en el entorno local/staging, no rompe la partida de ajedrez
    raise notice 'Función public.reportar_resultado_cruce_torneo no encontrada todavía en la base.';
  when others then
    raise notice 'Error al reportar resultado a Gameros: %', sqlerrm;
end;
$$;

-- 3. Actualización de chess_in_time.cerrar_partida para incorporar el hook de torneos
create or replace function chess_in_time.cerrar_partida(
  p_partida_id uuid,
  p_motivo text,
  p_ganador uuid default null
)
returns void
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_partida chess_in_time.partidas%rowtype;
  v_rating_blancas int;
  v_partidas_blancas int;
  v_rating_negras int;
  v_partidas_negras int;
  v_resultado_blancas numeric;
  v_resultado_negras numeric;
  v_esperado_blancas numeric;
  v_esperado_negras numeric;
  v_k_blancas int;
  v_k_negras int;
  v_es_empate boolean;
  v_rival_reporte chess_in_time.reportes_resultado_torneo%rowtype;
begin
  select * into v_partida
  from chess_in_time.partidas
  where id = p_partida_id
  for update;

  if not found then
    raise exception 'Partida % no existe', p_partida_id;
  end if;

  if v_partida.estado = 'terminada' then
    raise exception 'La partida % ya estaba terminada', p_partida_id;
  end if;

  if auth.uid() is distinct from v_partida.jugador_blancas
     and auth.uid() is distinct from v_partida.jugador_negras then
    raise exception 'Solo un jugador de la partida puede cerrarla';
  end if;

  if p_motivo not in ('jaque_mate', 'ahogado', 'timeout', 'resignation', 'tablas_acordadas', 'tablas_repeticion', 'tablas_50_movimientos', 'material_insuficiente') then
    raise exception 'Motivo de fin inválido: %', p_motivo;
  end if;

  if p_ganador is not null and p_ganador != v_partida.jugador_blancas and p_ganador != v_partida.jugador_negras then
    raise exception 'El ganador tiene que ser uno de los dos jugadores de la partida';
  end if;

  update chess_in_time.partidas
  set estado = 'terminada', motivo_fin = p_motivo, ganador = p_ganador
  where id = p_partida_id;

  -- --------------------------------------------------------------------------
  -- Actualización de ELO interno de Chess in Time
  -- --------------------------------------------------------------------------
  insert into chess_in_time.ratings (jugador, modalidad, rating, partidas_jugadas)
  values (v_partida.jugador_blancas, v_partida.modalidad, 1200, 0)
  on conflict (jugador, modalidad) do nothing;

  insert into chess_in_time.ratings (jugador, modalidad, rating, partidas_jugadas)
  values (v_partida.jugador_negras, v_partida.modalidad, 1200, 0)
  on conflict (jugador, modalidad) do nothing;

  select rating, partidas_jugadas into v_rating_blancas, v_partidas_blancas
  from chess_in_time.ratings
  where jugador = v_partida.jugador_blancas and modalidad = v_partida.modalidad
  for update;

  select rating, partidas_jugadas into v_rating_negras, v_partidas_negras
  from chess_in_time.ratings
  where jugador = v_partida.jugador_negras and modalidad = v_partida.modalidad
  for update;

  if p_ganador = v_partida.jugador_blancas then
    v_resultado_blancas := 1;
  elsif p_ganador = v_partida.jugador_negras then
    v_resultado_blancas := 0;
  else
    v_resultado_blancas := 0.5; -- tablas
  end if;
  v_resultado_negras := 1 - v_resultado_blancas;

  v_esperado_blancas := 1.0 / (1.0 + power(10.0, (v_rating_negras - v_rating_blancas) / 400.0));
  v_esperado_negras := 1.0 - v_esperado_blancas;

  v_k_blancas := case when v_partidas_blancas < 30 then 40 else 20 end;
  v_k_negras := case when v_partidas_negras < 30 then 40 else 20 end;

  update chess_in_time.ratings
  set rating = round(v_rating_blancas + v_k_blancas * (v_resultado_blancas - v_esperado_blancas)),
      partidas_jugadas = v_partidas_blancas + 1,
      actualizada_en = now()
  where jugador = v_partida.jugador_blancas and modalidad = v_partida.modalidad;

  update chess_in_time.ratings
  set rating = round(v_rating_negras + v_k_negras * (v_resultado_negras - v_esperado_negras)),
      partidas_jugadas = v_partidas_negras + 1,
      actualizada_en = now()
  where jugador = v_partida.jugador_negras and modalidad = v_partida.modalidad;

  -- --------------------------------------------------------------------------
  -- Hook oficial para cruces de torneo Gameros (si aplica)
  -- --------------------------------------------------------------------------
  if v_partida.torneo_partida_id is not null then
    v_es_empate := (p_ganador is null);

    -- Caso A: Cierre determinista (motor de ajedrez indiscutible) -> Reporte inmediato
    if p_motivo in ('jaque_mate', 'ahogado', 'material_insuficiente', 'tablas_repeticion', 'tablas_50_movimientos') then
      perform chess_in_time._despachar_reporte_torneo(v_partida, p_motivo, p_ganador, false);

    -- Caso B: Cierre no determinista (resignation, timeout, tablas_acordadas) -> Doble confirmación
    else
      insert into chess_in_time.reportes_resultado_torneo (
        partida_id, torneo_partida_id, reporter_usuario_id, ganador_usuario_id, empate, motivo
      ) values (
        p_partida_id, v_partida.torneo_partida_id, auth.uid(), p_ganador, v_es_empate, p_motivo
      ) on conflict (partida_id, reporter_usuario_id) do update
        set ganador_usuario_id = excluded.ganador_usuario_id,
            empate = excluded.empate,
            motivo = excluded.motivo;

      -- Verificar si el rival ya había enviado un reporte coincidente
      select * into v_rival_reporte
      from chess_in_time.reportes_resultado_torneo
      where partida_id = p_partida_id
        and reporter_usuario_id <> auth.uid();

      if found and v_rival_reporte.empate = v_es_empate
         and v_rival_reporte.ganador_usuario_id is not distinct from p_ganador then
        -- Ambos reportes coinciden: se despacha a Gameros
        perform chess_in_time._despachar_reporte_torneo(v_partida, p_motivo, p_ganador, true);
      end if;
    end if;
  end if;
end;
$$;

-- 4. Función de doble confirmación llamada por el segundo jugador
create or replace function chess_in_time.confirmar_resultado_torneo(
  p_partida_id uuid,
  p_motivo text,
  p_ganador uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_partida chess_in_time.partidas%rowtype;
  v_es_empate boolean;
  v_rival_reporte chess_in_time.reportes_resultado_torneo%rowtype;
begin
  select * into v_partida
  from chess_in_time.partidas
  where id = p_partida_id;

  if not found or v_partida.torneo_partida_id is null then
    return false;
  end if;

  if auth.uid() is distinct from v_partida.jugador_blancas
     and auth.uid() is distinct from v_partida.jugador_negras then
    raise exception 'Solo un jugador de la partida puede confirmar el resultado';
  end if;

  v_es_empate := (p_ganador is null);

  insert into chess_in_time.reportes_resultado_torneo (
    partida_id, torneo_partida_id, reporter_usuario_id, ganador_usuario_id, empate, motivo
  ) values (
    p_partida_id, v_partida.torneo_partida_id, auth.uid(), p_ganador, v_es_empate, p_motivo
  ) on conflict (partida_id, reporter_usuario_id) do update
    set ganador_usuario_id = excluded.ganador_usuario_id,
        empate = excluded.empate,
        motivo = excluded.motivo;

  select * into v_rival_reporte
  from chess_in_time.reportes_resultado_torneo
  where partida_id = p_partida_id
    and reporter_usuario_id <> auth.uid();

  if found and v_rival_reporte.empate = v_es_empate
     and v_rival_reporte.ganador_usuario_id is not distinct from p_ganador then
    perform chess_in_time._despachar_reporte_torneo(v_partida, p_motivo, p_ganador, true);
    return true;
  end if;

  return false;
end;
$$;

grant execute on function chess_in_time.cerrar_partida(uuid, text, uuid) to chess_in_time_app, authenticated;
grant execute on function chess_in_time.confirmar_resultado_torneo(uuid, text, uuid) to chess_in_time_app, authenticated;
