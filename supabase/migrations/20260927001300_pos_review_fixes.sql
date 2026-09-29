-- POS actor checks, whole-bottle depletion, and lot/SKU count validation.
-- A failed handshake must not be able to clear a working credential.

alter table public.inventory_movements
  drop constraint inventory_movements_reason_check;

alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in (
    'receive', 'put_away', 'privileged_adjustment', 'count_adjustment',
    'transfer_service', 'transfer_event', 'transfer_locker',
    'allocation_reserve', 'allocation_pickup', 'service_open', 'pos_sale'
  ));

alter table public.inventory_movements
  alter column actor_id drop not null;

alter table public.inventory_movements
  add constraint inventory_movements_actor_check
  check (actor_id is not null or reason = 'pos_sale');

alter table public.pos_check_lines
  add column item_id uuid references public.inventory_items (id),
  add column depleted_quantity numeric(14, 3) not null default 0,
  add constraint pos_check_lines_depleted_check
    check (depleted_quantity >= 0 and depleted_quantity <= quantity);

grant select (item_id, depleted_quantity) on public.pos_check_lines to authenticated;

create or replace function public.assert_integration_manage(p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.has_permission(p_organization_id, 'integration.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.ensure_integration(
  p_organization_id uuid,
  p_provider_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.assert_integration_manage(p_organization_id);
  if p_provider_key !~ '^[a-z0-9_]{2,40}$' then
    raise exception 'invalid_provider' using errcode = '22023';
  end if;
  insert into public.integration_connections (organization_id, provider_key, status, credential_ref)
  values (p_organization_id, p_provider_key, 'disconnected', null)
  on conflict (organization_id, provider_key) do update
    set provider_key = excluded.provider_key
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.assert_pos_actor(
  p_connection_id uuid,
  p_venue_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn public.integration_connections%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select * into v_conn from public.integration_connections where id = p_connection_id;
  if v_conn.id is null
     or not public.has_permission(v_conn.organization_id, 'integration.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if p_venue_id is not null
     and not public.venue_visible(v_conn.organization_id, p_venue_id, 'integration.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return v_conn.organization_id;
end;
$$;

revoke all on function public.assert_integration_manage(uuid) from public, anon;
revoke all on function public.ensure_integration(uuid, text) from public, anon;
revoke all on function public.assert_pos_actor(uuid, uuid) from public, anon;
grant execute on function public.assert_integration_manage(uuid) to authenticated;
grant execute on function public.ensure_integration(uuid, text) to authenticated;
grant execute on function public.assert_pos_actor(uuid, uuid) to authenticated;

create or replace function public.apply_pos_check(
  p_connection_id uuid,
  p_venue_id uuid,
  p_external_id text,
  p_occurred_at timestamptz,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conn public.integration_connections%rowtype;
  v_check uuid;
  v_line jsonb;
  v_sku text;
  v_mapped text;
  v_item uuid;
  v_qty numeric(14, 3);
  v_left numeric(14, 3);
  v_take numeric(14, 3);
  v_depleted numeric(14, 3);
  v_total numeric(14, 3) := 0;
  v_balance public.inventory_balances%rowtype;
begin
  select * into v_conn from public.integration_connections where id = p_connection_id;
  if v_conn.id is null or v_conn.status <> 'connected' then
    raise exception 'handshake_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.venues
    where id = p_venue_id and organization_id = v_conn.organization_id and deleted_at is null
  ) then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  insert into public.pos_checks (connection_id, organization_id, venue_id, external_id, occurred_at)
  values (p_connection_id, v_conn.organization_id, p_venue_id, p_external_id, p_occurred_at)
  on conflict (connection_id, external_id) do nothing
  returning id into v_check;
  if v_check is null then
    return jsonb_build_object('applied', false, 'depleted', 0);
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_sku := pg_catalog.upper(pg_catalog.btrim(coalesce(v_line ->> 'sku', '')));
    v_qty := (v_line ->> 'quantity')::numeric;
    if v_sku = '' or v_qty <= 0 then
      raise exception 'invalid_quantity' using errcode = '22023';
    end if;
    select local_sku into v_mapped
    from public.integration_item_maps
    where connection_id = p_connection_id
      and pg_catalog.upper(external_sku) = v_sku;
    if v_mapped is not null then
      v_sku := pg_catalog.upper(v_mapped);
    end if;
    select id into v_item
    from public.inventory_items
    where organization_id = v_conn.organization_id and sku = v_sku;
    v_depleted := 0;
    if v_item is not null and v_qty = trunc(v_qty) then
      v_left := v_qty;
      while v_left > 0 loop
        select * into v_balance
        from public.inventory_balances
        where venue_id = p_venue_id
          and item_id = v_item
          and ownership_class = 'house'
          and slot_id is not null
          and quantity >= 1
        order by quantity desc, id
        limit 1
        for update;
        exit when not found;
        v_take := least(v_left, trunc(v_balance.quantity));
        update public.inventory_balances
        set quantity = quantity - v_take
        where id = v_balance.id;
        update public.inventory_lots
        set quantity_on_hand = quantity_on_hand - v_take
        where id = v_balance.lot_id;
        insert into public.inventory_movements (
          organization_id, venue_id, item_id, lot_id, source_slot_id, quantity,
          source_quantity_before, source_quantity_after,
          destination_quantity_before, destination_quantity_after,
          reason, actor_id
        ) values (
          v_conn.organization_id, p_venue_id, v_item, v_balance.lot_id, v_balance.slot_id, v_take,
          v_balance.quantity, v_balance.quantity - v_take, 0, 0,
          'pos_sale', null
        );
        v_left := v_left - v_take;
        v_depleted := v_depleted + v_take;
      end loop;
    end if;
    insert into public.pos_check_lines (
      check_id, organization_id, sku, name, quantity, item_id, depleted_quantity
    ) values (
      v_check,
      v_conn.organization_id,
      v_sku,
      coalesce(v_line ->> 'name', v_sku),
      v_qty,
      v_item,
      v_depleted
    );
    v_total := v_total + v_depleted;
  end loop;
  return jsonb_build_object('applied', true, 'depleted', v_total, 'check_id', v_check);
end;
$$;

create or replace function public.record_count_entry(
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
    if v_item is not null and v_line.item_id is distinct from v_item then
      raise exception 'lot_item_mismatch' using errcode = '22023';
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

drop function public.count_sheet(uuid);

create function public.count_sheet(p_session_id uuid)
returns table (
  line_id uuid,
  location_code text,
  sku text,
  label text,
  counted_quantity numeric,
  expected_quantity numeric,
  conflict boolean,
  other_counted_quantity numeric,
  reason text,
  mode text,
  status text,
  lot_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.inventory_count_sessions%rowtype;
  v_show_expected boolean;
begin
  select * into v_session from public.inventory_count_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.execute')
     and not public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.review')
     and not public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.approve') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  v_show_expected := v_session.mode = 'expected'
    or public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.review')
    or public.has_scoped_permission(v_session.organization_id, v_session.venue_id, 'wine.count.approve');
  return query
  select
    l.id,
    s.location_code,
    i.sku,
    nullif(pg_catalog.btrim(coalesce(w.producer, '') || ' ' || coalesce(w.cuvee, '')), ''),
    l.counted_quantity,
    case when v_show_expected then l.expected_quantity else null end,
    l.other_counted_quantity is not null,
    l.other_counted_quantity,
    l.reason,
    v_session.mode,
    v_session.status,
    l.lot_id
  from public.inventory_count_lines l
  join public.storage_slots s on s.id = l.slot_id
  left join public.inventory_items i on i.id = l.item_id
  left join public.wine_profiles w on w.item_id = l.item_id
  where l.session_id = p_session_id
  order by s.location_code, i.sku nulls last, l.lot_id;
end;
$$;

revoke all on function public.count_sheet(uuid) from public, anon;
grant execute on function public.count_sheet(uuid) to authenticated;
