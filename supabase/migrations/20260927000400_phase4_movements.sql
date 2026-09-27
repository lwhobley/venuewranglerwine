-- Phase 4: transfer reserve stock to a bar, event hold, or member locker.
-- Availability is checked on the source slot. The ledger row is append-only.

alter table public.storage_locations
  drop constraint storage_locations_kind_check;

alter table public.storage_locations
  add constraint storage_locations_kind_check
  check (kind in ('room', 'zone', 'staging', 'service_bar', 'event_staging', 'member_locker'));

alter table public.storage_locations
  add column holder_label text;

alter table public.storage_locations
  add constraint storage_locations_holder_len check (holder_label is null or char_length(holder_label) between 2 and 80);

alter table public.inventory_movements
  add column source_slot_id uuid references public.storage_slots (id);

alter table public.inventory_movements
  drop constraint inventory_movements_reason_check;

alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in (
    'receive', 'put_away', 'privileged_adjustment', 'count_adjustment',
    'transfer_service', 'transfer_event', 'transfer_locker'
  ));

grant select (holder_label) on public.storage_locations to authenticated;
grant select (source_slot_id) on public.inventory_movements to authenticated;

create or replace function public.create_service_location(
  p_organization_id uuid,
  p_venue_id uuid,
  p_kind text,
  p_name text,
  p_code text,
  p_holder_label text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_code text := pg_catalog.upper(pg_catalog.btrim(p_code));
  v_name text := pg_catalog.btrim(p_name);
  v_holder text := nullif(pg_catalog.btrim(p_holder_label), '');
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.catalog.write');
  if p_kind not in ('service_bar', 'event_staging', 'member_locker') then
    raise exception 'invalid_destination' using errcode = '22023';
  end if;
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if v_code !~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$' or char_length(v_code) > 24 then
    raise exception 'invalid_room_code' using errcode = '22023';
  end if;
  if p_kind = 'member_locker' and (v_holder is null or char_length(v_holder) < 2) then
    raise exception 'holder_required' using errcode = '22023';
  end if;
  if p_kind <> 'member_locker' then
    v_holder := null;
  end if;
  insert into public.storage_locations (
    organization_id, venue_id, kind, name, code, holder_label, created_by
  ) values (
    p_organization_id, p_venue_id, p_kind, v_name, v_code, v_holder, v_uid
  )
  returning id into v_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'movement.location_created', 'storage_location', v_id,
    jsonb_build_object('kind', p_kind, 'code', v_code)
  );
  return v_id;
exception
  when unique_violation then
    raise exception 'code_taken' using errcode = '23505';
end;
$$;

