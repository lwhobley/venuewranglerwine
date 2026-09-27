-- Launch blockers: venue-scoped reads, no client plan writes, lot-level counts,
-- per-member holdings, independent count approval, and open-bottle lot totals.

create or replace function public.venue_visible(p_org uuid, p_venue uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_scoped_permission(p_org, p_venue, p_permission);
$$;

-- Venue-scoped selects. Organization-wide membership still sees every venue.
drop policy if exists venues_select on public.venues;
create policy venues_select on public.venues
for select to authenticated
using (
  deleted_at is null
  and public.venue_visible(organization_id, id, 'venue.read')
);

drop policy if exists storage_locations_select on public.storage_locations;
create policy storage_locations_select on public.storage_locations
for select to authenticated
using (deleted_at is null and public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists cellar_versions_select on public.cellar_map_versions;
create policy cellar_versions_select on public.cellar_map_versions
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists storage_units_select on public.storage_units;
create policy storage_units_select on public.storage_units
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists storage_slots_select on public.storage_slots;
create policy storage_slots_select on public.storage_slots
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists inventory_lots_select on public.inventory_lots;
create policy inventory_lots_select on public.inventory_lots
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists purchase_orders_select on public.purchase_orders;
create policy purchase_orders_select on public.purchase_orders
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.receive'));

drop policy if exists receipts_select on public.receipts;
create policy receipts_select on public.receipts
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.receive'));

drop policy if exists inventory_movements_select on public.inventory_movements;
create policy inventory_movements_select on public.inventory_movements
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists inventory_balances_select on public.inventory_balances;
create policy inventory_balances_select on public.inventory_balances
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists count_sessions_select on public.inventory_count_sessions;
create policy count_sessions_select on public.inventory_count_sessions
for select to authenticated
using (
  public.venue_visible(organization_id, venue_id, 'wine.count.execute')
  or public.venue_visible(organization_id, venue_id, 'wine.count.review')
  or public.venue_visible(organization_id, venue_id, 'wine.count.approve')
);

drop policy if exists guests_select on public.guests;
create policy guests_select on public.guests
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'guest.read'));

drop policy if exists floor_tables_select on public.floor_tables;
create policy floor_tables_select on public.floor_tables
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'floor.read'));

drop policy if exists reservations_select on public.reservations;
create policy reservations_select on public.reservations
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'reservation.read'));

drop policy if exists shifts_select on public.shifts;
create policy shifts_select on public.shifts
for select to authenticated
using (
  public.venue_visible(organization_id, venue_id, 'schedule.read')
  or public.venue_visible(organization_id, venue_id, 'schedule.publish')
);

drop policy if exists time_entries_select on public.time_entries;
create policy time_entries_select on public.time_entries
for select to authenticated
using (
  public.venue_visible(organization_id, venue_id, 'timeclock.manage')
  or (user_id = (select auth.uid()) and public.venue_visible(organization_id, venue_id, 'timeclock.self'))
);

drop policy if exists checklist_templates_select on public.checklist_templates;
create policy checklist_templates_select on public.checklist_templates
for select to authenticated
using (
  public.venue_visible(organization_id, venue_id, 'checklist.execute')
  or public.venue_visible(organization_id, venue_id, 'checklist.manage')
);

drop policy if exists checklist_runs_select on public.checklist_runs;
create policy checklist_runs_select on public.checklist_runs
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'checklist.execute'));

drop policy if exists logbook_select on public.logbook_entries;
create policy logbook_select on public.logbook_entries
for select to authenticated
using (
  public.venue_visible(organization_id, venue_id, 'logbook.write')
  or public.venue_visible(organization_id, venue_id, 'schedule.read')
);

drop policy if exists documents_select on public.documents;
create policy documents_select on public.documents
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'document.read'));

drop policy if exists events_select on public.events;
create policy events_select on public.events
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'event.read'));

drop policy if exists channels_select on public.channels;
create policy channels_select on public.channels
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'chat.write'));

drop policy if exists wine_lists_select on public.wine_lists;
create policy wine_lists_select on public.wine_lists
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists open_bottles_select on public.open_bottles;
create policy open_bottles_select on public.open_bottles
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists service_depletions_select on public.service_depletions;
create policy service_depletions_select on public.service_depletions
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.catalog.read'));

