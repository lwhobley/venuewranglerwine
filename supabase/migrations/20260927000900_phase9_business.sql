-- Phase 9: events and versioned BEOs, chat, report export, provider-neutral connections, plan entitlements.
-- No vendor API is called. A connection is a record. A report is refused without an active entitlement.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  name text not null,
  stage text not null default 'inquiry',
  guest_count integer not null,
  starts_at timestamptz not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint events_name_len check (char_length(name) between 2 and 80),
  constraint events_stage_check check (stage in ('inquiry', 'hold', 'booked', 'live', 'closed')),
  constraint events_guests_check check (guest_count between 1 and 500)
);

create table public.beo_versions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id),
  organization_id uuid not null references public.organizations (id),
  version_number integer not null,
  body text not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint beo_versions_unique unique (event_id, version_number),
  constraint beo_versions_body_len check (char_length(body) between 1 and 4000)
);

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  name text not null,
  constraint channels_name_unique unique (venue_id, name)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels (id),
  organization_id uuid not null references public.organizations (id),
  body text not null,
  author_id uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint messages_body_len check (char_length(body) between 1 and 2000)
);

create table public.integration_connections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  provider_key text not null,
  status text not null default 'disconnected',
  credential_ref text,
  constraint integration_connections_unique unique (organization_id, provider_key),
  constraint integration_connections_status_check check (status in ('disconnected', 'connected')),
  constraint integration_connections_provider_check check (provider_key ~ '^[a-z0-9_]{2,40}$')
);

create table public.subscription_accounts (
  organization_id uuid primary key references public.organizations (id),
  plan_key text not null,
  status text not null,
  constraint subscription_accounts_status_check check (status in ('trial', 'active', 'expired'))
);

create table public.plan_entitlements (
  plan_key text not null,
  feature_key text not null,
  primary key (plan_key, feature_key)
);

insert into public.plan_entitlements (plan_key, feature_key) values
  ('trial', 'reports'),
  ('active', 'reports')
on conflict do nothing;

