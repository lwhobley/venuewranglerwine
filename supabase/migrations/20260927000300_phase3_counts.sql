-- Phase 3: counts freeze expected quantity. Approval writes a movement.
-- It does not overwrite the count line or the movement history.

alter table public.inventory_movements
  drop constraint inventory_movements_reason_check;

alter table public.inventory_movements
  add constraint inventory_movements_reason_check
  check (reason in ('receive', 'put_away', 'privileged_adjustment', 'count_adjustment'));

create table public.inventory_count_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  location_id uuid references public.storage_locations (id),
  kind text not null,
  mode text not null,
  status text not null default 'in_progress',
  frozen_at timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint inventory_count_sessions_kind_check check (
    kind in ('full', 'partial', 'cycle', 'spot', 'opening', 'closing', 'event_prep', 'audit')
  ),
  constraint inventory_count_sessions_mode_check check (mode in ('blind', 'expected')),
  constraint inventory_count_sessions_status_check check (
    status in ('in_progress', 'submitted', 'approved', 'rejected')
  )
);

create table public.inventory_count_lines (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.inventory_count_sessions (id),
  organization_id uuid not null references public.organizations (id),
  slot_id uuid not null references public.storage_slots (id),
  item_id uuid references public.inventory_items (id),
  lot_id uuid references public.inventory_lots (id),
  expected_quantity numeric(14, 3) not null,
  counted_quantity numeric(14, 3),
  reason text,
  counted_by uuid references public.profiles (id),
  counted_at timestamptz,
  client_entry_id text unique,
  other_counted_quantity numeric(14, 3),
  other_counted_by uuid references public.profiles (id),
  constraint inventory_count_lines_expected_check check (expected_quantity >= 0),
  constraint inventory_count_lines_counted_check check (counted_quantity is null or counted_quantity >= 0)
);

create unique index inventory_count_lines_position
  on public.inventory_count_lines (
    session_id,
    slot_id,
    (coalesce(item_id, '00000000-0000-0000-0000-000000000000'::uuid))
  );

create index inventory_count_sessions_venue_idx
  on public.inventory_count_sessions (organization_id, venue_id, created_at desc);

create or replace function public.parse_count_quantity(p_quantity text)
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
  if v_qty is null or v_qty < 0 or v_qty <> trunc(v_qty) then
    raise exception 'invalid_quantity' using errcode = '22023';
  end if;
  return v_qty;
end;
$$;

create or replace function public.start_count_session(
  p_organization_id uuid,
  p_venue_id uuid,
  p_kind text,
  p_mode text,
  p_location_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'wine.count.execute');
  if p_kind not in ('full', 'partial', 'cycle', 'spot', 'opening', 'closing', 'event_prep', 'audit') then
    raise exception 'invalid_count_kind' using errcode = '22023';
  end if;
  if p_mode not in ('blind', 'expected') then
    raise exception 'invalid_count_mode' using errcode = '22023';
  end if;
  if p_location_id is not null and not exists (
    select 1 from public.storage_locations
    where id = p_location_id and venue_id = p_venue_id and kind = 'room' and deleted_at is null
  ) then
    raise exception 'room_not_found' using errcode = '22023';
  end if;

  insert into public.inventory_count_sessions (
    organization_id, venue_id, location_id, kind, mode, created_by
  ) values (
    p_organization_id, p_venue_id, p_location_id, p_kind, p_mode, v_uid
  )
  returning id into v_id;

  insert into public.inventory_count_lines (
    session_id, organization_id, slot_id, item_id, lot_id, expected_quantity
  )
  select
    v_id,
    p_organization_id,
    b.slot_id,
    b.item_id,
    b.lot_id,
    b.quantity
  from public.inventory_balances b
  join public.storage_slots s on s.id = b.slot_id
  join public.storage_units u on u.id = s.unit_id
  where b.venue_id = p_venue_id
    and b.organization_id = p_organization_id
    and b.ownership_class = 'house'
    and b.slot_id is not null
    and b.quantity > 0
    and (p_location_id is null or u.location_id = p_location_id);

  insert into public.inventory_count_lines (
    session_id, organization_id, slot_id, expected_quantity
  )
  select v_id, p_organization_id, s.id, 0
  from public.storage_slots s
  join public.storage_units u on u.id = s.unit_id
  where s.venue_id = p_venue_id
    and (p_location_id is null or u.location_id = p_location_id)
    and not exists (
      select 1 from public.inventory_count_lines line
      where line.session_id = v_id and line.slot_id = s.id
    );

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id, p_venue_id, v_uid, 'count.started', 'inventory_count_session', v_id,
    jsonb_build_object('kind', p_kind, 'mode', p_mode)
  );
  return v_id;
end;
$$;

