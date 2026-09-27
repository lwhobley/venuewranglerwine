-- Phase 6: list availability, open bottles, and pours.
-- Opening a bottle takes one house bottle. Allocated and member stock are not poured.

alter table public.inventory_movements
  drop constraint inventory_movements_reason_check;

alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in (
    'receive', 'put_away', 'privileged_adjustment', 'count_adjustment',
    'transfer_service', 'transfer_event', 'transfer_locker',
    'allocation_reserve', 'allocation_pickup', 'service_open'
  ));

create table public.wine_lists (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  name text not null,
  kind text not null,
  published boolean not null default false,
  threshold_bottles integer not null default 1,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint wine_lists_name_len check (char_length(name) between 2 and 80),
  constraint wine_lists_kind_check check (kind in ('glass', 'bottle', 'reserve', 'member', 'event')),
  constraint wine_lists_threshold_check check (threshold_bottles >= 0)
);

create table public.wine_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.wine_lists (id),
  organization_id uuid not null references public.organizations (id),
  item_id uuid not null references public.inventory_items (id),
  pour_ml integer,
  manual_86 boolean not null default false,
  constraint wine_list_items_unique unique (list_id, item_id),
  constraint wine_list_items_pour_check check (pour_ml is null or pour_ml > 0)
);

create table public.open_bottles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  item_id uuid not null references public.inventory_items (id),
  lot_id uuid not null references public.inventory_lots (id),
  slot_id uuid not null references public.storage_slots (id),
  opened_ml integer not null,
  remaining_ml integer not null,
  status text not null default 'open',
  opened_by uuid not null references public.profiles (id),
  opened_at timestamptz not null default now(),
  constraint open_bottles_ml_check check (opened_ml > 0 and remaining_ml >= 0 and remaining_ml <= opened_ml),
  constraint open_bottles_status_check check (status in ('open', 'finished'))
);

create table public.service_depletions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  item_id uuid not null references public.inventory_items (id),
  open_bottle_id uuid references public.open_bottles (id),
  pour_ml integer not null,
  reason text not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint service_depletions_pour_check check (pour_ml > 0),
  constraint service_depletions_reason_check check (reason in ('glass', 'tasting', 'comp', 'waste'))
);

create index open_bottles_venue_idx
  on public.open_bottles (venue_id, item_id)
  where status = 'open';

