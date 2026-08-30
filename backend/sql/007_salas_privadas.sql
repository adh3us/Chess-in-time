-- ============================================================================
-- CHESS IN TIME — Fase 7: partidas privadas (invitar a un amigo)
-- ============================================================================
-- Correr en el SQL Editor de Supabase, después de 001-006.
--
-- Pedido de Lucas: además del matchmaking automático (Ranked 1v1) y de las
-- partidas de torneo, un jugador tiene que poder invitar puntualmente a
-- otro (desde adentro del juego, o compartiendo un link/código afuera),
-- juntarse los dos en una sala, acordar el reloj (o jugar "sin reloj") y
-- recién ahí arrancar la partida.
--
-- Qué hace:
--   1. Tabla `salas_privadas`: una fila por sala, con un código corto para
--      compartir. RLS: solo el anfitrión y el invitado (una vez que se
--      une) pueden verla -- nadie más, ni siquiera por su id.
--   2. `partidas` suma la columna `sin_reloj` -- cuando es true, la partida
--      no tiene FischerClock del lado de la app (nadie pierde por tiempo,
--      solo termina por jaque mate/ahogado/tablas/rendición).
--   3. Tres funciones SECURITY DEFINER: crear_sala_privada (genera el
--      código), unirse_sala_privada (por código -- tiene que poder
--      encontrar la sala aunque el que se une todavía no sea "parte" de
--      ella según la RLS de arriba, por eso es SECURITY DEFINER y no un
--      simple select), e iniciar_partida_privada (arma la partida de
--      ajedrez una vez que los dos están en la sala).
-- ============================================================================

alter table chess_in_time.partidas add column if not exists sin_reloj boolean not null default false;

create table if not exists chess_in_time.salas_privadas (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  anfitrion uuid not null references auth.users (id),
  invitado uuid references auth.users (id),
  modalidad text check (modalidad in ('bullet', 'blitz', 'rapida', 'clasica')), -- null = sin reloj
  estado text not null default 'esperando' check (estado in ('esperando', 'lista', 'iniciada', 'cancelada')),
  partida_id uuid references chess_in_time.partidas (id),
  creada_en timestamptz not null default now()
);

alter table chess_in_time.salas_privadas enable row level security;

-- Nadie lee/escribe esta tabla directo -- ni siquiera el anfitrión antes de
-- que exista fila con su propio id como participante tendría cómo probarlo
-- sin pasar por las funciones de abajo. Todo el acceso real pasa por las 3
-- funciones SECURITY DEFINER; esta política solo cubre el polling normal
-- (obtenerSalaPrivada) una vez que ya sos parte de la sala.
drop policy if exists salas_privadas_select_participantes on chess_in_time.salas_privadas;
create policy salas_privadas_select_participantes on chess_in_time.salas_privadas
  for select
  using (auth.uid() = anfitrion or auth.uid() = invitado);

grant select on chess_in_time.salas_privadas to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- crear_sala_privada: arma una sala nueva con un código de 6 caracteres
-- (letras mayúsculas y números, sin 0/O/1/I para no confundir al leerlo en
-- voz alta), y la deja esperando a que alguien se una.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.crear_sala_privada(
  p_modalidad text default null -- null = sin reloj
)
returns chess_in_time.salas_privadas
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_alfabeto text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_codigo text;
  v_sala chess_in_time.salas_privadas%rowtype;
  v_intento int := 0;
begin
  if p_modalidad is not null and p_modalidad not in ('bullet', 'blitz', 'rapida', 'clasica') then
    raise exception 'Modalidad inválida: %', p_modalidad;
  end if;

  loop
    v_intento := v_intento + 1;
    v_codigo := '';
    for i in 1..6 loop
      v_codigo := v_codigo || substr(v_alfabeto, 1 + floor(random() * length(v_alfabeto))::int, 1);
    end loop;
    begin
      insert into chess_in_time.salas_privadas (codigo, anfitrion, modalidad)
      values (v_codigo, auth.uid(), p_modalidad)
      returning * into v_sala;
      return v_sala;
    exception when unique_violation then
      if v_intento >= 10 then
        raise exception 'No se pudo generar un código único, probá de nuevo';
      end if;
      -- código repetido (muy poco probable) -- reintenta con uno nuevo.
    end;
  end loop;
