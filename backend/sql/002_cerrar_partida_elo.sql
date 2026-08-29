-- ============================================================================
-- CHESS IN TIME — Fase 5: función para cerrar una partida y actualizar el ELO
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001_chess_in_time_schema.sql.
--
-- chess_in_time.cerrar_partida(p_partida_id, p_motivo, p_ganador)
--   - SECURITY DEFINER: corre con permisos elevados pero SOLO deja actuar a
--     uno de los dos jugadores de esa partida (valida auth.uid() adentro),
--     así la app nunca necesita tocar las tablas directo para cerrar algo.
--   - Marca la partida como terminada con su motivo y ganador.
--   - Actualiza el ELO de los dos jugadores con la fórmula estándar:
--       esperado = 1 / (1 + 10^((rival - propio) / 400))
--       nuevo = viejo + K * (resultado_real - esperado)
--     K = 40 mientras el jugador tenga menos de 30 partidas jugadas en esa
--     modalidad, K = 20 después. Si no existe fila de rating para un
--     jugador todavía, arranca en 1200 con 0 partidas jugadas.
-- ============================================================================

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
  v_resultado_blancas numeric; -- 1 = ganó, 0.5 = tablas, 0 = perdió
  v_resultado_negras numeric;
  v_esperado_blancas numeric;
  v_esperado_negras numeric;
  v_k_blancas int;
  v_k_negras int;
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

  -- Asegura que las dos filas de rating existan (arranca en 1200, 0 partidas).
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
    v_resultado_blancas := 0.5; -- tablas (ganador null)
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
end;
$$;

grant execute on function chess_in_time.cerrar_partida(uuid, text, uuid) to chess_in_time_app, authenticated;