create or replace function public.transfer_inventory(
  p_organization_id uuid,
  p_venue_id uuid,
  p_lot_id uuid,
  p_source_slot_id uuid,
  p_destination_location_id uuid,
  p_quantity text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_qty numeric(14, 3);
  v_lot public.inventory_lots%rowtype;
  v_slot public.storage_slots%rowtype;
  v_dest public.storage_locations%rowtype;
  v_source_id uuid;
  v_source_qty numeric(14, 3);
  v_dest_id uuid;
  v_dest_qty numeric(14, 3);
  v_reason text;
  v_movement uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.movement.write');
  v_qty := public.parse_bottle_quantity(p_quantity);
  select * into v_lot
  from public.inventory_lots
  where id = p_lot_id and organization_id = p_organization_id and venue_id = p_venue_id
  for update;
  if v_lot.id is null then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  select * into v_slot
  from public.storage_slots
  where id = p_source_slot_id and organization_id = p_organization_id and venue_id = p_venue_id;
  if v_slot.id is null then
    raise exception 'slot_not_found' using errcode = '22023';
  end if;
  select * into v_dest
  from public.storage_locations
  where id = p_destination_location_id
    and organization_id = p_organization_id
    and venue_id = p_venue_id
    and deleted_at is null
    and active;
  if v_dest.id is null or v_dest.kind not in ('service_bar', 'event_staging', 'member_locker') then
    raise exception 'invalid_destination' using errcode = '22023';
  end if;
  v_reason := case v_dest.kind
    when 'service_bar' then 'transfer_service'
    when 'event_staging' then 'transfer_event'
    else 'transfer_locker'
  end;

  select id, quantity into v_source_id, v_source_qty
  from public.inventory_balances
  where lot_id = p_lot_id
    and slot_id = p_source_slot_id
    and ownership_class = 'house'
  for update;
  if v_source_id is null or v_source_qty < v_qty then
    raise exception 'insufficient_quantity' using errcode = '22023';
  end if;

  update public.inventory_balances
  set quantity = quantity - v_qty
  where id = v_source_id;

  select id, quantity into v_dest_id, v_dest_qty
  from public.inventory_balances
  where lot_id = p_lot_id
    and location_id = p_destination_location_id
    and slot_id is null
    and ownership_class = 'house'
  for update;
  if v_dest_id is null then
    v_dest_qty := 0;
    insert into public.inventory_balances (
      organization_id, venue_id, item_id, lot_id, location_id, ownership_class, quantity
    ) values (
      p_organization_id, p_venue_id, v_lot.item_id, p_lot_id, p_destination_location_id, 'house', v_qty
    );
  else
    update public.inventory_balances
    set quantity = quantity + v_qty
    where id = v_dest_id;
  end if;

  insert into public.inventory_movements (
    organization_id, venue_id, item_id, lot_id, source_slot_id, destination_location_id, quantity,
    source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
    reason, actor_id
  ) values (
    p_organization_id, p_venue_id, v_lot.item_id, p_lot_id, p_source_slot_id, p_destination_location_id, v_qty,
    v_source_qty, v_source_qty - v_qty, coalesce(v_dest_qty, 0), coalesce(v_dest_qty, 0) + v_qty,
    v_reason, v_uid
  )
  returning id into v_movement;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'wine.transferred', 'inventory_movement', v_movement,
    jsonb_build_object('quantity', v_qty, 'reason', v_reason, 'destination', v_dest.code)
  );
  return jsonb_build_object(
    'movement_id', v_movement,
    'source_before', v_source_qty,
    'source_after', v_source_qty - v_qty,
    'destination_before', coalesce(v_dest_qty, 0),
    'destination_after', coalesce(v_dest_qty, 0) + v_qty,
    'reason', v_reason
  );
end;
$$;

create or replace function public.recent_transfers(p_venue_id uuid)
returns table (
  id uuid,
  reason text,
  quantity numeric,
  source_code text,
  destination_name text,
  source_before numeric,
  source_after numeric,
  created_at timestamptz
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
  if not public.has_scoped_permission(v_org, p_venue_id, 'wine.catalog.read')
     and not public.has_scoped_permission(v_org, p_venue_id, 'wine.movement.write') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  select
    m.id,
    m.reason,
    m.quantity,
    s.location_code,
    d.name,
    m.source_quantity_before,
    m.source_quantity_after,
    m.created_at
  from public.inventory_movements m
  left join public.storage_slots s on s.id = m.source_slot_id
  left join public.storage_locations d on d.id = m.destination_location_id
  where m.venue_id = p_venue_id
    and m.reason in ('transfer_service', 'transfer_event', 'transfer_locker')
  order by m.created_at desc
  limit 20;
end;
$$;

revoke all on function public.create_service_location(uuid, uuid, text, text, text, text) from public, anon;
revoke all on function public.transfer_inventory(uuid, uuid, uuid, uuid, uuid, text) from public, anon;
revoke all on function public.recent_transfers(uuid) from public, anon;
grant execute on function public.create_service_location(uuid, uuid, text, text, text, text) to authenticated;
grant execute on function public.transfer_inventory(uuid, uuid, uuid, uuid, uuid, text) to authenticated;
grant execute on function public.recent_transfers(uuid) to authenticated;