drop policy if exists allocation_campaigns_select on public.allocation_campaigns;
create policy allocation_campaigns_select on public.allocation_campaigns
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.allocation.manage'));

drop policy if exists fulfillment_records_select on public.fulfillment_records;
create policy fulfillment_records_select on public.fulfillment_records
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.allocation.manage'));

drop policy if exists invites_select on public.invites;
create policy invites_select on public.invites
for select to authenticated
using (
  (venue_id is null and public.venue_visible(organization_id, null, 'membership.read'))
  or (venue_id is not null and public.venue_visible(organization_id, venue_id, 'membership.read'))
);

drop policy if exists audit_select on public.audit_events;
create policy audit_select on public.audit_events
for select to authenticated
using (
  organization_id is not null
  and public.venue_visible(organization_id, venue_id, 'audit.read')
);

create or replace function public.child_venue_visible(p_org uuid, p_venue uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.venue_visible(p_org, p_venue, p_permission);
$$;

drop policy if exists purchase_order_lines_select on public.purchase_order_lines;
create policy purchase_order_lines_select on public.purchase_order_lines
for select to authenticated
using (
  exists (
    select 1 from public.purchase_orders po
    where po.id = purchase_order_lines.purchase_order_id
      and public.child_venue_visible(po.organization_id, po.venue_id, 'wine.receive')
  )
);

drop policy if exists receipt_lines_select on public.receipt_lines;
create policy receipt_lines_select on public.receipt_lines
for select to authenticated
using (
  exists (
    select 1 from public.receipts r
    where r.id = receipt_lines.receipt_id
      and public.child_venue_visible(r.organization_id, r.venue_id, 'wine.receive')
  )
);

drop policy if exists checklist_items_select on public.checklist_items;
create policy checklist_items_select on public.checklist_items
for select to authenticated
using (
  exists (
    select 1 from public.checklist_templates t
    where t.id = checklist_items.template_id
      and (
        public.child_venue_visible(t.organization_id, t.venue_id, 'checklist.execute')
        or public.child_venue_visible(t.organization_id, t.venue_id, 'checklist.manage')
      )
  )
);

drop policy if exists checklist_completions_select on public.checklist_completions;
create policy checklist_completions_select on public.checklist_completions
for select to authenticated
using (
  exists (
    select 1 from public.checklist_runs r
    where r.id = checklist_completions.run_id
      and public.child_venue_visible(r.organization_id, r.venue_id, 'checklist.execute')
  )
);

drop policy if exists beo_select on public.beo_versions;
create policy beo_select on public.beo_versions
for select to authenticated
using (
  exists (
    select 1 from public.events e
    where e.id = beo_versions.event_id
      and public.child_venue_visible(e.organization_id, e.venue_id, 'event.read')
  )
);

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
for select to authenticated
using (
  exists (
    select 1 from public.channels c
    where c.id = messages.channel_id
      and public.child_venue_visible(c.organization_id, c.venue_id, 'chat.write')
  )
);

drop policy if exists wine_list_items_select on public.wine_list_items;
create policy wine_list_items_select on public.wine_list_items
for select to authenticated
using (
  exists (
    select 1 from public.wine_lists l
    where l.id = wine_list_items.list_id
      and public.child_venue_visible(l.organization_id, l.venue_id, 'wine.catalog.read')
  )
);

drop policy if exists allocation_lines_select on public.allocation_lines;
create policy allocation_lines_select on public.allocation_lines
for select to authenticated
using (
  exists (
    select 1 from public.allocation_campaigns c
    where c.id = allocation_lines.campaign_id
      and public.child_venue_visible(c.organization_id, c.venue_id, 'wine.allocation.manage')
  )
);

drop policy if exists allocation_holds_select on public.allocation_holds;
create policy allocation_holds_select on public.allocation_holds
for select to authenticated
using (
  exists (
    select 1
    from public.allocation_lines l
    join public.allocation_campaigns c on c.id = l.campaign_id
    where l.id = allocation_holds.line_id
      and public.child_venue_visible(c.organization_id, c.venue_id, 'wine.allocation.manage')
  )
);

revoke all on function public.set_plan(uuid, text, text) from public, anon, authenticated;

drop index if exists public.inventory_count_lines_position;
create unique index inventory_count_lines_position
  on public.inventory_count_lines (
    session_id,
    slot_id,
    (coalesce(item_id, '00000000-0000-0000-0000-000000000000'::uuid)),
    (coalesce(lot_id, '00000000-0000-0000-0000-000000000000'::uuid))
  );

create table public.inventory_count_revisions (
  id uuid primary key default gen_random_uuid(),
  line_id uuid not null references public.inventory_count_lines (id),
  previous_quantity numeric(14, 3),
  new_quantity numeric(14, 3),
  actor_id uuid,
  created_at timestamptz not null default now()
);

alter table public.inventory_count_revisions enable row level security;
revoke all on table public.inventory_count_revisions from public, anon, authenticated;

create table public.member_holdings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  member_id uuid not null references public.wine_club_members (id),
  lot_id uuid not null references public.inventory_lots (id),
  slot_id uuid not null references public.storage_slots (id),
  quantity numeric(14, 3) not null,
  constraint member_holdings_qty_check check (quantity >= 0),
  constraint member_holdings_unique unique (member_id, lot_id, slot_id)
);

