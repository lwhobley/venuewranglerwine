-- Reviewed imports use the existing tenant permissions and inventory ledger.
alter table public.storage_locations drop constraint storage_locations_kind_check;
alter table public.storage_locations add constraint storage_locations_kind_check
  check (kind in ('room', 'zone', 'staging', 'service_bar', 'event_staging', 'member_locker', 'concourse', 'outlet'));

create table public.data_import_keys (
  organization_id uuid not null references public.organizations(id),
  venue_id uuid not null references public.venues(id),
  scope_id uuid not null,
  dataset text not null,
  source_key text not null,
  payload_hash text not null,
  target_id uuid not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (organization_id, scope_id, dataset, source_key)
);
alter table public.data_import_keys enable row level security;
revoke all on public.data_import_keys from public, anon, authenticated;

create or replace function public.import_venue_data(
  p_organization_id uuid, p_venue_id uuid, p_dataset text, p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_permission text;
  v_fields text[];
  v_required text[];
  v_key_fields text[];
  v_row jsonb;
  v_field text;
  v_key text;
  v_seen text[] := array[]::text[];
  v_scope_id uuid;
  v_hash text;
  v_prior public.data_import_keys%rowtype;
  v_target uuid;
  v_parent uuid;
  v_item uuid;
  v_other uuid;
  v_response jsonb;
  v_name text;
  v_code text;
  v_type text;
  v_cost numeric(14,4);
  v_number integer;
  v_index integer := 0;
  v_line integer;
  v_imported integer := 0;
  v_updated integer := 0;
  v_skipped integer := 0;
  v_existing boolean;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  case p_dataset
    when 'inventory' then
      v_permission := 'wine.catalog.write'; v_fields := array['sku','name','unit_cost','barcode','status']; v_required := array['sku','name']; v_key_fields := array['sku'];
    when 'wines' then
      v_permission := 'wine.catalog.write'; v_fields := array['sku','producer','cuvee','wine_type','vintage','bottle_ml','unit_cost','country','region']; v_required := array['sku','producer','cuvee','wine_type','bottle_ml']; v_key_fields := array['sku'];
    when 'locations' then
      v_permission := 'wine.catalog.write'; v_fields := array['code','name','kind','parent_code','capacity_bottles']; v_required := array['code','name','kind']; v_key_fields := array['code'];
    when 'racks' then
      v_permission := 'wine.catalog.write'; v_fields := array['location_code','code','name','template_key']; v_required := v_fields; v_key_fields := array['location_code','code'];
    when 'suppliers' then
      v_permission := 'wine.receive'; v_fields := array['name','email','lead_time_days']; v_required := array['name']; v_key_fields := array['name'];
    when 'stock' then
      v_permission := 'wine.receive'; v_fields := array['external_id','sku','supplier','quantity','unit_cost','slot_code']; v_required := array['external_id','sku','supplier','quantity']; v_key_fields := array['external_id'];
    when 'tables' then
      v_permission := 'floor.design'; v_fields := array['label','capacity']; v_required := v_fields; v_key_fields := array['label'];
    when 'guests' then
      v_permission := 'guest.write'; v_fields := array['external_id','name','allergies','seating','vip']; v_required := array['external_id','name']; v_key_fields := array['external_id'];
    when 'reservations' then
      v_permission := 'reservation.write'; v_fields := array['external_id','guest_external_id','party_size','reserved_at','notes']; v_required := array['external_id','guest_external_id','party_size','reserved_at']; v_key_fields := array['external_id'];
    when 'members' then
      v_permission := 'wine.allocation.manage'; v_fields := array['external_id','name','tier']; v_required := array['external_id','name']; v_key_fields := array['external_id'];
    when 'events' then
      v_permission := 'event.manage'; v_fields := array['external_id','name','guest_count','starts_at']; v_required := v_fields; v_key_fields := array['external_id'];
    when 'shifts' then
      v_permission := 'schedule.publish'; v_fields := array['external_id','role_key','starts_at','ends_at']; v_required := v_fields; v_key_fields := array['external_id'];
    when 'checklists' then
      v_permission := 'checklist.manage'; v_fields := array['name','item_label']; v_required := v_fields; v_key_fields := v_fields;
    when 'documents' then
      v_permission := 'document.manage'; v_fields := array['external_id','title','body']; v_required := v_fields; v_key_fields := array['external_id'];
    when 'wine_lists' then
      v_permission := 'wine.list.publish'; v_fields := array['name','kind','threshold']; v_required := array['name','kind']; v_key_fields := array['name','kind'];
    when 'list_items' then
      v_permission := 'wine.list.publish'; v_fields := array['list_name','list_kind','sku','pour_ml']; v_required := array['list_name','list_kind','sku']; v_key_fields := v_required;
    else raise exception 'invalid_import_dataset' using errcode = '22023';
  end case;
  perform public.require_venue_permission(p_organization_id, p_venue_id, v_permission);
  v_scope_id := case when p_dataset in ('inventory','wines','suppliers','members') then p_organization_id else p_venue_id end;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then raise exception 'invalid_import' using errcode = '22023'; end if;
  if jsonb_array_length(p_rows) not between 1 and 500 or octet_length(p_rows::text) > 2000000 then raise exception 'invalid_import_size' using errcode = '22023'; end if;
  -- Serialize same-scope replays; successful row keys and writes share a transaction.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_organization_id::text || v_scope_id::text || p_dataset, 0));
  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_index := v_index + 1;
    v_line := coalesce((v_row->>'__line')::integer, v_index);
    v_row := v_row - '__line';
    begin
      if jsonb_typeof(v_row) <> 'object' then raise exception 'Each row must be a record.'; end if;
      for v_field in select key from jsonb_each(v_row) loop
        if not v_field = any(v_fields) or jsonb_typeof(v_row->v_field) <> 'string' then raise exception 'Unknown or invalid field: %', v_field; end if;
        if char_length(v_row->>v_field) > 50000 then raise exception 'Field is too long: %', v_field; end if;
        v_row := jsonb_set(v_row, array[v_field], to_jsonb(btrim(v_row->>v_field)));
      end loop;
      foreach v_field in array v_required loop
        if nullif(v_row->>v_field, '') is null then raise exception 'Required field is missing: %', v_field; end if;
      end loop;
      if v_row ? 'sku' then
        v_row := jsonb_set(v_row, '{sku}', to_jsonb(upper(v_row->>'sku')));
        if (v_row->>'sku') !~ '^[A-Z0-9][A-Z0-9-]{1,31}$' then raise exception 'invalid_sku'; end if;
      end if;
      if v_row ? 'code' then
        v_row := jsonb_set(v_row, '{code}', to_jsonb(upper(v_row->>'code')));
        if (v_row->>'code') !~ '^[A-Z0-9]+(?:-[A-Z0-9]+)*$' or char_length(v_row->>'code') > 24 then raise exception 'invalid_room_code'; end if;
      end if;
      foreach v_field in array array['starts_at','ends_at','reserved_at'] loop
        if v_row ? v_field and (v_row->>v_field) !~ '(Z|[+-][0-9]{2}:?[0-9]{2})$' then raise exception 'Times must include Z or a UTC offset: %', v_field; end if;
      end loop;
      select encode(extensions.digest(convert_to(jsonb_agg(lower(v_row->>field) order by position)::text, 'UTF8'), 'sha256'), 'hex') into v_key
        from unnest(v_key_fields) with ordinality as keys(field, position);
      if v_key = any(v_seen) then raise exception 'Duplicate source key in this import.'; end if;
      v_seen := array_append(v_seen, v_key);
      v_hash := encode(extensions.digest(convert_to(v_row::text, 'UTF8'), 'sha256'), 'hex');
      select * into v_prior from public.data_import_keys
        where organization_id = p_organization_id and scope_id = v_scope_id and dataset = p_dataset and source_key = v_key;
      if v_prior.payload_hash = v_hash then v_skipped := v_skipped + 1; continue; end if;
      if v_prior.target_id is not null and p_dataset in ('stock','reservations','events','shifts') then
        raise exception 'This source ID was already imported with different data. Use a new ID for a new transaction.';
      end if;
      v_target := null;
      v_existing := false;
      v_name := v_row->>'name';
      if v_name is not null and char_length(v_name) not between 2 and 80 then raise exception 'invalid_name'; end if;
      case p_dataset
        when 'inventory' then
          v_cost := public.parse_unit_cost(coalesce(nullif(v_row->>'unit_cost',''), '0'));
          select id into v_target from public.inventory_items where organization_id = p_organization_id and sku = v_row->>'sku';
          v_existing := v_target is not null;
          insert into public.inventory_items (organization_id,sku,name,barcode,status,default_unit_cost)
            values (p_organization_id,v_row->>'sku',v_name,nullif(v_row->>'barcode',''),coalesce(nullif(v_row->>'status',''),'active'),v_cost)
            on conflict (organization_id,sku) do update set name = excluded.name, barcode = excluded.barcode, status = excluded.status, default_unit_cost = excluded.default_unit_cost, updated_at = now()
            returning id into v_target;
        when 'wines' then
          if char_length(v_row->>'producer') < 2 then raise exception 'invalid_name'; end if;
          v_cost := public.parse_unit_cost(coalesce(nullif(v_row->>'unit_cost',''), '0'));
          select id into v_target from public.inventory_items where organization_id = p_organization_id and sku = v_row->>'sku';
          v_existing := v_target is not null;
          insert into public.inventory_items (organization_id,sku,name,default_unit_cost)
            values (p_organization_id,v_row->>'sku',(v_row->>'producer') || ' ' || (v_row->>'cuvee'),v_cost)
            on conflict (organization_id,sku) do update set name = excluded.name, default_unit_cost = excluded.default_unit_cost, updated_at = now()
            returning id into v_target;
          insert into public.wine_profiles (item_id,organization_id,producer,cuvee,country,region,wine_type,vintage,bottle_ml,format_name)
            values (v_target,p_organization_id,v_row->>'producer',v_row->>'cuvee',nullif(v_row->>'country',''),nullif(v_row->>'region',''),v_row->>'wine_type',
              case when upper(coalesce(nullif(v_row->>'vintage',''),'NV')) = 'NV' then null else (v_row->>'vintage')::integer end,
              (v_row->>'bottle_ml')::integer,(v_row->>'bottle_ml') || 'ml')
            on conflict (item_id) do update set producer = excluded.producer, cuvee = excluded.cuvee, country = excluded.country, region = excluded.region,
              wine_type = excluded.wine_type, vintage = excluded.vintage, bottle_ml = excluded.bottle_ml, format_name = excluded.format_name;
        when 'locations' then
          v_code := v_row->>'code'; v_type := v_row->>'kind'; v_parent := null;
          if v_type not in ('concourse','outlet','room','zone') then raise exception 'Choose concourse, outlet, room, or zone.'; end if;
          if nullif(v_row->>'parent_code','') is not null then
            select id into v_parent from public.storage_locations where organization_id = p_organization_id and venue_id = p_venue_id and code = upper(v_row->>'parent_code') and deleted_at is null;
            if v_parent is null then raise exception 'Parent code was not found in this venue. Import parents first.'; end if;
          end if;
          select id into v_target from public.storage_locations where organization_id = p_organization_id and venue_id = p_venue_id and code = v_code and deleted_at is null for update;
          v_existing := v_target is not null;
          if v_existing and exists (select 1 from public.storage_locations where id = v_target and kind <> v_type) then raise exception 'Existing location types cannot be changed by import.'; end if;
          if v_target = v_parent or exists (
            with recursive ancestors as (
              select id,parent_id from public.storage_locations where id = v_parent
              union
              select l.id,l.parent_id from public.storage_locations l join ancestors a on a.parent_id = l.id
            ) select 1 from ancestors where id = v_target
          ) then raise exception 'Location parent codes form a cycle.'; end if;
          v_number := nullif(v_row->>'capacity_bottles','')::integer;
          if v_number <= 0 then raise exception 'Capacity must be positive.'; end if;
          if v_existing then
            update public.storage_locations set name = v_name,parent_id = v_parent,capacity_bottles = v_number,updated_at = now() where id = v_target;
          else
            insert into public.storage_locations (organization_id,venue_id,parent_id,kind,name,code,capacity_bottles,created_by)
              values (p_organization_id,p_venue_id,v_parent,v_type,v_name,v_code,v_number,auth.uid()) returning id into v_target;
          end if;
        when 'racks' then
          select id into v_parent from public.storage_locations where organization_id = p_organization_id and venue_id = p_venue_id and code = upper(v_row->>'location_code') and kind = 'room' and deleted_at is null;
          if v_parent is null then raise exception 'Import the rack room first.'; end if;
          select id into v_target from public.storage_units where organization_id = p_organization_id and venue_id = p_venue_id and location_id = v_parent and code = v_row->>'code';
          v_existing := v_target is not null;
          if v_existing then
            if exists (select 1 from public.storage_units where id = v_target and template_key <> v_row->>'template_key') then raise exception 'Existing rack geometry cannot be changed by import.'; end if;
            update public.storage_units set name = v_name where id = v_target;
          else v_target := public.place_storage_unit(p_organization_id,p_venue_id,v_parent,v_row->>'template_key',v_name,v_row->>'code'); end if;
        when 'suppliers' then
          if nullif(v_row->>'email','') is not null and (v_row->>'email') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'invalid_email'; end if;
          v_number := nullif(v_row->>'lead_time_days','')::integer;
          if v_number < 0 then raise exception 'Lead time cannot be negative.'; end if;
          if (select count(*) from public.vendors where organization_id = p_organization_id and lower(name) = lower(v_name)) > 1 then raise exception 'Supplier name is ambiguous. Resolve duplicate names first.'; end if;
          select id into v_target from public.vendors where organization_id = p_organization_id and lower(name) = lower(v_name);
          v_existing := v_target is not null;
          if not v_existing then v_target := public.create_vendor(p_organization_id,v_name,nullif(v_row->>'email','')); end if;
          update public.vendors set contact_email = nullif(v_row->>'email',''), lead_time_days = v_number where id = v_target;
        when 'stock' then
          if (select count(*) from public.vendors where organization_id = p_organization_id and lower(name) = lower(v_row->>'supplier') and active) <> 1 then raise exception 'Import a unique active supplier first.'; end if;
          select id into v_other from public.vendors where organization_id = p_organization_id and lower(name) = lower(v_row->>'supplier') and active;
          select id into v_item from public.inventory_items where organization_id = p_organization_id and sku = v_row->>'sku';
          if v_item is null then raise exception 'Import this SKU into the catalog first.'; end if;
          v_target := public.receive_to_staging(p_organization_id,p_venue_id,v_other,v_item,v_row->>'quantity',coalesce(nullif(v_row->>'unit_cost',''),'0'));
          if nullif(v_row->>'slot_code','') is not null then
            select id into v_other from public.storage_slots where organization_id = p_organization_id and venue_id = p_venue_id and location_code = upper(v_row->>'slot_code');
            if v_other is null then raise exception 'Destination bin was not found in this venue.'; end if;
            perform public.put_away(p_organization_id,p_venue_id,v_target,v_other,v_row->>'quantity');
          end if;
        when 'tables' then
          v_number := (v_row->>'capacity')::integer;
          if v_number not between 1 and 20 then raise exception 'invalid_party'; end if;
          select id into v_target from public.floor_tables where organization_id = p_organization_id and venue_id = p_venue_id and lower(label) = lower(v_row->>'label') for update;
          v_existing := v_target is not null;
          if v_existing then
            if exists (select 1 from public.reservations where table_id = v_target and status = 'seated' and party_size > v_number) then raise exception 'Capacity cannot be reduced below the seated party size.'; end if;
            update public.floor_tables set capacity = v_number where id = v_target;
          else v_target := public.create_floor_table(p_organization_id,p_venue_id,v_row->>'label',v_number); end if;
        when 'guests' then
          v_target := v_prior.target_id; v_existing := v_target is not null;
          if v_existing then
            update public.guests set display_name = v_name, allergies = nullif(v_row->>'allergies',''), seating_preference = nullif(v_row->>'seating',''),vip = coalesce(nullif(v_row->>'vip',''),'false')::boolean
              where id = v_target and organization_id = p_organization_id and venue_id = p_venue_id;
            if not found then raise exception 'Imported guest no longer exists.'; end if;
          else v_target := public.create_guest(p_organization_id,p_venue_id,v_name,v_row->>'allergies',v_row->>'seating',coalesce(nullif(v_row->>'vip',''),'false')::boolean); end if;
        when 'reservations' then
          select target_id into v_other from public.data_import_keys where organization_id = p_organization_id and scope_id = p_venue_id and dataset = 'guests' and source_key = encode(extensions.digest(convert_to(jsonb_build_array(lower(v_row->>'guest_external_id'))::text,'UTF8'),'sha256'),'hex');
          if v_other is null then raise exception 'Import the referenced guest source ID first.'; end if;
          v_target := public.create_reservation(p_organization_id,p_venue_id,v_other,(v_row->>'party_size')::integer,(v_row->>'reserved_at')::timestamptz,v_row->>'notes');
        when 'members' then
          v_target := v_prior.target_id; v_existing := v_target is not null;
          if v_existing then
            update public.wine_club_members set display_name = v_name,tier = coalesce(nullif(v_row->>'tier',''),'standard') where id = v_target and organization_id = p_organization_id;
            if not found then raise exception 'Imported member no longer exists.'; end if;
          else v_target := public.create_club_member(p_organization_id,v_name,coalesce(nullif(v_row->>'tier',''),'standard')); end if;
        when 'events' then
          v_target := public.create_event(p_organization_id,p_venue_id,v_name,(v_row->>'guest_count')::integer,(v_row->>'starts_at')::timestamptz);
        when 'shifts' then
          v_target := public.create_shift(p_organization_id,p_venue_id,v_row->>'role_key',(v_row->>'starts_at')::timestamptz,(v_row->>'ends_at')::timestamptz);
        when 'checklists' then
          if (select count(*) from public.checklist_templates where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_name)) > 1 then raise exception 'Checklist name is ambiguous.'; end if;
          select id into v_parent from public.checklist_templates where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_name);
          if v_parent is null then
            v_parent := public.create_checklist(p_organization_id,p_venue_id,v_name,v_row->>'item_label');
            select id into v_target from public.checklist_items where template_id = v_parent and lower(label) = lower(v_row->>'item_label');
          else
            select id into v_target from public.checklist_items where template_id = v_parent and organization_id = p_organization_id and lower(label) = lower(v_row->>'item_label');
            v_existing := v_target is not null;
            if not v_existing then insert into public.checklist_items (template_id,organization_id,label) values (v_parent,p_organization_id,v_row->>'item_label') returning id into v_target; end if;
          end if;
        when 'documents' then
          v_target := v_prior.target_id; v_existing := v_target is not null;
          if char_length(v_row->>'title') not between 2 and 120 then raise exception 'invalid_name'; end if;
          if v_existing then
            update public.documents set title = v_row->>'title',body = v_row->>'body' where id = v_target and organization_id = p_organization_id and venue_id = p_venue_id;
            if not found then raise exception 'Imported document no longer exists.'; end if;
          else v_target := public.create_document(p_organization_id,p_venue_id,v_row->>'title',v_row->>'body'); end if;
        when 'wine_lists' then
          if (select count(*) from public.wine_lists where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_name) and kind = v_row->>'kind') > 1 then raise exception 'List name and type are ambiguous.'; end if;
          select id into v_target from public.wine_lists where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_name) and kind = v_row->>'kind';
          v_existing := v_target is not null;
          v_number := coalesce(nullif(v_row->>'threshold',''),'2')::integer;
          if v_number < 0 then raise exception 'invalid_threshold'; end if;
          if v_existing then update public.wine_lists set threshold_bottles = v_number where id = v_target;
          else v_target := public.create_wine_list(p_organization_id,p_venue_id,v_name,v_row->>'kind',v_number); end if;
        when 'list_items' then
          if (select count(*) from public.wine_lists where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_row->>'list_name') and kind = v_row->>'list_kind') <> 1 then raise exception 'Import a unique wine list first.'; end if;
          select id into v_parent from public.wine_lists where organization_id = p_organization_id and venue_id = p_venue_id and lower(name) = lower(v_row->>'list_name') and kind = v_row->>'list_kind';
          select id into v_item from public.inventory_items where organization_id = p_organization_id and sku = v_row->>'sku';
          if v_item is null then raise exception 'Import this SKU into the catalog first.'; end if;
          v_number := nullif(v_row->>'pour_ml','')::integer;
          if v_number <= 0 or (v_row->>'list_kind' = 'glass' and v_number is null) then raise exception 'invalid_pour'; end if;
          select id into v_target from public.wine_list_items where list_id = v_parent and item_id = v_item;
          v_existing := v_target is not null;
          if v_existing then update public.wine_list_items set pour_ml = v_number where id = v_target;
          else v_target := public.add_wine_list_item(v_parent,v_item,v_number); end if;
      end case;
      if v_target is null then raise exception 'The record could not be saved.'; end if;
      insert into public.data_import_keys (organization_id,venue_id,scope_id,dataset,source_key,payload_hash,target_id,created_by)
        values (p_organization_id,p_venue_id,v_scope_id,p_dataset,v_key,v_hash,v_target,auth.uid())
        on conflict (organization_id,scope_id,dataset,source_key) do update set payload_hash = excluded.payload_hash;
      if v_existing then v_updated := v_updated + 1; else v_imported := v_imported + 1; end if;
    exception when others then
      -- Raising rolls back the entire batch, including receipts and deduplication keys.
      raise exception 'Import row %: %', v_line, sqlerrm using errcode = '22023';
    end;
  end loop;
  v_response := jsonb_build_object('imported',v_imported,'updated',v_updated,'skipped',v_skipped);
  insert into public.audit_events (organization_id,venue_id,actor_id,action,entity_type,payload)
    values (p_organization_id,p_venue_id,auth.uid(),'data.imported',p_dataset,v_response);
  return v_response;
end;
$$;
revoke all on function public.import_venue_data(uuid,uuid,text,jsonb) from public, anon;
grant execute on function public.import_venue_data(uuid,uuid,text,jsonb) to authenticated;