create or replace function public.record_count_entry(
  p_session_id uuid,
  p_client_entry_id text,
  p_location_code text,
  p_sku text,
  p_quantity text,
  p_reason text
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
  if (
    select count(*) from public.inventory_count_lines
    where session_id = p_session_id and slot_id = v_slot.id and item_id = v_item
  ) > 1 then
    raise exception 'lot_required' using errcode = '22023';
  end if;
elsif v_qty <> 0 then
  raise exception 'invalid_sku' using errcode = '22023';
end if;

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
  if v_line.id is null and v_item is not null then
    select * into v_line
    from public.inventory_count_lines
    where session_id = p_session_id and slot_id = v_slot.id and item_id is null
    limit 1;
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
      session_id, organization_id, slot_id, item_id, expected_quantity,
      counted_quantity, reason, counted_by, counted_at, client_entry_id
    ) values (
      p_session_id, v_session.organization_id, v_slot.id, v_item, 0,
      v_qty, nullif(pg_catalog.btrim(p_reason), ''), v_uid, pg_catalog.now(), p_client_entry_id
    )
    returning id into v_line.id;
  else
    update public.inventory_count_lines
    set item_id = coalesce(v_item, item_id),
        counted_quantity = v_qty,
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

create or replace function public.submit_count_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.inventory_count_sessions%rowtype;
begin
  select * into v_session from public.inventory_count_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.execute');
  if v_session.status <> 'in_progress' then
    raise exception 'session_not_open' using errcode = '22023';
  end if;
  update public.inventory_count_sessions
  set status = 'submitted', submitted_at = pg_catalog.now()
  where id = p_session_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (v_session.organization_id, v_session.venue_id, auth.uid(), 'count.submitted', 'inventory_count_session', p_session_id);
end;
$$;

create or replace function public.resolve_count_conflict(
  p_line_id uuid,
  p_quantity text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line public.inventory_count_lines%rowtype;
  v_session public.inventory_count_sessions%rowtype;
  v_qty numeric(14, 3);
begin
  v_qty := public.parse_count_quantity(p_quantity);
  select * into v_line from public.inventory_count_lines where id = p_line_id;
  if v_line.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  select * into v_session from public.inventory_count_sessions where id = v_line.session_id;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.review');
  if v_session.status <> 'submitted' then
    raise exception 'session_not_submitted' using errcode = '22023';
  end if;
  update public.inventory_count_lines
  set counted_quantity = v_qty,
      other_counted_quantity = null,
      other_counted_by = null
  where id = p_line_id;
end;
$$;

create or replace function public.approve_count_session(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.inventory_count_sessions%rowtype;
  v_line public.inventory_count_lines%rowtype;
  v_delta numeric(14, 3);
  v_current numeric(14, 3);
  v_balance uuid;
  v_written integer := 0;
begin
  select * into v_session from public.inventory_count_sessions where id = p_session_id for update;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.approve');
  if v_session.status <> 'submitted' then
    raise exception 'session_not_submitted' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.inventory_count_lines
    where session_id = p_session_id and other_counted_quantity is not null
  ) then
    raise exception 'count_conflict' using errcode = '22023';
  end if;

  for v_line in
    select * from public.inventory_count_lines
    where session_id = p_session_id and counted_quantity is not null
    for update
  loop
    if v_line.counted_quantity = v_line.expected_quantity then
      continue;
    end if;
    if v_line.lot_id is null and v_line.counted_quantity > 0 then
      raise exception 'count_needs_lot' using errcode = '22023';
    end if;
    v_delta := v_line.counted_quantity - v_line.expected_quantity;
    if v_delta = 0 or v_line.lot_id is null then
      continue;
    end if;

    select id, quantity into v_balance, v_current
    from public.inventory_balances
    where lot_id = v_line.lot_id and slot_id = v_line.slot_id and ownership_class = 'house'
    for update;
    v_current := coalesce(v_current, 0);
    if v_current + v_delta < 0 then
      raise exception 'adjustment_would_go_negative' using errcode = '22023';
    end if;
    if v_balance is null then
      insert into public.inventory_balances (
        organization_id, venue_id, item_id, lot_id, slot_id, location_id, ownership_class, quantity
      ) values (
        v_session.organization_id, v_session.venue_id, v_line.item_id, v_line.lot_id, v_line.slot_id,
        (select u.location_id from public.storage_slots s join public.storage_units u on u.id = s.unit_id where s.id = v_line.slot_id),
        'house', v_current + v_delta
      );
    else
      update public.inventory_balances
      set quantity = quantity + v_delta
      where id = v_balance;
    end if;
    update public.inventory_lots
    set quantity_on_hand = quantity_on_hand + v_delta
    where id = v_line.lot_id;

    insert into public.inventory_movements (
      organization_id, venue_id, item_id, lot_id, destination_slot_id, quantity,
      source_quantity_before, source_quantity_after, destination_quantity_before, destination_quantity_after,
      reason, actor_id
    ) values (
      v_session.organization_id, v_session.venue_id, v_line.item_id, v_line.lot_id, v_line.slot_id,
      abs(v_delta),
      v_current, v_current + v_delta, v_current, v_current + v_delta,
      'count_adjustment', v_uid
    );
    v_written := v_written + 1;
  end loop;

  update public.inventory_count_sessions
  set status = 'approved', reviewed_by = v_uid, reviewed_at = pg_catalog.now()
  where id = p_session_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_session.organization_id, v_session.venue_id, v_uid, 'count.approved', 'inventory_count_session', p_session_id,
    jsonb_build_object('adjustments', v_written)
  );
  return v_written;