end;
$$;

grant execute on function chess_in_time.crear_sala_privada(text) to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- unirse_sala_privada: por código. Si la sala ya tiene invitado (y no sos
-- vos), falla -- solo hay lugar para dos.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.unirse_sala_privada(p_codigo text)
returns chess_in_time.salas_privadas
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_sala chess_in_time.salas_privadas%rowtype;
begin
  select * into v_sala
  from chess_in_time.salas_privadas
  where codigo = upper(trim(p_codigo))
  for update;

  if not found then
    raise exception 'No existe ninguna sala con ese código';
  end if;
  if v_sala.estado not in ('esperando', 'lista') then
    raise exception 'Esa sala ya no está disponible';
  end if;
  if v_sala.anfitrion = auth.uid() then
    raise exception 'No podés unirte a tu propia sala';
  end if;

  if v_sala.invitado is null then
    update chess_in_time.salas_privadas
    set invitado = auth.uid(), estado = 'lista'
    where id = v_sala.id
    returning * into v_sala;
  elsif v_sala.invitado <> auth.uid() then
    raise exception 'Esa sala ya tiene un invitado';
  end if;

  return v_sala;
end;
$$;

grant execute on function chess_in_time.unirse_sala_privada(text) to chess_in_time_app, authenticated;

-- ----------------------------------------------------------------------------
-- iniciar_partida_privada: cualquiera de los dos la puede disparar, una vez
-- que la sala está "lista" (los dos presentes). Si el rival ya la arrancó
-- primero, devuelve la misma partida en vez de crear una segunda.
-- ----------------------------------------------------------------------------
create or replace function chess_in_time.iniciar_partida_privada(p_sala_id uuid)
returns chess_in_time.partidas
language plpgsql
security definer
set search_path = chess_in_time, public
as $$
declare
  v_sala chess_in_time.salas_privadas%rowtype;
  v_partida chess_in_time.partidas%rowtype;
  v_blancas uuid;
  v_negras uuid;
  v_base_ms int;
  v_incremento_ms int;
begin
  select * into v_sala from chess_in_time.salas_privadas where id = p_sala_id for update;
  if not found then raise exception 'Sala no encontrada'; end if;
  if auth.uid() <> v_sala.anfitrion and auth.uid() <> v_sala.invitado then
    raise exception 'No sos parte de esta sala';
  end if;

  if v_sala.partida_id is not null then
    select * into v_partida from chess_in_time.partidas where id = v_sala.partida_id;
    return v_partida;
  end if;

  if v_sala.estado <> 'lista' or v_sala.invitado is null then
    raise exception 'Todavía falta que se una el invitado';
  end if;

  case v_sala.modalidad
    when 'bullet' then v_base_ms := 60000; v_incremento_ms := 0;
    when 'blitz' then v_base_ms := 180000; v_incremento_ms := 2000;
    when 'rapida' then v_base_ms := 600000; v_incremento_ms := 0;
    when 'clasica' then v_base_ms := 1800000; v_incremento_ms := 0;
    else v_base_ms := 0; v_incremento_ms := 0; -- sin reloj
  end case;

  if random() < 0.5 then
    v_blancas := v_sala.anfitrion;
    v_negras := v_sala.invitado;
  else
    v_blancas := v_sala.invitado;
    v_negras := v_sala.anfitrion;
  end if;

  insert into chess_in_time.partidas (
    jugador_blancas, jugador_negras, modalidad,
    tiempo_restante_blancas_ms, tiempo_restante_negras_ms, incremento_ms, sin_reloj
  ) values (
    v_blancas, v_negras, coalesce(v_sala.modalidad, 'rapida'),
    v_base_ms, v_base_ms, v_incremento_ms, v_sala.modalidad is null
  )
  returning * into v_partida;

  update chess_in_time.salas_privadas
  set estado = 'iniciada', partida_id = v_partida.id
  where id = p_sala_id;

  return v_partida;
end;
$$;

grant execute on function chess_in_time.iniciar_partida_privada(uuid) to chess_in_time_app, authenticated;
