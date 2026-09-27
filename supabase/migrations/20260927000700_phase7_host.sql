-- Phase 7: guests, reservations, and live table seating.
-- A table can hold one seated party. Capacity is enforced in the function.

create table public.guests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  display_name text not null,
  allergies text,
  seating_preference text,
  vip boolean not null default false,
  favorite_item_id uuid references public.inventory_items (id),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint guests_name_len check (char_length(display_name) between 2 and 80)
);

create table public.floor_tables (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  label text not null,
  capacity integer not null,
  status text not null default 'available',
  constraint floor_tables_label_unique unique (venue_id, label),
  constraint floor_tables_capacity_check check (capacity between 1 and 20),
  constraint floor_tables_status_check check (status in ('available', 'reserved', 'seated', 'dirty', 'blocked'))
);

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  guest_id uuid not null references public.guests (id),
  party_size integer not null,
  reserved_at timestamptz not null,
  status text not null default 'booked',
  table_id uuid references public.floor_tables (id),
  notes text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint reservations_party_check check (party_size between 1 and 20),
  constraint reservations_status_check check (status in ('booked', 'seated', 'completed', 'cancelled', 'no_show'))
);

create unique index reservations_one_seated_per_table
  on public.reservations (table_id)
  where status = 'seated' and table_id is not null;

