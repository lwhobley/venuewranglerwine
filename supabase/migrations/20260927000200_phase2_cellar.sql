-- Phase 2: opening cellar. Quantity and money are numeric. Movements are append-only.
-- Clients can read tenant rows. They cannot insert movements or balances.

create table public.storage_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  parent_id uuid references public.storage_locations (id),
  kind text not null,
  name text not null,
  code text not null,
  capacity_bottles integer,
  active boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint storage_locations_kind_check check (kind in ('room', 'zone', 'staging')),
  constraint storage_locations_code_format check (code ~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$'),
  constraint storage_locations_venue_code_unique unique (venue_id, code)
);

create table public.storage_unit_templates (
  key text primary key,
  label text not null,
  unit_kind text not null,
  default_rows integer not null,
  default_columns integer not null,
  slot_capacity integer not null,
  constraint storage_unit_templates_dims check (
    default_rows between 1 and 20
    and default_columns between 1 and 20
    and slot_capacity between 1 and 120
  )
);

create table public.cellar_map_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  version_number integer not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint cellar_map_versions_unique unique (venue_id, version_number)
);

create table public.storage_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  location_id uuid not null references public.storage_locations (id),
  template_key text not null references public.storage_unit_templates (key),
  map_version_id uuid not null references public.cellar_map_versions (id),
  name text not null,
  code text not null,
  side text not null default 'A',
  row_count integer not null,
  column_count integer not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint storage_units_code_format check (code ~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$'),
  constraint storage_units_location_code_unique unique (location_id, code),
  constraint storage_units_dims check (row_count between 1 and 20 and column_count between 1 and 20)
);

create table public.storage_slots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  unit_id uuid not null references public.storage_units (id),
  row_index integer not null,
  column_index integer not null,
  location_code text not null,
  capacity_bottles integer not null,
  constraint storage_slots_position_unique unique (unit_id, row_index, column_index),
  constraint storage_slots_code_unique unique (venue_id, location_code),
  constraint storage_slots_capacity_check check (capacity_bottles > 0)
);

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  name text not null,
  contact_email text,
  lead_time_days integer,
  active boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint vendors_name_unique unique (organization_id, name),
  constraint vendors_name_len check (char_length(name) between 2 and 80)
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  sku text not null,
  name text not null,
  status text not null default 'active',
  barcode text,
  default_unit_cost numeric(14, 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_items_sku_unique unique (organization_id, sku),
  constraint inventory_items_status_check check (
    status in ('active', 'seasonal', 'archived', 'discontinued', 'unavailable', 'on_order')
  ),
  constraint inventory_items_cost_check check (default_unit_cost is null or default_unit_cost >= 0)
);

create table public.wine_profiles (
  item_id uuid primary key references public.inventory_items (id),
  organization_id uuid not null references public.organizations (id),
  producer text not null,
  cuvee text not null,
  country text,
  region text,
  wine_type text not null,
  vintage integer,
  bottle_ml integer not null,
  format_name text not null,
  constraint wine_profiles_type_check check (
    wine_type in (
      'red', 'white', 'rose', 'sparkling', 'champagne', 'orange',
      'dessert', 'fortified', 'sake', 'non_alcoholic'
    )
  ),
  constraint wine_profiles_vintage_check check (vintage is null or vintage between 1900 and 2100),
  constraint wine_profiles_ml_check check (bottle_ml > 0)
);

create table public.inventory_lots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  item_id uuid not null references public.inventory_items (id),
  vendor_id uuid references public.vendors (id),
  unit_cost numeric(14, 4) not null,
  quantity_on_hand numeric(14, 3) not null default 0,
  created_at timestamptz not null default now(),
  constraint inventory_lots_qty_check check (quantity_on_hand >= 0),
  constraint inventory_lots_cost_check check (unit_cost >= 0)
);

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  vendor_id uuid not null references public.vendors (id),
  status text not null default 'open',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint purchase_orders_status_check check (status in ('open', 'partial', 'received', 'cancelled'))
);

