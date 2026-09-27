-- Phase 5: reserve house bottles onto an allocation hold.
-- Transfer and a second release only see ownership_class = house, so the same bottles cannot be taken twice.

alter table public.inventory_movements
  drop constraint inventory_movements_reason_check;

alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in (
    'receive', 'put_away', 'privileged_adjustment', 'count_adjustment',
    'transfer_service', 'transfer_event', 'transfer_locker',
    'allocation_reserve', 'allocation_pickup'
  ));

create table public.wine_club_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  display_name text not null,
  tier text not null default 'standard',
  active boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint wine_club_members_name_len check (char_length(display_name) between 2 and 80),
  constraint wine_club_members_tier_check check (tier in ('standard', 'reserve', 'founding'))
);

create table public.allocation_campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  name text not null,
  release_on date not null,
  status text not null default 'draft',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint allocation_campaigns_name_len check (char_length(name) between 2 and 80),
  constraint allocation_campaigns_status_check check (status in ('draft', 'reserved', 'closed'))
);

create table public.allocation_lines (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.allocation_campaigns (id),
  organization_id uuid not null references public.organizations (id),
  member_id uuid not null references public.wine_club_members (id),
  item_id uuid not null references public.inventory_items (id),
  quantity_required numeric(14, 3) not null,
  quantity_reserved numeric(14, 3) not null default 0,
  quantity_fulfilled numeric(14, 3) not null default 0,
  constraint allocation_lines_required_check check (quantity_required > 0),
  constraint allocation_lines_reserved_check check (
    quantity_reserved >= 0 and quantity_reserved <= quantity_required
  ),
  constraint allocation_lines_fulfilled_check check (
    quantity_fulfilled >= 0 and quantity_fulfilled <= quantity_reserved
  )
);

create table public.allocation_holds (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  line_id uuid not null references public.allocation_lines (id),
  lot_id uuid not null references public.inventory_lots (id),
  slot_id uuid not null references public.storage_slots (id),
  quantity_reserved numeric(14, 3) not null,
  quantity_fulfilled numeric(14, 3) not null default 0,
  constraint allocation_holds_qty_check check (
    quantity_reserved > 0 and quantity_fulfilled >= 0 and quantity_fulfilled <= quantity_reserved
  )
);

create table public.fulfillment_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  line_id uuid not null references public.allocation_lines (id),
  hold_id uuid not null references public.allocation_holds (id),
  quantity numeric(14, 3) not null,
  fulfilled_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint fulfillment_records_qty_check check (quantity > 0)
);

create index allocation_lines_campaign_idx on public.allocation_lines (campaign_id);
create index allocation_holds_line_idx on public.allocation_holds (line_id);

