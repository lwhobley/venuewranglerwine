-- POS gateway. Connected is set only after a server handshake.
-- Secrets are not readable by the app.

create table public.integration_secrets (
  connection_id uuid primary key references public.integration_connections (id) on delete cascade,
  access_token text,
  client_id text,
  client_secret text,
  merchant_id text,
  shop_domain text,
  restaurant_guid text,
  webhook_url text,
  webhook_secret text,
  sandbox boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.integration_sync_runs (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.integration_connections (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  direction text not null,
  status text not null,
  detail text,
  created_at timestamptz not null default now(),
  constraint integration_sync_runs_direction_check check (direction in ('ingest', 'push')),
  constraint integration_sync_runs_status_check check (status in ('ok', 'failed'))
);

create table public.integration_item_maps (
  connection_id uuid not null references public.integration_connections (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  local_sku text not null,
  external_sku text not null,
  primary key (connection_id, local_sku)
);

create table public.pos_checks (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.integration_connections (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  external_id text not null,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint pos_checks_external_unique unique (connection_id, external_id)
);

create table public.pos_check_lines (
  id uuid primary key default gen_random_uuid(),
  check_id uuid not null references public.pos_checks (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  sku text not null,
  name text not null,
  quantity numeric(14, 3) not null,
  constraint pos_check_lines_qty_check check (quantity > 0)
);

alter table public.integration_secrets enable row level security;
alter table public.integration_sync_runs enable row level security;
alter table public.integration_item_maps enable row level security;
alter table public.pos_checks enable row level security;
alter table public.pos_check_lines enable row level security;

create policy integration_sync_runs_select on public.integration_sync_runs
for select to authenticated
using (public.has_permission(organization_id, 'integration.manage'));

create policy integration_item_maps_select on public.integration_item_maps
for select to authenticated
using (public.has_permission(organization_id, 'integration.manage'));

create policy pos_checks_select on public.pos_checks
for select to authenticated
using (public.venue_visible(organization_id, venue_id, 'integration.manage'));

create policy pos_check_lines_select on public.pos_check_lines
for select to authenticated
using (
  exists (
    select 1 from public.pos_checks c
    where c.id = pos_check_lines.check_id
      and public.venue_visible(c.organization_id, c.venue_id, 'integration.manage')
  )
);

revoke all on table public.integration_secrets from public, anon, authenticated;
revoke all on table public.integration_sync_runs from public, anon, authenticated;
revoke all on table public.integration_item_maps from public, anon, authenticated;
revoke all on table public.pos_checks from public, anon, authenticated;
revoke all on table public.pos_check_lines from public, anon, authenticated;

grant select (id, connection_id, organization_id, direction, status, detail, created_at)
  on public.integration_sync_runs to authenticated;
grant select (connection_id, organization_id, local_sku, external_sku)
  on public.integration_item_maps to authenticated;
grant select (id, connection_id, organization_id, venue_id, external_id, occurred_at)
  on public.pos_checks to authenticated;
grant select (id, check_id, organization_id, sku, name, quantity)
  on public.pos_check_lines to authenticated;

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
  if p_status = 'connected' then
    raise exception 'handshake_required' using errcode = '42501';
  end if;
  if p_provider_key !~ '^[a-z0-9_]{2,40}$' or p_status <> 'disconnected' then
    raise exception 'invalid_provider' using errcode = '22023';
  end if;
  insert into public.integration_connections (organization_id, provider_key, status, credential_ref)
  values (p_organization_id, p_provider_key, 'disconnected', null)
  on conflict (organization_id, provider_key)
  do update set status = 'disconnected', credential_ref = null;
end;
$$;

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
  v_inserted boolean := false;
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
    return jsonb_build_object('applied', false);
  end if;
  v_inserted := true;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    insert into public.pos_check_lines (check_id, organization_id, sku, name, quantity)
    values (
      v_check,
      v_conn.organization_id,
      pg_catalog.upper(v_line ->> 'sku'),
      coalesce(v_line ->> 'name', v_line ->> 'sku'),
      (v_line ->> 'quantity')::numeric
    );
  end loop;
  return jsonb_build_object('applied', v_inserted, 'check_id', v_check);
end;
$$;

revoke all on function public.apply_pos_check(uuid, uuid, text, timestamptz, jsonb) from public, anon, authenticated;
grant execute on function public.apply_pos_check(uuid, uuid, text, timestamptz, jsonb) to service_role;
grant select, update on public.integration_connections to service_role;
grant all on table public.integration_secrets to service_role;
grant all on table public.integration_sync_runs to service_role;
grant all on table public.integration_item_maps to service_role;
grant all on table public.pos_checks to service_role;
grant all on table public.pos_check_lines to service_role;

update public.integration_connections
set status = 'disconnected', credential_ref = null
where provider_key = 'pos_generic' and credential_ref is null and status = 'connected';