create or replace function public.create_event(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_guest_count integer,
  p_starts_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'event.manage');
  if char_length(pg_catalog.btrim(p_name)) < 2 or p_guest_count < 1 or p_starts_at is null then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  insert into public.events (organization_id, venue_id, name, guest_count, starts_at, created_by)
  values (p_organization_id, p_venue_id, pg_catalog.btrim(p_name), p_guest_count, p_starts_at, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.advance_event(p_event_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_next text;
begin
  select * into v_event from public.events where id = p_event_id for update;
  if v_event.id is null then
    raise exception 'event_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_event.organization_id, v_event.venue_id, 'event.manage');
  v_next := case v_event.stage
    when 'inquiry' then 'hold'
    when 'hold' then 'booked'
    when 'booked' then 'live'
    when 'live' then 'closed'
    else null
  end;
  if v_next is null then
    raise exception 'event_closed' using errcode = '22023';
  end if;
  update public.events set stage = v_next where id = p_event_id;
  return v_next;
end;
$$;

create or replace function public.add_beo(p_event_id uuid, p_body text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_version integer;
begin
  select * into v_event from public.events where id = p_event_id;
  if v_event.id is null then
    raise exception 'event_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_event.organization_id, v_event.venue_id, 'event.manage');
  if char_length(pg_catalog.btrim(p_body)) < 1 then
    raise exception 'invalid_message' using errcode = '22023';
  end if;
  select coalesce(max(version_number), 0) + 1 into v_version
  from public.beo_versions where event_id = p_event_id;
  insert into public.beo_versions (event_id, organization_id, version_number, body, created_by)
  values (p_event_id, v_event.organization_id, v_version, pg_catalog.btrim(p_body), auth.uid());
  return v_version;
end;
$$;

create or replace function public.create_channel(p_venue_id uuid, p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_id uuid;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  perform public.require_venue_permission(v_org, p_venue_id, 'chat.write');
  insert into public.channels (organization_id, venue_id, name)
  values (v_org, p_venue_id, pg_catalog.btrim(p_name))
  returning id into v_id;
  return v_id;
exception
  when unique_violation then
    raise exception 'code_taken' using errcode = '23505';
end;
$$;

create or replace function public.post_message(p_channel_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_channel public.channels%rowtype;
  v_id uuid;
  v_body text := pg_catalog.btrim(p_body);
begin
  select * into v_channel from public.channels where id = p_channel_id;
  if v_channel.id is null then
    raise exception 'channel_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_channel.organization_id, v_channel.venue_id, 'chat.write');
  if v_body is null or char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'invalid_message' using errcode = '22023';
  end if;
  insert into public.messages (channel_id, organization_id, body, author_id)
  values (p_channel_id, v_channel.organization_id, v_body, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.save_integration(
  p_organization_id uuid,
  p_provider_key text,
  p_status text
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
  if not public.has_permission(p_organization_id, 'integration.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if p_provider_key !~ '^[a-z0-9_]{2,40}$' or p_status not in ('disconnected', 'connected') then
    raise exception 'invalid_provider' using errcode = '22023';
  end if;
  insert into public.integration_connections (organization_id, provider_key, status, credential_ref)
  values (p_organization_id, p_provider_key, p_status, null)
  on conflict (organization_id, provider_key)
  do update set status = excluded.status;
end;
$$;

create or replace function public.set_plan(p_organization_id uuid, p_plan_key text, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission(p_organization_id, 'billing.manage') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if p_status not in ('trial', 'active', 'expired') then
    raise exception 'invalid_plan' using errcode = '22023';
  end if;
  insert into public.subscription_accounts (organization_id, plan_key, status)
  values (p_organization_id, p_plan_key, p_status)
  on conflict (organization_id) do update set plan_key = excluded.plan_key, status = excluded.status;
end;
$$;

create or replace function public.operational_report(p_venue_id uuid)
returns table (metric text, value integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_status text;
  v_plan text;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  if v_org is null then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_org, p_venue_id, 'report.operational') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  select status, plan_key into v_status, v_plan
  from public.subscription_accounts where organization_id = v_org;
  if v_status is null or v_status = 'expired' or not exists (
    select 1 from public.plan_entitlements
    where plan_key = v_plan and feature_key = 'reports'
  ) then
    raise exception 'plan_required' using errcode = '42501';
  end if;
  return query
  select 'booked_reservations'::text, count(*)::integer
  from public.reservations where venue_id = p_venue_id and status = 'booked'
  union all
  select 'seated_reservations'::text, count(*)::integer
  from public.reservations where venue_id = p_venue_id and status = 'seated'
  union all
  select 'open_events'::text, count(*)::integer
  from public.events where venue_id = p_venue_id and stage <> 'closed';
end;
$$;

alter table public.events enable row level security;
alter table public.beo_versions enable row level security;
alter table public.channels enable row level security;
alter table public.messages enable row level security;
alter table public.integration_connections enable row level security;
alter table public.subscription_accounts enable row level security;
alter table public.plan_entitlements enable row level security;

create policy events_select on public.events for select to authenticated
using (public.has_permission(organization_id, 'event.read'));
create policy beo_select on public.beo_versions for select to authenticated
using (public.has_permission(organization_id, 'event.read'));
create policy channels_select on public.channels for select to authenticated
using (public.has_permission(organization_id, 'chat.write'));
create policy messages_select on public.messages for select to authenticated
using (public.has_permission(organization_id, 'chat.write'));
create policy integrations_select on public.integration_connections for select to authenticated
using (public.has_permission(organization_id, 'integration.manage'));
create policy subscriptions_select on public.subscription_accounts for select to authenticated
using (public.has_permission(organization_id, 'billing.manage') or public.has_permission(organization_id, 'report.operational'));
create policy entitlements_select on public.plan_entitlements for select to authenticated using (true);

revoke all on table public.events from public, anon, authenticated;
revoke all on table public.beo_versions from public, anon, authenticated;
revoke all on table public.channels from public, anon, authenticated;
revoke all on table public.messages from public, anon, authenticated;
revoke all on table public.integration_connections from public, anon, authenticated;
revoke all on table public.subscription_accounts from public, anon, authenticated;
revoke all on table public.plan_entitlements from public, anon, authenticated;

grant select (id, organization_id, venue_id, name, stage, guest_count, starts_at) on public.events to authenticated;
grant select (id, event_id, organization_id, version_number, body, created_at) on public.beo_versions to authenticated;
grant select (id, organization_id, venue_id, name) on public.channels to authenticated;
grant select (id, channel_id, organization_id, body, author_id, created_at) on public.messages to authenticated;
grant select (id, organization_id, provider_key, status) on public.integration_connections to authenticated;
grant select (organization_id, plan_key, status) on public.subscription_accounts to authenticated;
grant select on public.plan_entitlements to authenticated;

revoke all on function public.create_event(uuid, uuid, text, integer, timestamptz) from public, anon;
revoke all on function public.advance_event(uuid) from public, anon;
revoke all on function public.add_beo(uuid, text) from public, anon;
revoke all on function public.create_channel(uuid, text) from public, anon;
revoke all on function public.post_message(uuid, text) from public, anon;
revoke all on function public.save_integration(uuid, text, text) from public, anon;
revoke all on function public.set_plan(uuid, text, text) from public, anon;
revoke all on function public.operational_report(uuid) from public, anon;
grant execute on function public.create_event(uuid, uuid, text, integer, timestamptz) to authenticated;
grant execute on function public.advance_event(uuid) to authenticated;
grant execute on function public.add_beo(uuid, text) to authenticated;
grant execute on function public.create_channel(uuid, text) to authenticated;
grant execute on function public.post_message(uuid, text) to authenticated;
grant execute on function public.save_integration(uuid, text, text) to authenticated;
grant execute on function public.set_plan(uuid, text, text) to authenticated;
grant execute on function public.operational_report(uuid) to authenticated;