end;
$$;

create or replace function public.reject_count_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.inventory_count_sessions%rowtype;
begin
  select * into v_session from public.inventory_count_sessions where id = p_session_id;
  if v_session.id is null then
    raise exception 'session_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_session.organization_id, v_session.venue_id, 'wine.count.review');
  if v_session.status <> 'submitted' then
    raise exception 'session_not_submitted' using errcode = '22023';
  end if;
  update public.inventory_count_sessions
  set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = pg_catalog.now()
  where id = p_session_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (v_session.organization_id, v_session.venue_id, auth.uid(), 'count.rejected', 'inventory_count_session', p_session_id);
end;
$$;

create or replace function public.list_count_sessions(p_venue_id uuid)
returns table (
  id uuid,
  kind text,
  mode text,
  status text,
  created_at timestamptz,
  counted_lines integer,
  open_lines integer
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
  if not public.has_scoped_permission(v_org, p_venue_id, 'wine.count.execute')
     and not public.has_scoped_permission(v_org, p_venue_id, 'wine.count.review')
     and not public.has_scoped_permission(v_org, p_venue_id, 'wine.count.approve') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return query
  select
    s.id,
    s.kind,
    s.mode,
    s.status,
    s.created_at,
    count(l.id) filter (where l.counted_quantity is not null)::integer,
    count(l.id) filter (where l.counted_quantity is null)::integer
  from public.inventory_count_sessions s
  left join public.inventory_count_lines l on l.session_id = s.id
  where s.venue_id = p_venue_id
  group by s.id
  order by s.created_at desc;
end;
$$;

create or replace function public.count_sheet(p_session_id uuid)
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
  status text
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
    v_session.status
  from public.inventory_count_lines l
  join public.storage_slots s on s.id = l.slot_id
  left join public.inventory_items i on i.id = l.item_id
  left join public.wine_profiles w on w.item_id = l.item_id
  where l.session_id = p_session_id
  order by s.location_code, i.sku nulls last;
end;
$$;

alter table public.inventory_count_sessions enable row level security;
alter table public.inventory_count_lines enable row level security;

create policy count_sessions_select on public.inventory_count_sessions
for select to authenticated
using (
  public.has_permission(organization_id, 'wine.count.execute')
  or public.has_permission(organization_id, 'wine.count.review')
  or public.has_permission(organization_id, 'wine.count.approve')
);

revoke all on table public.inventory_count_sessions from public, anon, authenticated;
revoke all on table public.inventory_count_lines from public, anon, authenticated;
grant select (id, organization_id, venue_id, location_id, kind, mode, status, frozen_at, submitted_at, reviewed_at, created_at)
  on public.inventory_count_sessions to authenticated;

revoke all on function public.parse_count_quantity(text) from public, anon, authenticated;
revoke all on function public.start_count_session(uuid, uuid, text, text, uuid) from public, anon;
revoke all on function public.record_count_entry(uuid, text, text, text, text, text) from public, anon;
revoke all on function public.submit_count_session(uuid) from public, anon;
revoke all on function public.resolve_count_conflict(uuid, text) from public, anon;
revoke all on function public.approve_count_session(uuid) from public, anon;
revoke all on function public.reject_count_session(uuid) from public, anon;
revoke all on function public.list_count_sessions(uuid) from public, anon;
revoke all on function public.count_sheet(uuid) from public, anon;

grant execute on function public.start_count_session(uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.record_count_entry(uuid, text, text, text, text, text) to authenticated;
grant execute on function public.submit_count_session(uuid) to authenticated;
grant execute on function public.resolve_count_conflict(uuid, text) to authenticated;
grant execute on function public.approve_count_session(uuid) to authenticated;
grant execute on function public.reject_count_session(uuid) to authenticated;
grant execute on function public.list_count_sessions(uuid) to authenticated;
grant execute on function public.count_sheet(uuid) to authenticated;