create or replace function public.create_guest(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_allergies text,
  p_seating text,
  p_vip boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_name text := pg_catalog.btrim(p_name);
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'guest.write');
  if v_name is null or char_length(v_name) < 2 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  insert into public.guests (
    organization_id, venue_id, display_name, allergies, seating_preference, vip, created_by
  ) values (
    p_organization_id, p_venue_id, v_name,
    nullif(pg_catalog.btrim(p_allergies), ''),
    nullif(pg_catalog.btrim(p_seating), ''),
    coalesce(p_vip, false),
    auth.uid()
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.set_guest_favorite(p_guest_id uuid, p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guest public.guests%rowtype;
begin
  select * into v_guest from public.guests where id = p_guest_id;
  if v_guest.id is null then
    raise exception 'guest_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_guest.organization_id, v_guest.venue_id, 'guest.write');
  if p_item_id is not null and not exists (
    select 1 from public.inventory_items
    where id = p_item_id and organization_id = v_guest.organization_id
  ) then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  update public.guests set favorite_item_id = p_item_id where id = p_guest_id;
end;
$$;

create or replace function public.create_floor_table(
  p_organization_id uuid,
  p_venue_id uuid,
  p_label text,
  p_capacity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_label text := pg_catalog.btrim(p_label);
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'floor.design');
  if v_label is null or char_length(v_label) < 1 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_capacity is null or p_capacity < 1 or p_capacity > 20 then
    raise exception 'invalid_party' using errcode = '22023';
  end if;
  insert into public.floor_tables (organization_id, venue_id, label, capacity)
  values (p_organization_id, p_venue_id, v_label, p_capacity)
  returning id into v_id;
  return v_id;
exception
  when unique_violation then
    raise exception 'code_taken' using errcode = '23505';
end;
$$;

create or replace function public.create_reservation(
  p_organization_id uuid,
  p_venue_id uuid,
  p_guest_id uuid,
  p_party_size integer,
  p_reserved_at timestamptz,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'reservation.write');
  if p_party_size is null or p_party_size < 1 or p_party_size > 20 then
    raise exception 'invalid_party' using errcode = '22023';
  end if;
  if p_reserved_at is null then
    raise exception 'invalid_release_date' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.guests
    where id = p_guest_id and venue_id = p_venue_id
  ) then
    raise exception 'guest_not_found' using errcode = '22023';
  end if;
  insert into public.reservations (
    organization_id, venue_id, guest_id, party_size, reserved_at, notes, created_by
  ) values (
    p_organization_id, p_venue_id, p_guest_id, p_party_size, p_reserved_at,
    nullif(pg_catalog.btrim(p_notes), ''), auth.uid()
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.seat_reservation(p_reservation_id uuid, p_table_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res public.reservations%rowtype;
  v_table public.floor_tables%rowtype;
begin
  select * into v_res from public.reservations where id = p_reservation_id for update;
  if v_res.id is null then
    raise exception 'reservation_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_res.organization_id, v_res.venue_id, 'reservation.seat');
  if v_res.status <> 'booked' then
    raise exception 'reservation_not_booked' using errcode = '22023';
  end if;
  select * into v_table from public.floor_tables where id = p_table_id and venue_id = v_res.venue_id for update;
  if v_table.id is null then
    raise exception 'table_not_found' using errcode = '22023';
  end if;
  if v_table.status not in ('available', 'reserved') then
    raise exception 'table_unavailable' using errcode = '22023';
  end if;
  if v_res.party_size > v_table.capacity then
    raise exception 'party_exceeds_capacity' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.reservations
    where table_id = p_table_id and status = 'seated'
  ) then
    raise exception 'table_occupied' using errcode = '22023';
  end if;
  update public.reservations
  set status = 'seated', table_id = p_table_id
  where id = p_reservation_id;
  update public.floor_tables set status = 'seated' where id = p_table_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (v_res.organization_id, v_res.venue_id, auth.uid(), 'reservation.seated', 'reservation', p_reservation_id);
end;
$$;

create or replace function public.complete_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_res public.reservations%rowtype;
begin
  select * into v_res from public.reservations where id = p_reservation_id for update;
  if v_res.id is null or v_res.status <> 'seated' then
    raise exception 'reservation_not_seated' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_res.organization_id, v_res.venue_id, 'reservation.seat');
  update public.reservations set status = 'completed' where id = p_reservation_id;
  if v_res.table_id is not null then
    update public.floor_tables set status = 'dirty' where id = v_res.table_id;
  end if;
end;
$$;

create or replace function public.clear_table(p_table_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table public.floor_tables%rowtype;
begin
  select * into v_table from public.floor_tables where id = p_table_id for update;
  if v_table.id is null then
    raise exception 'table_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_table.organization_id, v_table.venue_id, 'reservation.seat');
  if v_table.status <> 'dirty' then
    raise exception 'table_unavailable' using errcode = '22023';
  end if;
  update public.floor_tables set status = 'available' where id = p_table_id;
end;
$$;

create or replace function public.host_board(p_venue_id uuid)
returns table (
  reservation_id uuid,
  guest_name text,
  allergies text,
  seating_preference text,
  vip boolean,
  favorite_wine text,
  party_size integer,
  reserved_at timestamptz,
  reservation_status text,
  table_id uuid,
  table_label text,
  table_capacity integer,
  table_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  if v_org is null then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_org, p_venue_id, 'reservation.read')
     and not public.has_scoped_permission(v_org, p_venue_id, 'floor.read') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  select
    r.id,
    g.display_name,
    g.allergies,
    g.seating_preference,
    g.vip,
    nullif(pg_catalog.btrim(coalesce(w.producer, '') || ' ' || coalesce(w.cuvee, '')), ''),
    r.party_size,
    r.reserved_at,
    r.status,
    t.id,
    t.label,
    t.capacity,
    t.status
  from public.reservations r
  join public.guests g on g.id = r.guest_id
  left join public.floor_tables t on t.id = r.table_id
  left join public.wine_profiles w on w.item_id = g.favorite_item_id
  where r.venue_id = p_venue_id
    and r.status in ('booked', 'seated')
  order by r.reserved_at;
end;
$$;

alter table public.guests enable row level security;
alter table public.floor_tables enable row level security;
alter table public.reservations enable row level security;

create policy guests_select on public.guests
for select to authenticated
using (public.has_permission(organization_id, 'guest.read'));

create policy floor_tables_select on public.floor_tables
for select to authenticated
using (public.has_permission(organization_id, 'floor.read'));

create policy reservations_select on public.reservations
for select to authenticated
using (public.has_permission(organization_id, 'reservation.read'));

revoke all on table public.guests from public, anon, authenticated;
revoke all on table public.floor_tables from public, anon, authenticated;
revoke all on table public.reservations from public, anon, authenticated;
grant select (id, organization_id, venue_id, display_name, allergies, seating_preference, vip, favorite_item_id)
  on public.guests to authenticated;
grant select (id, organization_id, venue_id, label, capacity, status) on public.floor_tables to authenticated;
grant select (id, organization_id, venue_id, guest_id, party_size, reserved_at, status, table_id)
  on public.reservations to authenticated;

revoke all on function public.create_guest(uuid, uuid, text, text, text, boolean) from public, anon;
revoke all on function public.set_guest_favorite(uuid, uuid) from public, anon;
revoke all on function public.create_floor_table(uuid, uuid, text, integer) from public, anon;
revoke all on function public.create_reservation(uuid, uuid, uuid, integer, timestamptz, text) from public, anon;
revoke all on function public.seat_reservation(uuid, uuid) from public, anon;
revoke all on function public.complete_reservation(uuid) from public, anon;
revoke all on function public.clear_table(uuid) from public, anon;
revoke all on function public.host_board(uuid) from public, anon;
grant execute on function public.create_guest(uuid, uuid, text, text, text, boolean) to authenticated;
grant execute on function public.set_guest_favorite(uuid, uuid) to authenticated;
grant execute on function public.create_floor_table(uuid, uuid, text, integer) to authenticated;
grant execute on function public.create_reservation(uuid, uuid, uuid, integer, timestamptz, text) to authenticated;
grant execute on function public.seat_reservation(uuid, uuid) to authenticated;
grant execute on function public.complete_reservation(uuid) to authenticated;
grant execute on function public.clear_table(uuid) to authenticated;
grant execute on function public.host_board(uuid) to authenticated;
