-- A count line is one lot. Staff must name the lot when a slot holds more than one.
-- Older pooled lines cannot be approved; they must be recounted.

alter table public.inventory_count_lines
  add column if not exists lot_attributed boolean not null default true;

update public.inventory_count_lines as line
set lot_attributed = false
where line.lot_id is not null
  and exists (
    select 1
    from public.inventory_balances other
    where other.slot_id = line.slot_id
      and other.item_id = line.item_id
      and other.lot_id <> line.lot_id
      and other.ownership_class = 'house'
      and other.quantity > 0
  )
  and line.expected_quantity > coalesce((
    select balance.quantity
    from public.inventory_balances balance
    where balance.slot_id = line.slot_id
      and balance.lot_id = line.lot_id
      and balance.ownership_class = 'house'
  ), 0);

create or replace function public.reject_unattributed_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'approved' and exists (
    select 1
    from public.inventory_count_lines
    where session_id = new.id
      and counted_quantity is not null
      and lot_attributed = false
  ) then
    raise exception 'count_needs_recount' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists inventory_count_sessions_lot_attribution on public.inventory_count_sessions;
create trigger inventory_count_sessions_lot_attribution
before update on public.inventory_count_sessions
for each row execute function public.reject_unattributed_count();

drop function if exists public.record_count_entry(uuid, text, text, text, text, text);

create function public.record_count_entry(
  p_session_id uuid,
  p_client_entry_id text,
  p_location_code text,
  p_sku text,
  p_quantity text,
  p_reason text,
  p_lot_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.inventory_count_sessions%rowtype;
  v_slot public.storage_slots%rowtype;
  v_item uuid;
  v_qty numeric(14, 3);
  v_line public.inventory_count_lines%rowtype;
  v_code text := pg_catalog.upper(pg_catalog.btrim(p_location_code));
  v_sku text := nullif(pg_catalog.upper(pg_catalog.btrim(p_sku)), '');
  v_matches integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_client_entry_id is null or char_length(p_client_entry_id) < 8 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  select * into v_session from public.inventory_count_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.execute');
  if v_session.status <> 'in_progress' then
    raise exception 'session_not_open' using errcode = '22023';
  end if;
  v_qty := public.parse_count_quantity(p_quantity);
  select * into v_slot
  from public.storage_slots
  where venue_id = v_session.venue_id and location_code = v_code;
  if v_slot.id is null then
    raise exception 'slot_not_found' using errcode = '22023';
  end if;
  if v_sku is not null then
    select id into v_item
    from public.inventory_items
    where organization_id = v_session.organization_id and sku = v_sku;
    if v_item is null then
      raise exception 'item_not_found' using errcode = '22023';
    end if;
    select count(*) into v_matches
    from public.inventory_count_lines
    where session_id = p_session_id and slot_id = v_slot.id and item_id = v_item;
    if v_matches > 1 and p_lot_id is null then
      raise exception 'lot_required' using errcode = '22023';
    end if;
  elsif v_qty <> 0 then
    raise exception 'invalid_sku' using errcode = '22023';
  end if;

  if p_lot_id is not null then
    select * into v_line
    from public.inventory_count_lines
    where session_id = p_session_id and slot_id = v_slot.id and lot_id = p_lot_id;
    if v_line.id is null then
      raise exception 'lot_required' using errcode = '22023';
    end if;
  else
    select * into v_line
    from public.inventory_count_lines
    where client_entry_id = p_client_entry_id;
    if v_line.id is null then
      select * into v_line
      from public.inventory_count_lines
      where session_id = p_session_id
        and slot_id = v_slot.id
        and coalesce(item_id, '00000000-0000-0000-0000-000000000000'::uuid)
          = coalesce(v_item, '00000000-0000-0000-0000-000000000000'::uuid);
    end if;
  end if;

  if v_line.id is not null
     and v_line.counted_by is not null
     and v_line.counted_by <> v_uid
     and v_line.counted_quantity is distinct from v_qty
     and v_line.client_entry_id is distinct from p_client_entry_id then
    update public.inventory_count_lines
    set other_counted_quantity = v_qty, other_counted_by = v_uid
    where id = v_line.id;
    return jsonb_build_object('status', 'conflict', 'line_id', v_line.id);
  end if;

  if v_line.id is null then
    insert into public.inventory_count_lines (
      session_id, organization_id, slot_id, item_id, lot_id, expected_quantity,
      counted_quantity, reason, counted_by, counted_at, client_entry_id
    ) values (
      p_session_id, v_session.organization_id, v_slot.id, v_item, p_lot_id, 0,
      v_qty, nullif(pg_catalog.btrim(p_reason), ''), v_uid, pg_catalog.now(), p_client_entry_id
    )
    returning id into v_line.id;
  else
    update public.inventory_count_lines
    set counted_quantity = v_qty,
        reason = nullif(pg_catalog.btrim(p_reason), ''),
        counted_by = v_uid,
        counted_at = pg_catalog.now(),
        client_entry_id = p_client_entry_id,
        other_counted_quantity = null,
        other_counted_by = null
    where id = v_line.id;
  end if;
  return jsonb_build_object('status', 'saved', 'line_id', v_line.id);
end;
$$;

create function public.count_lot_choices(
  p_session_id uuid,
  p_location_code text,
  p_sku text
)
returns table (
  lot_id uuid,
  label text,
  expected_quantity numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.inventory_count_sessions%rowtype;
  v_show boolean;
  v_code text := pg_catalog.upper(pg_catalog.btrim(p_location_code));
  v_sku text := pg_catalog.upper(pg_catalog.btrim(p_sku));
begin
  select * into v_session from public.inventory_count_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.execute');
  v_show := v_session.mode = 'expected'
    or public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.review')
    or public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.approve');
  return query
  select
    line.lot_id,
    ('Received ' || to_char(lot.created_at at time zone 'UTC', 'YYYY-MM-DD'))::text,
    case when v_show then line.expected_quantity else null end
  from public.inventory_count_lines line
  join public.storage_slots slot on slot.id = line.slot_id
  join public.inventory_lots lot on lot.id = line.lot_id
  join public.inventory_items item on item.id = line.item_id
  where line.session_id = p_session_id
    and slot.location_code = v_code
    and item.sku = v_sku
    and line.lot_id is not null
  order by lot.created_at, line.lot_id;
end;
$$;

revoke all on function public.record_count_entry(uuid, text, text, text, text, text, uuid) from public, anon;
revoke all on function public.count_lot_choices(uuid, text, text) from public, anon;
grant execute on function public.record_count_entry(uuid, text, text, text, text, text, uuid) to authenticated;
grant execute on function public.count_lot_choices(uuid, text, text) to authenticated;