create or replace function public.create_club_member(
  p_organization_id uuid,
  p_display_name text,
  p_tier text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_name text := pg_catalog.btrim(p_display_name);
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.has_permission(p_organization_id, 'wine.allocation.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_tier not in ('standard', 'reserve', 'founding') then
    raise exception 'invalid_tier' using errcode = '22023';
  end if;
  insert into public.wine_club_members (organization_id, display_name, tier, created_by)
  values (p_organization_id, v_name, p_tier, v_uid)
  returning id into v_id;
  insert into public.audit_events (organization_id, actor_id, action, entity_type, entity_id)
  values (p_organization_id, v_uid, 'allocation.member_created', 'wine_club_member', v_id);
  return v_id;
end;
$$;

create or replace function public.create_allocation_campaign(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_release_on date
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
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.allocation.manage');
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_release_on is null then
    raise exception 'invalid_release_date' using errcode = '22023';
  end if;
  insert into public.allocation_campaigns (
    organization_id, venue_id, name, release_on, created_by
  ) values (
    p_organization_id, p_venue_id, v_name, p_release_on, v_uid
  )
  returning id into v_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (p_organization_id, p_venue_id, v_uid, 'allocation.campaign_created', 'allocation_campaign', v_id);
  return v_id;
end;
$$;

create or replace function public.add_allocation_line(
  p_campaign_id uuid,
  p_member_id uuid,
  p_item_id uuid,
  p_quantity text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.allocation_campaigns%rowtype;
  v_qty numeric(14, 3);
  v_id uuid;
begin
  select * into v_campaign from public.allocation_campaigns where id = p_campaign_id for update;
  if v_campaign.id is null then
    raise exception 'campaign_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_campaign.organization_id, v_campaign.venue_id, 'wine.allocation.manage');
  if v_campaign.status <> 'draft' then
    raise exception 'campaign_not_draft' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.wine_club_members
    where id = p_member_id and organization_id = v_campaign.organization_id and active
  ) then
    raise exception 'member_not_found' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.inventory_items
    where id = p_item_id and organization_id = v_campaign.organization_id
  ) then
    raise exception 'item_not_found' using errcode = '22023';
  end if;
  v_qty := public.parse_bottle_quantity(p_quantity);
  insert into public.allocation_lines (
    campaign_id, organization_id, member_id, item_id, quantity_required
  ) values (
    p_campaign_id, v_campaign.organization_id, p_member_id, p_item_id, v_qty
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.reserve_allocation(p_campaign_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_campaign public.allocation_campaigns%rowtype;
  v_line public.allocation_lines%rowtype;
  v_balance record;
  v_need numeric(14, 3);
  v_take numeric(14, 3);
  v_holds integer := 0;
begin
  select * into v_campaign from public.allocation_campaigns where id = p_campaign_id for update;
  if v_campaign.id is null then
    raise exception 'campaign_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_campaign.organization_id, v_campaign.venue_id, 'wine.allocation.manage');
  if v_campaign.status <> 'draft' then
    raise exception 'campaign_not_draft' using errcode = '22023';
  end if;

  for v_line in
    select * from public.allocation_lines
    where campaign_id = p_campaign_id
    order by id
    for update
  loop
    v_need := v_line.quantity_required - v_line.quantity_reserved;
    for v_balance in
      select id, lot_id, slot_id, quantity
      from public.inventory_balances
      where venue_id = v_campaign.venue_id
        and item_id = v_line.item_id
        and ownership_class = 'house'
        and slot_id is not null
        and quantity > 0
      order by quantity desc, id
      for update
    loop
      exit when v_need <= 0;
      v_take := least(v_balance.quantity, v_need);
      update public.inventory_balances
      set quantity = quantity - v_take
      where id = v_balance.id;

      perform 1
      from public.inventory_balances
      where lot_id = v_balance.lot_id
        and slot_id = v_balance.slot_id
        and ownership_class = 'allocated'
      for update;
      if not found then
        insert into public.inventory_balances (
          organization_id, venue_id, item_id, lot_id, slot_id, location_id, ownership_class, quantity
        )
        select
          v_campaign.organization_id, v_campaign.venue_id, v_line.item_id, v_balance.lot_id, v_balance.slot_id,
          u.location_id, 'allocated', v_take
        from public.storage_slots s
        join public.storage_units u on u.id = s.unit_id
        where s.id = v_balance.slot_id;
      else
        update public.inventory_balances
        set quantity = quantity + v_take
        where lot_id = v_balance.lot_id
          and slot_id = v_balance.slot_id
          and ownership_class = 'allocated';
      end if;

      insert into public.allocation_holds (
        organization_id, line_id, lot_id, slot_id, quantity_reserved
      ) values (
        v_campaign.organization_id, v_line.id, v_balance.lot_id, v_balance.slot_id, v_take
      );
      insert into public.inventory_movements (
        organization_id, venue_id, item_id, lot_id, source_slot_id, destination_slot_id, quantity,
        source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
        reason, actor_id
      ) values (
        v_campaign.organization_id, v_campaign.venue_id, v_line.item_id, v_balance.lot_id,
        v_balance.slot_id, v_balance.slot_id, v_take,
        v_balance.quantity, v_balance.quantity - v_take, 0, v_take,
        'allocation_reserve', v_uid
      );
      v_need := v_need - v_take;
      v_holds := v_holds + 1;
    end loop;
    update public.allocation_lines
    set quantity_reserved = quantity_required - v_need
    where id = v_line.id;
  end loop;

  update public.allocation_campaigns set status = 'reserved' where id = p_campaign_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_campaign.organization_id, v_campaign.venue_id, v_uid, 'allocation.reserved', 'allocation_campaign', p_campaign_id,
    jsonb_build_object('holds', v_holds)
  );
  return v_holds;
end;
$$;

create or replace function public.fulfill_allocation_pickup(
  p_line_id uuid,
  p_quantity text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_line public.allocation_lines%rowtype;
  v_campaign public.allocation_campaigns%rowtype;
  v_hold public.allocation_holds%rowtype;
  v_qty numeric(14, 3);
  v_left numeric(14, 3);
  v_take numeric(14, 3);
  v_allocated numeric(14, 3);
  v_balance uuid;
  v_record uuid;
begin
  v_qty := public.parse_bottle_quantity(p_quantity);
  select * into v_line from public.allocation_lines where id = p_line_id for update;
  if v_line.id is null then
    raise exception 'allocation_not_found' using errcode = '22023';
  end if;
  select * into v_campaign from public.allocation_campaigns where id = v_line.campaign_id;
  perform public.require_venue_permission(v_campaign.organization_id, v_campaign.venue_id, 'wine.allocation.manage');
  if v_campaign.status <> 'reserved' then
    raise exception 'campaign_not_reserved' using errcode = '22023';
  end if;
  if v_line.quantity_reserved - v_line.quantity_fulfilled < v_qty then
    raise exception 'insufficient_reserved' using errcode = '22023';
  end if;
  v_left := v_qty;
  for v_hold in
    select * from public.allocation_holds
    where line_id = p_line_id and quantity_fulfilled < quantity_reserved
    order by id
    for update
  loop
    exit when v_left <= 0;
    v_take := least(v_hold.quantity_reserved - v_hold.quantity_fulfilled, v_left);
    select id, quantity into v_balance, v_allocated
    from public.inventory_balances
    where lot_id = v_hold.lot_id and slot_id = v_hold.slot_id and ownership_class = 'allocated'
    for update;
    if v_balance is null or v_allocated < v_take then
      raise exception 'insufficient_reserved' using errcode = '22023';
    end if;
    update public.inventory_balances set quantity = quantity - v_take where id = v_balance;
    insert into public.inventory_movements (
      organization_id, venue_id, item_id, lot_id, source_slot_id, destination_slot_id, quantity,
      source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
      reason, actor_id
    ) values (
      v_campaign.organization_id, v_campaign.venue_id, v_line.item_id, v_hold.lot_id,
      v_hold.slot_id, v_hold.slot_id, v_take,
      v_allocated, v_allocated - v_take, 0, v_take,
      'allocation_pickup', v_uid
    );
    insert into public.fulfillment_records (
      organization_id, venue_id, line_id, hold_id, quantity, fulfilled_by
    ) values (
      v_campaign.organization_id, v_campaign.venue_id, p_line_id, v_hold.id, v_take, v_uid
    )
    returning id into v_record;
    update public.allocation_holds
    set quantity_fulfilled = quantity_fulfilled + v_take
    where id = v_hold.id;
    v_left := v_left - v_take;
  end loop;
  if v_left <> 0 then
    raise exception 'insufficient_reserved' using errcode = '22023';
  end if;
  update public.allocation_lines
  set quantity_fulfilled = quantity_fulfilled + v_qty
  where id = p_line_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_campaign.organization_id, v_campaign.venue_id, v_uid, 'allocation.fulfilled', 'allocation_line', p_line_id,
    jsonb_build_object('quantity', v_qty)
  );
  return v_record;
end;
$$;

create or replace function public.allocation_readiness(p_campaign_id uuid)
returns table (
  line_id uuid,
  member_name text,
  sku text,
  label text,
  quantity_required numeric,
  quantity_reserved numeric,
  quantity_fulfilled numeric,
  house_available numeric,
  shortage numeric,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_campaign public.allocation_campaigns%rowtype;
begin
  select * into v_campaign from public.allocation_campaigns where id = p_campaign_id;
  if v_campaign.id is null then
    raise exception 'campaign_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_campaign.organization_id, v_campaign.venue_id, 'wine.allocation.manage')
     and not public.has_scoped_permission(v_campaign.organization_id, v_campaign.venue_id, 'wine.catalog.read') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  with ordered as (
    select
      l.id,
      m.display_name,
      i.sku,
      nullif(pg_catalog.btrim(coalesce(w.producer, '') || ' ' || coalesce(w.cuvee, '')), '') as wine_label,
      l.quantity_required,
      l.quantity_reserved,
      l.quantity_fulfilled,
      l.item_id,
      row_number() over (partition by l.item_id order by l.id) as item_row
    from public.allocation_lines l
    join public.wine_club_members m on m.id = l.member_id
    join public.inventory_items i on i.id = l.item_id
    left join public.wine_profiles w on w.item_id = l.item_id
    where l.campaign_id = p_campaign_id
  ),
  house as (
    select b.item_id, coalesce(sum(b.quantity), 0) as available
    from public.inventory_balances b
    where b.venue_id = v_campaign.venue_id
      and b.ownership_class = 'house'
      and b.slot_id is not null
    group by b.item_id
  ),
  claimed as (
    select
      o.id,
      coalesce(sum(o.quantity_required - o.quantity_reserved) over (
        partition by o.item_id
        order by o.id
        rows between unbounded preceding and 1 preceding
      ), 0) as prior_need
    from ordered o
  )
  select
    o.id,
    o.display_name,
    o.sku,
    o.wine_label,
    o.quantity_required,
    o.quantity_reserved,
    o.quantity_fulfilled,
    coalesce(h.available, 0),
    case
      when v_campaign.status = 'draft' then greatest(
        o.quantity_required - o.quantity_reserved - greatest(coalesce(h.available, 0) - c.prior_need, 0),
        0
      )
      else greatest(o.quantity_required - o.quantity_reserved, 0)
    end,
    v_campaign.status
  from ordered o
  join claimed c on c.id = o.id
  left join house h on h.item_id = o.item_id
  order by o.display_name, o.sku;
end;
$$;

create or replace function public.list_allocation_campaigns(p_venue_id uuid)
returns table (
  id uuid,
  name text,
  release_on date,
  status text,
  line_count integer
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
  if not public.has_scoped_permission(v_org, p_venue_id, 'wine.allocation.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  select c.id, c.name, c.release_on, c.status, count(l.id)::integer
  from public.allocation_campaigns c
  left join public.allocation_lines l on l.campaign_id = c.id
  where c.venue_id = p_venue_id
  group by c.id
  order by c.release_on, c.created_at;
end;
$$;

alter table public.wine_club_members enable row level security;
alter table public.allocation_campaigns enable row level security;
alter table public.allocation_lines enable row level security;
alter table public.allocation_holds enable row level security;
alter table public.fulfillment_records enable row level security;

create policy wine_club_members_select on public.wine_club_members
for select to authenticated
using (public.has_permission(organization_id, 'wine.allocation.manage'));

create policy allocation_campaigns_select on public.allocation_campaigns
for select to authenticated
using (public.has_permission(organization_id, 'wine.allocation.manage'));

create policy allocation_lines_select on public.allocation_lines
for select to authenticated
using (public.has_permission(organization_id, 'wine.allocation.manage'));

create policy allocation_holds_select on public.allocation_holds
for select to authenticated
using (public.has_permission(organization_id, 'wine.allocation.manage'));

create policy fulfillment_records_select on public.fulfillment_records
for select to authenticated
using (public.has_permission(organization_id, 'wine.allocation.manage'));

revoke all on table public.wine_club_members from public, anon, authenticated;
revoke all on table public.allocation_campaigns from public, anon, authenticated;
revoke all on table public.allocation_lines from public, anon, authenticated;
revoke all on table public.allocation_holds from public, anon, authenticated;
revoke all on table public.fulfillment_records from public, anon, authenticated;

grant select (id, organization_id, display_name, tier, active) on public.wine_club_members to authenticated;
grant select (id, organization_id, venue_id, name, release_on, status) on public.allocation_campaigns to authenticated;
grant select (id, campaign_id, organization_id, member_id, item_id, quantity_required, quantity_reserved, quantity_fulfilled)
  on public.allocation_lines to authenticated;
grant select (id, organization_id, line_id, lot_id, slot_id, quantity_reserved, quantity_fulfilled)
  on public.allocation_holds to authenticated;
grant select (id, organization_id, venue_id, line_id, quantity, created_at)
  on public.fulfillment_records to authenticated;

revoke all on function public.create_club_member(uuid, text, text) from public, anon;
revoke all on function public.create_allocation_campaign(uuid, uuid, text, date) from public, anon;
revoke all on function public.add_allocation_line(uuid, uuid, uuid, text) from public, anon;
revoke all on function public.reserve_allocation(uuid) from public, anon;
revoke all on function public.fulfill_allocation_pickup(uuid, text) from public, anon;
revoke all on function public.allocation_readiness(uuid) from public, anon;
revoke all on function public.list_allocation_campaigns(uuid) from public, anon;

grant execute on function public.create_club_member(uuid, text, text) to authenticated;
grant execute on function public.create_allocation_campaign(uuid, uuid, text, date) to authenticated;
grant execute on function public.add_allocation_line(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.reserve_allocation(uuid) to authenticated;
grant execute on function public.fulfill_allocation_pickup(uuid, text) to authenticated;
grant execute on function public.allocation_readiness(uuid) to authenticated;
grant execute on function public.list_allocation_campaigns(uuid) to authenticated;
