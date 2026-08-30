-- ============================================================================
-- CHESS IN TIME — Fase 6: arreglar el bug real del "host" trabado en el lobby
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001-004.
--
-- Bug reportado por Lucas: con dos cuentas reales, el matchmaking encuentra
-- rival, pero quien estaba esperando en la cola (el "host") se queda
-- congelado en "Buscando rival..." mientras que el segundo jugador (el que
-- llamó a buscar_partida y disparó el emparejamiento) sí entra bien a la
-- partida.
--
-- Causa real: buscar_partida() borra al host de cola_espera y crea la fila
-- en `partidas`, pero esa fila solo se la devuelve a quien la llamó (el
-- segundo jugador) -- al host nunca le llega directamente. El host sigue
-- reintentando buscar_partida() cada 2 segundos (OnlineLobbyScreen), pero
-- esa función no chequeaba si el que llama ya quedó emparejado por otro:
-- solo miraba la cola de espera (ya vacía, porque el segundo jugador lo
-- sacó de ahí), así que el host se volvía a anotar en la cola de cero, en
-- un loop infinito sin enterarse nunca de que su partida ya existe.
--
-- Fix: antes de tocar la cola, buscar_partida() ahora chequea primero si
-- quien llama ya es parte de una partida en_curso en esa modalidad -- si
-- es así, la devuelve directo, sin volver a anotarlo en la cola.
-- ============================================================================

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

  -- Si quien llama ya quedó emparejado por otro jugador mientras esperaba
  -- (el otro lo sacó de la cola y armó la partida), esa partida ya existe
  -- pero nunca le llegó directo -- se la devolvemos acá en vez de volver a
  -- anotarlo en la cola.
  select * into v_partida
  from chess_in_time.partidas
  where estado = 'en_curso'
    and modalidad = p_modalidad
    and (jugador_blancas = auth.uid() or jugador_negras = auth.uid())
  order by creada_en desc
  limit 1;

  if found then
    return v_partida;
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