create table public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  purchase_order_id uuid not null references public.purchase_orders (id),
  item_id uuid not null references public.inventory_items (id),
  quantity_ordered numeric(14, 3) not null,
  unit_cost numeric(14, 4) not null,
  constraint purchase_order_lines_qty_check check (quantity_ordered > 0)
);

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  purchase_order_id uuid references public.purchase_orders (id),
  staging_location_id uuid not null references public.storage_locations (id),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.receipt_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  receipt_id uuid not null references public.receipts (id),
  item_id uuid not null references public.inventory_items (id),
  lot_id uuid not null references public.inventory_lots (id),
  quantity numeric(14, 3) not null,
  unit_cost numeric(14, 4) not null,
  constraint receipt_lines_qty_check check (quantity > 0)
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  item_id uuid not null references public.inventory_items (id),
  lot_id uuid not null references public.inventory_lots (id),
  source_location_id uuid references public.storage_locations (id),
  destination_location_id uuid references public.storage_locations (id),
  destination_slot_id uuid references public.storage_slots (id),
  quantity numeric(14, 3) not null,
  source_quantity_before numeric(14, 3) not null,
  source_quantity_after numeric(14, 3) not null,
  destination_quantity_before numeric(14, 3) not null,
  destination_quantity_after numeric(14, 3) not null,
  reason text not null,
  receipt_id uuid references public.receipts (id),
  actor_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint inventory_movements_qty_check check (quantity > 0),
  constraint inventory_movements_reason_check check (reason in ('receive', 'put_away', 'privileged_adjustment'))
);

create table public.inventory_balances (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  item_id uuid not null references public.inventory_items (id),
  lot_id uuid not null references public.inventory_lots (id),
  location_id uuid references public.storage_locations (id),
  slot_id uuid references public.storage_slots (id),
  ownership_class text not null default 'house',
  quantity numeric(14, 3) not null,
  constraint inventory_balances_qty_check check (quantity >= 0),
  constraint inventory_balances_ownership_check check (ownership_class in ('house', 'allocated', 'member'))
);

create unique index inventory_balances_position
  on public.inventory_balances (
    lot_id,
    ownership_class,
    (coalesce(slot_id, '00000000-0000-0000-0000-000000000000'::uuid)),
    (coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid))
  );

create index storage_locations_venue_idx
  on public.storage_locations (organization_id, venue_id)
  where deleted_at is null;

create index storage_slots_venue_idx
  on public.storage_slots (organization_id, venue_id);

create index inventory_items_org_sku_idx
  on public.inventory_items (organization_id, sku);

create index inventory_balances_item_idx
  on public.inventory_balances (organization_id, item_id);

create index inventory_movements_lot_idx
  on public.inventory_movements (organization_id, lot_id, created_at desc);

create index wine_profiles_search_idx
  on public.wine_profiles
  using gin (to_tsvector('simple', producer || ' ' || cuvee || ' ' || coalesce(region, '')));

create trigger storage_locations_updated_at
before update on public.storage_locations
for each row execute function public.set_updated_at();

create trigger inventory_items_updated_at
before update on public.inventory_items
for each row execute function public.set_updated_at();

create trigger inventory_movements_immutable
before update or delete on public.inventory_movements
for each row execute function public.reject_audit_mutation();

insert into public.storage_unit_templates (key, label, unit_kind, default_rows, default_columns, slot_capacity)
values
  ('bin_rack', 'Bin rack', 'bin_rack', 5, 6, 1),
  ('shelf', 'Horizontal shelf', 'shelf', 4, 8, 1),
  ('case_stack', 'Case stack', 'case_stack', 3, 2, 12),
  ('fridge', 'Wine fridge', 'fridge', 4, 3, 1)
on conflict (key) do nothing;

create or replace function public.require_venue_permission(
  p_org uuid,
  p_venue uuid,
  p_permission text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.venues
    where id = p_venue and organization_id = p_org and deleted_at is null
  ) then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(p_org, p_venue, p_permission) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.parse_bottle_quantity(p_quantity text)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
  v_qty numeric;
begin
  begin
    v_qty := p_quantity::numeric;
  exception
    when others then
      raise exception 'invalid_quantity' using errcode = '22023';
  end;
  if v_qty is null or v_qty <= 0 or v_qty <> trunc(v_qty) then
    raise exception 'invalid_quantity' using errcode = '22023';
  end if;
  return v_qty;
end;
$$;

create or replace function public.parse_unit_cost(p_cost text)
returns numeric
language plpgsql
stable
set search_path = ''
as $$
declare
  v_cost numeric;
