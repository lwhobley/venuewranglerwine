-- A Square location belongs to one venue, and a sale line can be reconciled on a later pull.
create table public.integration_venue_maps (
  connection_id uuid not null references public.integration_connections (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  external_location_id text not null,
  primary key (connection_id, venue_id),
  unique (connection_id, external_location_id)
);

alter table public.integration_venue_maps enable row level security;
create policy integration_venue_maps_select on public.integration_venue_maps
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'integration.manage'));
revoke all on public.integration_venue_maps from public, anon, authenticated;
grant select (connection_id, organization_id, venue_id, external_location_id)
  on public.integration_venue_maps to authenticated;
grant all on public.integration_venue_maps to service_role;

alter table public.pos_check_lines add column line_index integer;
create unique index pos_check_lines_position on public.pos_check_lines (check_id, line_index);
alter table public.pos_checks add column legacy_applied boolean not null default false;
update public.pos_checks c set legacy_applied = true
where exists (select 1 from public.pos_check_lines l where l.check_id = c.id);

alter table public.integration_item_maps drop constraint integration_item_maps_pkey;
alter table public.integration_item_maps
  add primary key (connection_id, external_sku);

create function public.save_pos_venue_map(
  p_connection_id uuid, p_venue_id uuid, p_external_location_id text
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_org uuid;
begin
  v_org := public.assert_pos_actor(p_connection_id, p_venue_id);
  if pg_catalog.btrim(coalesce(p_external_location_id, '')) = '' then
    raise exception 'invalid_location' using errcode = '22023';
  end if;
  insert into public.integration_venue_maps
    (connection_id, organization_id, venue_id, external_location_id)
  values (p_connection_id, v_org, p_venue_id, pg_catalog.btrim(p_external_location_id))
  on conflict (connection_id, venue_id) do update
    set external_location_id = excluded.external_location_id;
end;
$$;

create function public.save_pos_item_map(
  p_connection_id uuid, p_external_sku text, p_local_sku text
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_org uuid;
  v_external text := pg_catalog.upper(pg_catalog.btrim(p_external_sku));
  v_local text := pg_catalog.upper(pg_catalog.btrim(p_local_sku));
begin
  v_org := public.assert_pos_actor(p_connection_id, null);
  if v_external = '' or v_local = '' or not exists (
    select 1 from public.inventory_items
    where organization_id = v_org and sku = v_local
  ) then
    raise exception 'invalid_item_map' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.integration_item_maps m
    join public.pos_checks c on c.connection_id = m.connection_id
    join public.pos_check_lines l on l.check_id = c.id and l.sku = m.external_sku
    where m.connection_id = p_connection_id and m.external_sku = v_external
      and m.local_sku <> v_local and l.depleted_quantity > 0
  ) then
    raise exception 'item_already_applied' using errcode = '22023';
  end if;
  insert into public.integration_item_maps
    (connection_id, organization_id, local_sku, external_sku)
  values (p_connection_id, v_org, v_local, v_external)
  on conflict (connection_id, external_sku) do update
    set local_sku = excluded.local_sku;
end;
$$;

create function public.pos_unmapped_items(p_connection_id uuid, p_venue_id uuid)
returns table (external_sku text, name text, line_count bigint)
language plpgsql security definer set search_path = '' as $$
begin
  perform public.assert_pos_actor(p_connection_id, p_venue_id);
  return query
  select l.sku, max(l.name), count(*)
  from public.pos_check_lines l
  join public.pos_checks c on c.id = l.check_id
  where c.connection_id = p_connection_id and c.venue_id = p_venue_id
    and not c.legacy_applied
    and l.item_id is null
  group by l.sku
  order by count(*) desc, l.sku;
end;
$$;

revoke all on function public.save_pos_venue_map(uuid, uuid, text) from public, anon;
revoke all on function public.save_pos_item_map(uuid, text, text) from public, anon;
revoke all on function public.pos_unmapped_items(uuid, uuid) from public, anon;
grant execute on function public.save_pos_venue_map(uuid, uuid, text) to authenticated;
grant execute on function public.save_pos_item_map(uuid, text, text) to authenticated;
grant execute on function public.pos_unmapped_items(uuid, uuid) to authenticated;

-- The service-role call is one transaction: credential and connection state commit together.
create function public.activate_pos_integration(p_connection_id uuid, p_secret jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.integration_connections where id = p_connection_id) then
    raise exception 'connection_not_found' using errcode = '22023';
  end if;
  insert into public.integration_secrets (
    connection_id, access_token, client_id, client_secret, merchant_id,
    shop_domain, restaurant_guid, webhook_url, webhook_secret, sandbox
  ) values (
    p_connection_id, p_secret ->> 'access_token', p_secret ->> 'client_id',
    p_secret ->> 'client_secret', p_secret ->> 'merchant_id',
    p_secret ->> 'shop_domain', p_secret ->> 'restaurant_guid',
    p_secret ->> 'webhook_url', p_secret ->> 'webhook_secret',
    coalesce((p_secret ->> 'sandbox')::boolean, false)
  ) on conflict (connection_id) do update set
    access_token = excluded.access_token,
    client_id = excluded.client_id,
    client_secret = excluded.client_secret,
    merchant_id = excluded.merchant_id,
    shop_domain = excluded.shop_domain,
    restaurant_guid = excluded.restaurant_guid,
    webhook_url = excluded.webhook_url,
    webhook_secret = excluded.webhook_secret,
    sandbox = excluded.sandbox,
    updated_at = now();
  update public.integration_connections
  set status = 'connected', credential_ref = p_connection_id
  where id = p_connection_id;
end;
$$;
revoke all on function public.activate_pos_integration(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.activate_pos_integration(uuid, jsonb) to service_role;

create or replace function public.apply_pos_check(
  p_connection_id uuid, p_venue_id uuid, p_external_id text,
  p_occurred_at timestamptz, p_lines jsonb
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_conn public.integration_connections%rowtype;
  v_check uuid;
  v_existing_venue uuid;
  v_legacy boolean;
  v_line jsonb;
  v_index integer := 0;
  v_external text;
  v_mapped text;
  v_item uuid;
  v_qty numeric(14, 3);
  v_left numeric(14, 3);
  v_take numeric(14, 3);
  v_depleted numeric(14, 3);
  v_total numeric(14, 3) := 0;
  v_unmapped integer := 0;
  v_position public.pos_check_lines%rowtype;
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
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'invalid_lines' using errcode = '22023';
  end if;
  insert into public.pos_checks
    (connection_id, organization_id, venue_id, external_id, occurred_at)
  values (p_connection_id, v_conn.organization_id, p_venue_id, p_external_id, p_occurred_at)
  on conflict (connection_id, external_id) do nothing returning id into v_check;
  if v_check is null then
    select id, venue_id, legacy_applied into v_check, v_existing_venue, v_legacy
    from public.pos_checks
    where connection_id = p_connection_id and external_id = p_external_id
    for update;
    if v_existing_venue is distinct from p_venue_id then
      raise exception 'pos_venue_mismatch' using errcode = '22023';
    end if;
    if v_legacy then
      return jsonb_build_object('applied', false, 'depleted', 0, 'unmapped', 0);
    end if;
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_external := pg_catalog.upper(pg_catalog.btrim(coalesce(v_line ->> 'sku', '')));
    v_qty := (v_line ->> 'quantity')::numeric;
    if v_external = '' or v_qty is null or v_qty <= 0 then
      raise exception 'invalid_quantity' using errcode = '22023';
    end if;
    select * into v_position from public.pos_check_lines
    where check_id = v_check and line_index = v_index for update;
    if v_position.id is null then
      insert into public.pos_check_lines
        (check_id, organization_id, line_index, sku, name, quantity, depleted_quantity)
      values (v_check, v_conn.organization_id, v_index, v_external,
        coalesce(v_line ->> 'name', v_external), v_qty, 0)
      returning * into v_position;
    elsif v_position.sku <> v_external or v_position.quantity <> v_qty then
      raise exception 'pos_order_changed' using errcode = '22023';
    end if;
    select local_sku into v_mapped from public.integration_item_maps
    where connection_id = p_connection_id and external_sku = v_external;
    if v_mapped is null then
      v_unmapped := v_unmapped + 1;
      v_index := v_index + 1;
      continue;
    end if;
    select id into v_item from public.inventory_items
    where organization_id = v_conn.organization_id and sku = v_mapped;
    if v_item is null then
      raise exception 'invalid_item_map' using errcode = '22023';
    end if;
    v_depleted := 0;
    if v_qty = trunc(v_qty) then
      v_left := v_qty - v_position.depleted_quantity;
      while v_left > 0 loop
        select * into v_balance from public.inventory_balances
        where venue_id = p_venue_id and item_id = v_item
          and ownership_class = 'house' and slot_id is not null and quantity >= 1
        order by quantity desc, id limit 1 for update;
        exit when not found;
        v_take := least(v_left, trunc(v_balance.quantity));
        update public.inventory_balances set quantity = quantity - v_take where id = v_balance.id;
        update public.inventory_lots
        set quantity_on_hand = quantity_on_hand - v_take where id = v_balance.lot_id;
        insert into public.inventory_movements (
          organization_id, venue_id, item_id, lot_id, source_slot_id, quantity,
          source_quantity_before, source_quantity_after,
          destination_quantity_before, destination_quantity_after, reason, actor_id
        ) values (
          v_conn.organization_id, p_venue_id, v_item, v_balance.lot_id,
          v_balance.slot_id, v_take, v_balance.quantity, v_balance.quantity - v_take,
          0, 0, 'pos_sale', null
        );
        v_left := v_left - v_take;
        v_depleted := v_depleted + v_take;
      end loop;
      if v_left > 0 then
        raise exception 'pos_stock_shortage' using errcode = '22023';
      end if;
    end if;
    update public.pos_check_lines
    set item_id = v_item, depleted_quantity = depleted_quantity + v_depleted
    where id = v_position.id;
    v_total := v_total + v_depleted;
    v_index := v_index + 1;
  end loop;
  if exists (select 1 from public.pos_check_lines
    where check_id = v_check and line_index >= v_index) then
    raise exception 'pos_order_changed' using errcode = '22023';
  end if;
  return jsonb_build_object('applied', true, 'depleted', v_total,
    'unmapped', v_unmapped, 'check_id', v_check);
end;
$$;
