-- ============================================================================
-- CHESS IN TIME — Fase 6: partidas de torneo (integración con Gameros)
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001-005.
--
-- Contexto: hasta ahora, "Jugar online" solo arma partidas por matchmaking
-- libre (dos desconocidos en cola). Esto agrega un segundo camino: una
-- partida puntual entre los dos jugadores exactos de un cruce de torneo de
-- Gameros, disparada por un deep link desde la app de Gameros.
--
-- Qué hace:
--   1. `partidas` suma 2 columnas nuevas, todas nullables (no rompe nada de
--      lo que ya existe): torneo_partida_id (a qué cruce de
--      public.partidas de Gameros pertenece) e insc_blancas/insc_negras
--      (la inscripción de Gameros de cada lado, necesaria para poder
--      reportar el resultado de vuelta con el id correcto).
--   2. iniciar_partida_torneo(...): arma (o, si el rival ya la armó,
--      simplemente devuelve) la partida para ese cruce puntual -- a
--      diferencia de buscar_partida(), acá los dos jugadores ya están
--      decididos de antemano, no hay cola ni azar de quién juega con quién.
--
-- Nota: la modalidad de tiempo para partidas de torneo queda fija en
-- Rápida (10+0) por ahora -- Gameros todavía no tiene forma de elegir modalidad
-- al crear un torneo. Si más adelante se agrega esa opción del lado de
-- Gameros, esto se puede parametrizar sin tocar la lógica de abajo.
-- ============================================================================

alter table chess_in_time.partidas add column if not exists torneo_partida_id uuid;
alter table chess_in_time.partidas add column if not exists torneo_insc_blancas uuid;
alter table chess_in_time.partidas add column if not exists torneo_insc_negras uuid;
alter table chess_in_time.partidas add column if not exists torneo_tipo_llave text;

-- Un cruce de torneo solo puede tener una partida de chess_in_time -- si
-- los dos jugadores tocan "Jugar" casi al mismo tiempo, el segundo tiene
-- que enganchar a la misma fila, nunca crear una segunda.
create unique index if not exists partidas_torneo_partida_id_uidx
  on chess_in_time.partidas (torneo_partida_id)
  where torneo_partida_id is not null;

-- ----------------------------------------------------------------------------
-- iniciar_partida_torneo: arma la partida para un cruce puntual de torneo,
-- o devuelve la que ya armó el rival si llegó primero. Nunca toca la cola
-- de matchmaking libre (cola_espera) -- son caminos independientes.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.iniciar_partida_torneo(
  p_torneo_partida_id uuid,
  p_rival_usuario_id uuid,
  p_insc_propia uuid,
  p_insc_rival uuid,
  p_tipo_llave text
)
returns chess_in_time.partidas
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_partida chess_in_time.partidas%rowtype;
  v_blancas uuid;
  v_negras uuid;
  v_insc_blancas uuid;
  v_insc_negras uuid;
  v_base_ms int := 600000; -- Rápida 10+0, ver nota arriba.
  v_incremento_ms int := 0;
begin
  if p_rival_usuario_id = auth.uid() then
    raise exception 'No podés jugar un cruce de torneo contra vos mismo';
  end if;

  -- Ya armada por el rival (llegó primero) -- se devuelve tal cual, sin
  -- volver a sortear colores ni pisar nada.
  select * into v_partida
  from chess_in_time.partidas
  where torneo_partida_id = p_torneo_partida_id;
  if found then
    return v_partida;
  end if;

  -- Sanity check contra el cruce real de Gameros: evita armar una partida
  -- para un torneo_partida_id inventado o que no sea justo entre estos dos
  -- usuarios -- el reporte automático del resultado, más adelante, hace su
  -- propia verificación independiente de esto igual.
  if not exists (
    select 1
    from public.partidas p
    join public.inscripciones_torneo ia on ia.id = p.inscripcion_a_id
    join public.inscripciones_torneo ib on ib.id = p.inscripcion_b_id
    where p.id = p_torneo_partida_id
      and p.estado = 'pendiente'
      and ((ia.usuario_id = auth.uid() and ib.usuario_id = p_rival_usuario_id)
        or (ib.usuario_id = auth.uid() and ia.usuario_id = p_rival_usuario_id))
  ) then
    raise exception 'Este cruce de torneo no existe, ya tiene resultado, o no es entre estos dos jugadores';
  end if;

  if random() < 0.5 then
    v_blancas := auth.uid();
    v_negras := p_rival_usuario_id;
    v_insc_blancas := p_insc_propia;
    v_insc_negras := p_insc_rival;
  else
    v_blancas := p_rival_usuario_id;
    v_negras := auth.uid();
    v_insc_blancas := p_insc_rival;
    v_insc_negras := p_insc_propia;
  end if;

  insert into chess_in_time.partidas (
    jugador_blancas, jugador_negras, modalidad,
    tiempo_restante_blancas_ms, tiempo_restante_negras_ms, incremento_ms,
    torneo_partida_id, torneo_insc_blancas, torneo_insc_negras, torneo_tipo_llave
  ) values (
    v_blancas, v_negras, 'rapida',
    v_base_ms, v_base_ms, v_incremento_ms,
    p_torneo_partida_id, v_insc_blancas, v_insc_negras, p_tipo_llave
  )
  on conflict (torneo_partida_id) where torneo_partida_id is not null
  do nothing
  returning * into v_partida;

  -- Carrera: el rival la insertó justo entre el select de arriba y este
  -- insert -- la fila ya existe, así que la traemos en vez de fallar.
  if not found then
    select * into v_partida from chess_in_time.partidas where torneo_partida_id = p_torneo_partida_id;
  end if;

  return v_partida;
end;
$$;

grant execute on function chess_in_time.iniciar_partida_torneo(uuid, uuid, uuid, uuid, text) to chess_in_time_app, authenticated;