create or replace function public.create_wine_list(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_kind text,
  p_threshold integer
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
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.list.publish');
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_kind not in ('glass', 'bottle', 'reserve', 'member', 'event') then
    raise exception 'invalid_list_kind' using errcode = '22023';
  end if;
  if p_threshold is null or p_threshold < 0 then
    raise exception 'invalid_threshold' using errcode = '22023';
  end if;
  insert into public.wine_lists (
    organization_id, venue_id, name, kind, threshold_bottles, created_by
  ) values (
    p_organization_id, p_venue_id, v_name, p_kind, p_threshold, v_uid
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.add_wine_list_item(
  p_list_id uuid,
  p_item_id uuid,
  p_pour_ml integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_list public.wine_lists%rowtype;
  v_id uuid;
begin
  select * into v_list from public.wine_lists where id = p_list_id;
  if v_list.id is null then
    raise exception 'list_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_list.organization_id, v_list.venue_id, 'wine.list.publish');
  if not exists (
    select 1 from public.inventory_items
    where id = p_item_id and organization_id = v_list.organization_id
  ) then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  if v_list.kind = 'glass' and (p_pour_ml is null or p_pour_ml <= 0) then
    raise exception 'invalid_pour' using errcode = '22023';
  end if;
  insert into public.wine_list_items (list_id, organization_id, item_id, pour_ml)
  values (p_list_id, v_list.organization_id, p_item_id, p_pour_ml)
  returning id into v_id;
  return v_id;
exception
  when unique_violation then
    raise exception 'list_item_exists' using errcode = '23505';
end;
$$;

create or replace function public.publish_wine_list(p_list_id uuid, p_published boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_list public.wine_lists%rowtype;
begin
  select * into v_list from public.wine_lists where id = p_list_id;
  if v_list.id is null then
    raise exception 'list_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_list.organization_id, v_list.venue_id, 'wine.list.publish');
  update public.wine_lists set published = p_published where id = p_list_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_list.organization_id, v_list.venue_id, auth.uid(), 'wine.list_published', 'wine_list', p_list_id,
    jsonb_build_object('published', p_published)
  );
end;
$$;

create or replace function public.set_wine_86(p_list_item_id uuid, p_eighty_sixed boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.wine_list_items%rowtype;
  v_list public.wine_lists%rowtype;
begin
  select * into v_item from public.wine_list_items where id = p_list_item_id;
  if v_item.id is null then
    raise exception 'list_not_found' using errcode = '22023';
  end if;
  select * into v_list from public.wine_lists where id = v_item.list_id;
  perform public.require_venue_permission(v_list.organization_id, v_list.venue_id, 'wine.list.publish');
  update public.wine_list_items set manual_86 = p_eighty_sixed where id = p_list_item_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_list.organization_id, v_list.venue_id, auth.uid(), 'wine.86', 'wine_list_item', p_list_item_id,
    jsonb_build_object('manual_86', p_eighty_sixed)
  );
end;
$$;

create or replace function public.open_service_bottle(p_venue_id uuid, p_item_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid;
  v_balance record;
  v_ml integer;
  v_id uuid;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  if v_org is null then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_org, p_venue_id, 'wine.movement.write');
  select bottle_ml into v_ml from public.wine_profiles where item_id = p_item_id and organization_id = v_org;
  if v_ml is null then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  select id, lot_id, slot_id, quantity
  into v_balance
  from public.inventory_balances
  where venue_id = p_venue_id
    and item_id = p_item_id
    and ownership_class = 'house'
    and slot_id is not null
    and quantity >= 1
  order by quantity desc, id
  limit 1
  for update;
  if v_balance.id is null then
    raise exception 'insufficient_quantity' using errcode = '22023';
  end if;
  update public.inventory_balances set quantity = quantity - 1 where id = v_balance.id;
  update public.inventory_lots set quantity_on_hand = quantity_on_hand - 1 where id = v_balance.lot_id;
  insert into public.open_bottles (
    organization_id, venue_id, item_id, lot_id, slot_id, opened_ml, remaining_ml, opened_by
  ) values (
    v_org, p_venue_id, p_item_id, v_balance.lot_id, v_balance.slot_id, v_ml, v_ml, v_uid
  )
  returning id into v_id;
  insert into public.inventory_movements (
    organization_id, venue_id, item_id, lot_id, source_slot_id, quantity,
    source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
    reason, actor_id
  ) values (
    v_org, p_venue_id, p_item_id, v_balance.lot_id, v_balance.slot_id, 1,
    v_balance.quantity, v_balance.quantity - 1, 0, 0,
    'service_open', v_uid
  );
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (v_org, p_venue_id, v_uid, 'wine.bottle_opened', 'open_bottle', v_id);
  return v_id;
end;
$$;

create or replace function public.record_pour(
  p_open_bottle_id uuid,
  p_pour_ml integer,
  p_reason text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_bottle public.open_bottles%rowtype;
begin
  if p_reason not in ('glass', 'tasting', 'comp', 'waste') then
    raise exception 'invalid_pour' using errcode = '22023';
  end if;
  if p_pour_ml is null or p_pour_ml <= 0 then
    raise exception 'invalid_pour' using errcode = '22023';
  end if;
  select * into v_bottle from public.open_bottles where id = p_open_bottle_id for update;
  if v_bottle.id is null or v_bottle.status <> 'open' then
    raise exception 'bottle_not_open' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_bottle.organization_id, v_bottle.venue_id, 'wine.movement.write');
  if v_bottle.remaining_ml < p_pour_ml then
    raise exception 'insufficient_pour' using errcode = '22023';
  end if;
  update public.open_bottles
  set remaining_ml = remaining_ml - p_pour_ml,
      status = case when remaining_ml - p_pour_ml = 0 then 'finished' else 'open' end
  where id = p_open_bottle_id;
  insert into public.service_depletions (
    organization_id, venue_id, item_id, open_bottle_id, pour_ml, reason, created_by
  ) values (
    v_bottle.organization_id, v_bottle.venue_id, v_bottle.item_id, p_open_bottle_id, p_pour_ml, p_reason, v_uid
  );
  return v_bottle.remaining_ml - p_pour_ml;
end;
$$;

create or replace function public.service_board(p_venue_id uuid)
returns table (
  list_id uuid,
  list_name text,
  list_kind text,
  published boolean,
  list_item_id uuid,
  item_id uuid,
  sku text,
  label text,
  pour_ml integer,
  manual_86 boolean,
  house_bottles numeric,
  open_remaining_ml integer,
  available boolean,
  unavailable_reason text
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
     and not public.has_scoped_permission(v_org, p_venue_id, 'wine.list.publish')
     and not public.has_scoped_permission(v_org, p_venue_id, 'wine.movement.write') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  select
    l.id,
    l.name,
    l.kind,
    l.published,
    li.id,
    li.item_id,
    i.sku,
    nullif(pg_catalog.btrim(coalesce(w.producer, '') || ' ' || coalesce(w.cuvee, '')), ''),
    li.pour_ml,
    li.manual_86,
    coalesce((
      select sum(b.quantity)
      from public.inventory_balances b
      where b.venue_id = p_venue_id
        and b.item_id = li.item_id
        and b.ownership_class = 'house'
        and b.slot_id is not null
    ), 0),
    coalesce((
      select sum(ob.remaining_ml)::integer
      from public.open_bottles ob
      where ob.venue_id = p_venue_id and ob.item_id = li.item_id and ob.status = 'open'
    ), 0),
    l.published
      and not li.manual_86
      and (
        coalesce((
          select sum(b.quantity)
          from public.inventory_balances b
          where b.venue_id = p_venue_id
            and b.item_id = li.item_id
            and b.ownership_class = 'house'
            and b.slot_id is not null
        ), 0) >= l.threshold_bottles
        or (
          li.pour_ml is not null
          and coalesce((
            select sum(ob.remaining_ml)
            from public.open_bottles ob
            where ob.venue_id = p_venue_id and ob.item_id = li.item_id and ob.status = 'open'
          ), 0) >= li.pour_ml
        )
      ),
    case
      when not l.published then 'unpublished'
      when li.manual_86 then 'manual_86'
      when coalesce((
        select sum(b.quantity)
        from public.inventory_balances b
        where b.venue_id = p_venue_id
          and b.item_id = li.item_id
          and b.ownership_class = 'house'
          and b.slot_id is not null
      ), 0) < l.threshold_bottles
        and not (
          li.pour_ml is not null
          and coalesce((
            select sum(ob.remaining_ml)
            from public.open_bottles ob
            where ob.venue_id = p_venue_id and ob.item_id = li.item_id and ob.status = 'open'
          ), 0) >= li.pour_ml
        ) then 'below_threshold'
      else null
    end
  from public.wine_lists l
  join public.wine_list_items li on li.list_id = l.id
  join public.inventory_items i on i.id = li.item_id
  left join public.wine_profiles w on w.item_id = li.item_id
  where l.venue_id = p_venue_id
  order by l.name, i.sku;
end;
$$;

alter table public.wine_lists enable row level security;
alter table public.wine_list_items enable row level security;
alter table public.open_bottles enable row level security;
alter table public.service_depletions enable row level security;

create policy wine_lists_select on public.wine_lists
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy wine_list_items_select on public.wine_list_items
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy open_bottles_select on public.open_bottles
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

create policy service_depletions_select on public.service_depletions
for select to authenticated
using (public.has_permission(organization_id, 'wine.catalog.read'));

revoke all on table public.wine_lists from public, anon, authenticated;
revoke all on table public.wine_list_items from public, anon, authenticated;
revoke all on table public.open_bottles from public, anon, authenticated;
revoke all on table public.service_depletions from public, anon, authenticated;

grant select (id, organization_id, venue_id, name, kind, published, threshold_bottles)
  on public.wine_lists to authenticated;
grant select (id, list_id, organization_id, item_id, pour_ml, manual_86)
  on public.wine_list_items to authenticated;
grant select (id, organization_id, venue_id, item_id, remaining_ml, status, opened_ml)
  on public.open_bottles to authenticated;
grant select (id, organization_id, venue_id, item_id, pour_ml, reason, created_at)
  on public.service_depletions to authenticated;

revoke all on function public.create_wine_list(uuid, uuid, text, text, integer) from public, anon;
revoke all on function public.add_wine_list_item(uuid, uuid, integer) from public, anon;
revoke all on function public.publish_wine_list(uuid, boolean) from public, anon;
revoke all on function public.set_wine_86(uuid, boolean) from public, anon;
revoke all on function public.open_service_bottle(uuid, uuid) from public, anon;
revoke all on function public.record_pour(uuid, integer, text) from public, anon;
revoke all on function public.service_board(uuid) from public, anon;

grant execute on function public.create_wine_list(uuid, uuid, text, text, integer) to authenticated;
grant execute on function public.add_wine_list_item(uuid, uuid, integer) to authenticated;
grant execute on function public.publish_wine_list(uuid, boolean) to authenticated;
grant execute on function public.set_wine_86(uuid, boolean) to authenticated;
grant execute on function public.open_service_bottle(uuid, uuid) to authenticated;
grant execute on function public.record_pour(uuid, integer, text) to authenticated;
grant execute on function public.service_board(uuid) to authenticated;