alter table public.member_holdings enable row level security;
create policy member_holdings_select on public.member_holdings
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'wine.allocation.manage'));
revoke all on table public.member_holdings from public, anon, authenticated;
grant select (id, organization_id, venue_id, member_id, lot_id, slot_id, quantity)
  on public.member_holdings to authenticated;

create or replace function public.keep_count_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.counted_quantity is not null and old.counted_quantity is distinct from new.counted_quantity then
    insert into public.inventory_count_revisions (line_id, previous_quantity, new_quantity, actor_id)
    values (old.id, old.counted_quantity, new.counted_quantity, auth.uid());
  end if;
  return new;
end;
$$;

create trigger inventory_count_lines_revision
before update on public.inventory_count_lines
for each row execute function public.keep_count_revision();

create or replace function public.enforce_count_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_location uuid;
  v_venue uuid;
  v_room uuid;
begin
  select location_id, venue_id into v_location, v_venue
  from public.inventory_count_sessions where id = new.session_id;
  if not exists (
    select 1 from public.storage_slots where id = new.slot_id and venue_id = v_venue
  ) then
    raise exception 'slot_not_found' using errcode = '22023';
  end if;
  if v_location is not null then
    select u.location_id into v_room
    from public.storage_slots s
    join public.storage_units u on u.id = s.unit_id
    where s.id = new.slot_id;
    if v_room is distinct from v_location then
      raise exception 'count_out_of_scope' using errcode = '22023';
    end if;
  end if;
  return new;
end;
$$;

create trigger inventory_count_lines_scope
before insert or update on public.inventory_count_lines
for each row execute function public.enforce_count_scope();

create or replace function public.reject_self_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'approved' and (
    new.reviewed_by = new.created_by
    or exists (
      select 1 from public.inventory_count_lines
      where session_id = new.id and counted_by = new.reviewed_by
    )
  ) then
    raise exception 'self_approval_denied' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger inventory_count_sessions_self_approval
before update on public.inventory_count_sessions
for each row execute function public.reject_self_approval();

create or replace function public.record_member_holding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member uuid;
  v_lot uuid;
  v_slot uuid;
begin
  select l.member_id, h.lot_id, h.slot_id
  into v_member, v_lot, v_slot
  from public.allocation_lines l
  join public.allocation_holds h on h.id = new.hold_id
  where l.id = new.line_id and h.line_id = l.id;
  insert into public.member_holdings (
    organization_id, venue_id, member_id, lot_id, slot_id, quantity
  ) values (
    new.organization_id, new.venue_id, v_member, v_lot, v_slot, new.quantity
  )
  on conflict (member_id, lot_id, slot_id)
  do update set quantity = public.member_holdings.quantity + excluded.quantity;
  return new;
end;
$$;

create trigger fulfillment_member_holding
after insert on public.fulfillment_records
for each row execute function public.record_member_holding();