begin
  begin
    v_cost := p_cost::numeric;
  exception
    when others then
      raise exception 'invalid_cost' using errcode = '22023';
  end;
  if v_cost is null or v_cost < 0 then
    raise exception 'invalid_cost' using errcode = '22023';
  end if;
  return v_cost;
end;
$$;

create or replace function public.ensure_staging_location(p_org uuid, p_venue uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_uid uuid := auth.uid();
begin
  select id into v_id
  from public.storage_locations
  where venue_id = p_venue and kind = 'staging' and deleted_at is null;
  if v_id is not null then
    return v_id;
  end if;
  begin
    insert into public.storage_locations (
      organization_id, venue_id, kind, name, code, created_by
    ) values (
      p_org, p_venue, 'staging', 'Receiving staging', 'STAGING', v_uid
    )
    returning id into v_id;
    return v_id;
  exception
    when unique_violation then
      select id into v_id
      from public.storage_locations
      where venue_id = p_venue and kind = 'staging' and deleted_at is null;
      return v_id;
  end;
end;
$$;

create or replace function public.create_cellar_room(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_code text
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
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.catalog.write');
  perform public.ensure_staging_location(p_organization_id, p_venue_id);
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if v_code !~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$' or char_length(v_code) > 24 then
    raise exception 'invalid_room_code' using errcode = '22023';
  end if;
  insert into public.storage_locations (
    organization_id, venue_id, kind, name, code, created_by
  ) values (
    p_organization_id, p_venue_id, 'room', v_name, v_code, v_uid
  )
  returning id into v_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'cellar.room_created', 'storage_location', v_id,
    jsonb_build_object('code', v_code)
  );
  return v_id;
exception
  when unique_violation then
    raise exception 'code_taken' using errcode = '23505';
end;
$$;

create or replace function public.place_storage_unit(
  p_organization_id uuid,
  p_venue_id uuid,
  p_location_id uuid,
  p_template_key text,
  p_name text,
  p_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_template public.storage_unit_templates%rowtype;
  v_room public.storage_locations%rowtype;
  v_version_id uuid;
  v_version integer;
  v_unit uuid;
  v_code text := pg_catalog.upper(pg_catalog.btrim(p_code));
  v_name text := pg_catalog.btrim(p_name);
  v_row integer;
  v_column integer;
  v_slot_code text;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.catalog.write');
  select * into v_room
  from public.storage_locations
  where id = p_location_id
    and organization_id = p_organization_id
    and venue_id = p_venue_id
    and kind = 'room'
    and deleted_at is null;
  if v_room.id is null then
    raise exception 'room_not_found' using errcode = '22023';
  end if;
  select * into v_template from public.storage_unit_templates where key = p_template_key;
  if v_template.key is null then
    raise exception 'template_not_found' using errcode = '22023';
  end if;
  if v_name is null or char_length(v_name) < 2 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if v_code !~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$' or char_length(v_code) > 24 then
    raise exception 'invalid_unit_code' using errcode = '22023';
  end if;

  select coalesce(max(version_number), 0) + 1 into v_version
  from public.cellar_map_versions
  where venue_id = p_venue_id;
  insert into public.cellar_map_versions (organization_id, venue_id, version_number, created_by)
  values (p_organization_id, p_venue_id, v_version, v_uid)
  returning id into v_version_id;

  insert into public.storage_units (
    organization_id, venue_id, location_id, template_key, map_version_id,
    name, code, side, row_count, column_count, created_by
  ) values (
    p_organization_id, p_venue_id, p_location_id, p_template_key, v_version_id,
    v_name, v_code, 'A', v_template.default_rows, v_template.default_columns, v_uid
  )
  returning id into v_unit;

  for v_row in 1..v_template.default_rows loop
    for v_column in 1..v_template.default_columns loop
      v_slot_code := v_room.code || '/' || v_code || '/SIDE-A/ROW-'
        || pg_catalog.lpad(v_row::text, 2, '0') || '/BIN-'
        || pg_catalog.lpad(v_column::text, 2, '0');
      insert into public.storage_slots (
        organization_id, venue_id, unit_id, row_index, column_index, location_code, capacity_bottles
      ) values (
        p_organization_id, p_venue_id, v_unit, v_row, v_column, v_slot_code, v_template.slot_capacity
      );
    end loop;
  end loop;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'cellar.unit_placed', 'storage_unit', v_unit,
    jsonb_build_object('code', v_code, 'template', p_template_key, 'map_version', v_version)
  );
  return v_unit;
exception
  when unique_violation then
    raise exception 'code_taken' using errcode = '23505';
end;
$$;

create or replace function public.create_vendor(
  p_organization_id uuid,
  p_name text,
  p_email text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_name text := pg_catalog.btrim(p_name);
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.has_permission(p_organization_id, 'wine.purchase') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  insert into public.vendors (organization_id, name, contact_email, created_by)
  values (p_organization_id, v_name, nullif(pg_catalog.lower(pg_catalog.btrim(p_email)), ''), v_uid)
  returning id into v_id;
  insert into public.audit_events (organization_id, actor_id, action, entity_type, entity_id, payload)
  values (p_organization_id, v_uid, 'vendor.created', 'vendor', v_id, jsonb_build_object('name', v_name));
  return v_id;
exception
  when unique_violation then
    raise exception 'vendor_exists' using errcode = '23505';
end;
$$;

create or replace function public.import_wines(
  p_organization_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row jsonb;
  v_index integer := 0;
  v_imported integer := 0;
  v_updated integer := 0;
  v_errors jsonb := '[]'::jsonb;
  v_sku text;
  v_producer text;
  v_cuvee text;
  v_type text;
  v_vintage integer;
  v_ml integer;
  v_cost numeric;
  v_item uuid;
  v_name text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.has_permission(p_organization_id, 'wine.catalog.write') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'invalid_import' using errcode = '22023';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_index := v_index + 1;
    begin
      v_sku := pg_catalog.upper(pg_catalog.btrim(v_row ->> 'sku'));
      v_producer := pg_catalog.btrim(v_row ->> 'producer');
      v_cuvee := pg_catalog.btrim(v_row ->> 'cuvee');
      v_type := pg_catalog.lower(pg_catalog.btrim(v_row ->> 'wine_type'));
      if v_sku is null or v_sku !~ '^[A-Z0-9][A-Z0-9-]{1,31}$' then
        raise exception 'invalid_sku';
      end if;
      if v_producer is null or char_length(v_producer) < 2 or v_cuvee is null or char_length(v_cuvee) < 1 then
        raise exception 'invalid_name';
      end if;
      if v_type not in (
        'red', 'white', 'rose', 'sparkling', 'champagne', 'orange',
        'dessert', 'fortified', 'sake', 'non_alcoholic'
      ) then
        raise exception 'invalid_wine_type';
      end if;
      if nullif(v_row ->> 'vintage', '') is null or pg_catalog.upper(v_row ->> 'vintage') = 'NV' then
        v_vintage := null;
      else
        v_vintage := (v_row ->> 'vintage')::integer;
        if v_vintage < 1900 or v_vintage > 2100 then
          raise exception 'invalid_vintage';
        end if;
      end if;
      v_ml := (v_row ->> 'bottle_ml')::integer;
      if v_ml is null or v_ml <= 0 then
        raise exception 'invalid_bottle_size';
      end if;
      v_cost := public.parse_unit_cost(coalesce(v_row ->> 'unit_cost', '0'));
      v_name := v_producer || ' ' || v_cuvee;

      select id into v_item
      from public.inventory_items
      where organization_id = p_organization_id and sku = v_sku;
      if v_item is null then
        insert into public.inventory_items (organization_id, sku, name, status, default_unit_cost)
        values (p_organization_id, v_sku, v_name, 'active', v_cost)
        returning id into v_item;
        insert into public.wine_profiles (
          item_id, organization_id, producer, cuvee, country, region, wine_type, vintage, bottle_ml, format_name
        ) values (
          v_item, p_organization_id, v_producer, v_cuvee,
          nullif(pg_catalog.btrim(v_row ->> 'country'), ''),
          nullif(pg_catalog.btrim(v_row ->> 'region'), ''),
          v_type, v_vintage, v_ml, coalesce(nullif(v_row ->> 'format_name', ''), '750ml')
        );
        v_imported := v_imported + 1;
      else
        update public.inventory_items
        set name = v_name, default_unit_cost = v_cost
        where id = v_item;
        update public.wine_profiles
        set producer = v_producer,
            cuvee = v_cuvee,
            country = nullif(pg_catalog.btrim(v_row ->> 'country'), ''),
            region = nullif(pg_catalog.btrim(v_row ->> 'region'), ''),
            wine_type = v_type,
            vintage = v_vintage,
            bottle_ml = v_ml
        where item_id = v_item;
        v_updated := v_updated + 1;
      end if;
    exception
      when others then
        v_errors := v_errors || jsonb_build_array(jsonb_build_object('line', v_index, 'message', sqlerrm));
    end;
  end loop;

  insert into public.audit_events (organization_id, actor_id, action, entity_type, payload)
  values (
    p_organization_id, v_uid, 'wine.imported', 'inventory_item',
    jsonb_build_object('imported', v_imported, 'updated', v_updated, 'errors', jsonb_array_length(v_errors))
  );
  return jsonb_build_object('imported', v_imported, 'updated', v_updated, 'errors', v_errors);
end;
$$;

create or replace function public.receive_to_staging(
  p_organization_id uuid,
  p_venue_id uuid,
  p_vendor_id uuid,
  p_item_id uuid,
  p_quantity text,
  p_unit_cost text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_qty numeric(14, 3);
  v_cost numeric(14, 4);
  v_staging uuid;
  v_po uuid;
  v_receipt uuid;
  v_lot uuid;
  v_before numeric(14, 3);
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.receive');
  v_qty := public.parse_bottle_quantity(p_quantity);
  v_cost := public.parse_unit_cost(p_unit_cost);
  if not exists (
    select 1 from public.vendors
    where id = p_vendor_id and organization_id = p_organization_id and active
  ) then
    raise exception 'vendor_not_found' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.inventory_items
    where id = p_item_id and organization_id = p_organization_id
  ) then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  v_staging := public.ensure_staging_location(p_organization_id, p_venue_id);

  insert into public.purchase_orders (organization_id, venue_id, vendor_id, status, created_by)
  values (p_organization_id, p_venue_id, p_vendor_id, 'received', v_uid)
  returning id into v_po;
  insert into public.purchase_order_lines (organization_id, purchase_order_id, item_id, quantity_ordered, unit_cost)
  values (p_organization_id, v_po, p_item_id, v_qty, v_cost);
  insert into public.receipts (organization_id, venue_id, purchase_order_id, staging_location_id, created_by)
  values (p_organization_id, p_venue_id, v_po, v_staging, v_uid)
  returning id into v_receipt;
  insert into public.inventory_lots (organization_id, venue_id, item_id, vendor_id, unit_cost, quantity_on_hand)
  values (p_organization_id, p_venue_id, p_item_id, p_vendor_id, v_cost, v_qty)
  returning id into v_lot;
  insert into public.receipt_lines (organization_id, receipt_id, item_id, lot_id, quantity, unit_cost)
  values (p_organization_id, v_receipt, p_item_id, v_lot, v_qty, v_cost);

  select quantity into v_before
  from public.inventory_balances
  where lot_id = v_lot and location_id = v_staging and slot_id is null and ownership_class = 'house';
  v_before := coalesce(v_before, 0);

  insert into public.inventory_balances (
    organization_id, venue_id, item_id, lot_id, location_id, ownership_class, quantity
  ) values (
    p_organization_id, p_venue_id, p_item_id, v_lot, v_staging, 'house', v_qty
  );

  insert into public.inventory_movements (
    organization_id, venue_id, item_id, lot_id, destination_location_id, quantity,
    source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
    reason, receipt_id, actor_id
  ) values (
    p_organization_id, p_venue_id, p_item_id, v_lot, v_staging, v_qty,
    0, 0, v_before, v_before + v_qty,
    'receive', v_receipt, v_uid
  );

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'wine.received', 'inventory_lot', v_lot,
    jsonb_build_object('quantity', v_qty, 'staging', v_staging)
  );
  return v_lot;
end;
$$;

create or replace function public.put_away(
  p_organization_id uuid,
  p_venue_id uuid,
  p_lot_id uuid,
  p_slot_id uuid,
  p_quantity text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_qty numeric(14, 3);
  v_lot public.inventory_lots%rowtype;
  v_slot public.storage_slots%rowtype;
  v_staging uuid;
  v_source_id uuid;
  v_source_qty numeric(14, 3);
  v_dest_id uuid;
  v_dest_qty numeric(14, 3);
  v_movement uuid;
  v_slot_on_hand numeric(14, 3);
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
  where id = p_slot_id and organization_id = p_organization_id and venue_id = p_venue_id;
  if v_slot.id is null then
    raise exception 'slot_not_found' using errcode = '22023';
  end if;
  v_staging := public.ensure_staging_location(p_organization_id, p_venue_id);

  select id, quantity into v_source_id, v_source_qty
  from public.inventory_balances
  where lot_id = p_lot_id and location_id = v_staging and slot_id is null and ownership_class = 'house'
  for update;
  if v_source_id is null or v_source_qty < v_qty then
    raise exception 'insufficient_quantity' using errcode = '22023';
  end if;

  select coalesce(sum(quantity), 0) into v_slot_on_hand
  from public.inventory_balances
  where slot_id = p_slot_id;
  if v_slot_on_hand + v_qty > v_slot.capacity_bottles then
    raise exception 'slot_over_capacity' using errcode = '22023';
  end if;

  update public.inventory_balances
  set quantity = quantity - v_qty
  where id = v_source_id;
  update public.inventory_lots
  set quantity_on_hand = quantity_on_hand
  where id = p_lot_id;

  select id, quantity into v_dest_id, v_dest_qty
  from public.inventory_balances
  where lot_id = p_lot_id and slot_id = p_slot_id and ownership_class = 'house'
  for update;
  if v_dest_id is null then
    v_dest_qty := 0;
    insert into public.inventory_balances (
      organization_id, venue_id, item_id, lot_id, location_id, slot_id, ownership_class, quantity
    ) values (
      p_organization_id, p_venue_id, v_lot.item_id, p_lot_id,
      (select location_id from public.storage_units where id = v_slot.unit_id),
      p_slot_id, 'house', v_qty
    );
  else
    update public.inventory_balances
    set quantity = quantity + v_qty
    where id = v_dest_id;
  end if;

  insert into public.inventory_movements (
    organization_id, venue_id, item_id, lot_id, source_location_id, destination_slot_id, quantity,
    source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
    reason, actor_id
  ) values (
    p_organization_id, p_venue_id, v_lot.item_id, p_lot_id, v_staging, p_slot_id, v_qty,
    v_source_qty, v_source_qty - v_qty, v_dest_qty, v_dest_qty + v_qty,
    'put_away', v_uid
  )
  returning id into v_movement;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'wine.put_away', 'inventory_movement', v_movement,
    jsonb_build_object('quantity', v_qty, 'slot', v_slot.location_code)
  );
  return v_movement;
end;
$$;

alter table public.storage_locations enable row level security;
alter table public.storage_unit_templates enable row level security;
alter table public.cellar_map_versions enable row level security;
alter table public.storage_units enable row level security;
alter table public.storage_slots enable row level security;
alter table public.vendors enable row level security;
alter table public.inventory_items enable row level security;
alter table public.wine_profiles enable row level security;
alter table public.inventory_lots enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.receipts enable row level security;
alter table public.receipt_lines enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_balances enable row level security;

create policy storage_locations_select on public.storage_locations
for select to authenticated
using (deleted_at is null and public.has_permission(organization_id, 'wine.catalog.read'));

create policy storage_templates_select on public.storage_unit_templates
for select to authenticated
using (true);

create policy cellar_versions_select on public.cellar_map_versions
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy storage_units_select on public.storage_units
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy storage_slots_select on public.storage_slots
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy vendors_select on public.vendors
for select to authenticated
using (
  public.has_permission(organization_id, 'wine.purchase')
  or public.has_permission(organization_id, 'wine.receive')
);

create policy inventory_items_select on public.inventory_items
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy wine_profiles_select on public.wine_profiles
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy inventory_lots_select on public.inventory_lots
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy purchase_orders_select on public.purchase_orders
for select to authenticated
using (public.has_permission(organization_id, 'wine.receive'));

create policy purchase_order_lines_select on public.purchase_order_lines
for select to authenticated
using (public.has_permission(organization_id, 'wine.receive'));

create policy receipts_select on public.receipts
for select to authenticated
using (public.has_permission(organization_id, 'wine.receive'));

create policy receipt_lines_select on public.receipt_lines
for select to authenticated
using (public.has_permission(organization_id, 'wine.receive'));

create policy inventory_movements_select on public.inventory_movements
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy inventory_balances_select on public.inventory_balances
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

revoke all on table public.storage_locations from public, anon, authenticated;
revoke all on table public.storage_unit_templates from public, anon, authenticated;
revoke all on table public.cellar_map_versions from public, anon, authenticated;
revoke all on table public.storage_units from public, anon, authenticated;
revoke all on table public.storage_slots from public, anon, authenticated;
revoke all on table public.vendors from public, anon, authenticated;
revoke all on table public.inventory_items from public, anon, authenticated;
revoke all on table public.wine_profiles from public, anon, authenticated;
revoke all on table public.inventory_lots from public, anon, authenticated;
revoke all on table public.purchase_orders from public, anon, authenticated;
revoke all on table public.purchase_order_lines from public, anon, authenticated;
revoke all on table public.receipts from public, anon, authenticated;
revoke all on table public.receipt_lines from public, anon, authenticated;
revoke all on table public.inventory_movements from public, anon, authenticated;
revoke all on table public.inventory_balances from public, anon, authenticated;

grant select (id, organization_id, venue_id, parent_id, kind, name, code, capacity_bottles, active, created_at)
  on public.storage_locations to authenticated;
grant select on public.storage_unit_templates to authenticated;
grant select on public.cellar_map_versions to authenticated;
grant select (id, organization_id, venue_id, location_id, template_key, map_version_id, name, code, side, row_count, column_count)
  on public.storage_units to authenticated;
grant select (id, organization_id, venue_id, unit_id, row_index, column_index, location_code, capacity_bottles)
  on public.storage_slots to authenticated;
grant select (id, organization_id, name, contact_email, lead_time_days, active)
  on public.vendors to authenticated;
grant select (id, organization_id, sku, name, status, barcode)
  on public.inventory_items to authenticated;
grant select on public.wine_profiles to authenticated;
grant select (id, organization_id, venue_id, item_id, vendor_id, quantity_on_hand, created_at)
  on public.inventory_lots to authenticated;
grant select on public.purchase_orders to authenticated;
grant select (id, organization_id, purchase_order_id, item_id, quantity_ordered)
  on public.purchase_order_lines to authenticated;
grant select on public.receipts to authenticated;
grant select (id, organization_id, receipt_id, item_id, lot_id, quantity)
  on public.receipt_lines to authenticated;
grant select (
  id, organization_id, venue_id, item_id, lot_id, source_location_id, destination_location_id,
  destination_slot_id, quantity, source_quantity_before, source_quantity_after,
  destination_quantity_before, destination_quantity_after, reason, receipt_id, actor_id, created_at
) on public.inventory_movements to authenticated;
grant select (id, organization_id, venue_id, item_id, lot_id, location_id, slot_id, ownership_class, quantity)
  on public.inventory_balances to authenticated;

revoke all on function public.require_venue_permission(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.parse_bottle_quantity(text) from public, anon, authenticated;
revoke all on function public.parse_unit_cost(text) from public, anon, authenticated;
revoke all on function public.ensure_staging_location(uuid, uuid) from public, anon, authenticated;
revoke all on function public.create_cellar_room(uuid, uuid, text, text) from public, anon;
revoke all on function public.place_storage_unit(uuid, uuid, uuid, text, text, text) from public, anon;
revoke all on function public.create_vendor(uuid, text, text) from public, anon;
revoke all on function public.import_wines(uuid, jsonb) from public, anon;
revoke all on function public.receive_to_staging(uuid, uuid, uuid, uuid, text, text) from public, anon;
revoke all on function public.put_away(uuid, uuid, uuid, uuid, text) from public, anon;

grant execute on function public.create_cellar_room(uuid, uuid, text, text) to authenticated;
grant execute on function public.place_storage_unit(uuid, uuid, uuid, text, text, text) to authenticated;
grant execute on function public.create_vendor(uuid, text, text) to authenticated;
grant execute on function public.import_wines(uuid, jsonb) to authenticated;
grant execute on function public.receive_to_staging(uuid, uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.put_away(uuid, uuid, uuid, uuid, text) to authenticated;
