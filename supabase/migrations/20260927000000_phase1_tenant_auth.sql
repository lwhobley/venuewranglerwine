-- Phase 1: tenant identity, membership, invites, and row level security.
-- Mutations go through security-definer functions so a client cannot grant itself a role.
-- Table owners bypass RLS. API roles do not. Do not FORCE ROW LEVEL SECURITY.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  email text,
  phone text,
  locale text not null default 'en',
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint profiles_display_name_len check (char_length(display_name) between 1 and 60),
  constraint profiles_locale_len check (char_length(locale) between 2 and 12)
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  legal_name text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint organizations_slug_unique unique (slug),
  constraint organizations_name_len check (char_length(name) between 2 and 80),
  constraint organizations_slug_format check (slug ~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$')
);

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  name text not null,
  slug text not null,
  timezone text not null,
  currency_code text not null default 'USD',
  country_code text not null default 'US',
  address_line1 text,
  city text,
  region text,
  postal_code text,
  service_style text not null default 'wine_club',
  status text not null default 'draft',
  join_code text not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint venues_org_slug_unique unique (organization_id, slug),
  constraint venues_join_code_unique unique (join_code),
  constraint venues_name_len check (char_length(name) between 2 and 80),
  constraint venues_currency_check check (currency_code ~ '^[A-Z]{3}$'),
  constraint venues_timezone_check check (
    timezone = 'UTC' or timezone ~ '^[A-Za-z_]+(?:/[A-Za-z0-9_+-]+)+$'
  ),
  constraint venues_status_check check (status in ('draft', 'opening', 'active', 'suspended')),
  constraint venues_service_style_check check (
    service_style in ('wine_club', 'restaurant', 'club', 'event_venue', 'bar')
  )
);

create table public.app_roles (
  key text primary key,
  label text not null,
  rank integer not null,
  constraint app_roles_rank_positive check (rank > 0)
);

create table public.permissions (
  key text primary key,
  description text not null
);

create table public.role_permissions (
  role_key text not null references public.app_roles (key),
  permission_key text not null references public.permissions (key),
  primary key (role_key, permission_key)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  user_id uuid not null references public.profiles (id),
  venue_id uuid references public.venues (id),
  role_key text not null references public.app_roles (key),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint memberships_status_check check (status in ('active', 'suspended', 'revoked'))
);

create unique index memberships_active_unique
  on public.memberships (
    organization_id,
    user_id,
    role_key,
    (coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid))
  )
  where deleted_at is null and status = 'active';

create index memberships_user_idx
  on public.memberships (user_id)
  where deleted_at is null;

create index memberships_org_idx
  on public.memberships (organization_id)
  where deleted_at is null;

create index venues_org_idx
  on public.venues (organization_id)
  where deleted_at is null;

create table public.membership_permission_overrides (
  membership_id uuid not null references public.memberships (id) on delete cascade,
  permission_key text not null references public.permissions (key),
  effect text not null,
  primary key (membership_id, permission_key),
  constraint membership_overrides_effect_check check (effect in ('allow', 'deny'))
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid references public.venues (id),
  email text not null,
  role_key text not null references public.app_roles (key),
  token_hash text not null unique,
  expires_at timestamptz not null,
  invited_by uuid not null references public.profiles (id),
  accepted_at timestamptz,
  declined_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint invites_email_format check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

create unique index invites_open_email_role
  on public.invites (organization_id, lower(email), role_key)
  where accepted_at is null and declined_at is null and revoked_at is null;

create index invites_org_idx on public.invites (organization_id);

create table public.join_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid references public.venues (id),
  user_id uuid not null references public.profiles (id),
  requested_role_key text not null references public.app_roles (key),
  status text not null default 'pending',
  message text,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint join_requests_status_check check (status in ('pending', 'approved', 'declined')),
  constraint join_requests_message_len check (message is null or char_length(message) <= 500)
);

create unique index join_requests_pending_unique
  on public.join_requests (
    organization_id,
    user_id,
    (coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid))
  )
  where status = 'pending';

create index join_requests_org_status_idx
  on public.join_requests (organization_id, status);

create table public.platform_admins (
  user_id uuid primary key references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations (id),
  venue_id uuid references public.venues (id),
  actor_id uuid references public.profiles (id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_org_created_idx
  on public.audit_events (organization_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create trigger organizations_updated_at before update on public.organizations
for each row execute function public.set_updated_at();

create trigger venues_updated_at before update on public.venues
for each row execute function public.set_updated_at();

create trigger memberships_updated_at before update on public.memberships
for each row execute function public.set_updated_at();

create trigger join_requests_updated_at before update on public.join_requests
for each row execute function public.set_updated_at();

create or replace function public.reject_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'audit_immutable' using errcode = '42501';
end;
$$;

create trigger audit_events_immutable
before update or delete on public.audit_events
for each row execute function public.reject_audit_mutation();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1), 'Member'),
    nullif(pg_catalog.lower(new.email), '')
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = pg_catalog.now();
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_admins
    where user_id = (select auth.uid())
  );
$$;

create or replace function public.is_org_member(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
  or exists (
    select 1
    from public.memberships
    where organization_id = p_org
      and user_id = (select auth.uid())
      and status = 'active'
      and deleted_at is null
  );
$$;

create or replace function public.membership_allows(
  p_membership uuid,
  p_role text,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select 1
      from public.membership_permission_overrides
      where membership_id = p_membership
        and permission_key = p_permission
        and effect = 'deny'
    ) then false
    when exists (
      select 1
      from public.membership_permission_overrides
      where membership_id = p_membership
        and permission_key = p_permission
        and effect = 'allow'
    ) then true
    else exists (
      select 1
      from public.role_permissions
      where role_key = p_role
        and permission_key = p_permission
    )
  end;
$$;

create or replace function public.has_permission(p_org uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
  or exists (
    select 1
    from public.memberships m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.deleted_at is null
      and public.membership_allows(m.id, m.role_key, p_permission)
  );
$$;

create or replace function public.has_scoped_permission(
  p_org uuid,
  p_venue uuid,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_platform_admin()
  or exists (
    select 1
    from public.memberships m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.deleted_at is null
      and (m.venue_id is null or m.venue_id = p_venue)
      and public.membership_allows(m.id, m.role_key, p_permission)
  );
$$;

create or replace function public.actor_can_grant(
  p_org uuid,
  p_venue uuid,
  p_role text,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_roles target_role
    where target_role.key = p_role
  )
  and exists (
    select 1
    from public.memberships m
    join public.app_roles actor_role on actor_role.key = m.role_key
    join public.app_roles target_role on target_role.key = p_role
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.deleted_at is null
      and (
        (p_venue is null and m.venue_id is null)
        or (p_venue is not null and (m.venue_id is null or m.venue_id = p_venue))
      )
      and actor_role.rank <= target_role.rank
      and public.membership_allows(m.id, m.role_key, p_permission)
  );
$$;

create or replace function public.ensure_profile(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, email)
  select
    u.id,
    coalesce(nullif(pg_catalog.btrim(u.raw_user_meta_data ->> 'display_name'), ''), split_part(u.email, '@', 1), 'Member'),
    nullif(pg_catalog.lower(u.email), '')
  from auth.users u
  where u.id = p_uid
  on conflict (id) do nothing;
end;
$$;

create or replace function public.create_organization(
  p_name text,
  p_slug text,
  p_legal_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid;
  v_slug text := pg_catalog.lower(pg_catalog.btrim(p_slug));
  v_name text := pg_catalog.btrim(p_name);
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  perform public.ensure_profile(v_uid);
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if v_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$' then
    raise exception 'invalid_slug' using errcode = '22023';
  end if;

  insert into public.organizations (name, slug, legal_name, created_by)
  values (v_name, v_slug, nullif(pg_catalog.btrim(p_legal_name), ''), v_uid)
  returning id into v_org;

  insert into public.memberships (organization_id, user_id, role_key, status)
  values (v_org, v_uid, 'organization_owner', 'active');

  insert into public.audit_events (organization_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_org,
    v_uid,
    'organization.created',
    'organization',
    v_org,
    jsonb_build_object('slug', v_slug)
  );

  return v_org;
exception
  when unique_violation then
    raise exception 'slug_taken' using errcode = '23505';
end;
$$;

create or replace function public.generate_join_code()
returns text
language plpgsql
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
begin
  for i in 1..8 loop
    result := result || substr(alphabet, 1 + floor(pg_catalog.random() * char_length(alphabet))::integer, 1);
  end loop;
  return result;
end;
$$;

create or replace function public.create_venue(
  p_organization_id uuid,
  p_name text,
  p_slug text,
  p_timezone text,
  p_currency_code text,
  p_country_code text,
  p_address_line1 text,
  p_city text,
  p_region text,
  p_postal_code text,
  p_service_style text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_code text;
  v_name text := pg_catalog.btrim(p_name);
  v_slug text := pg_catalog.lower(pg_catalog.btrim(p_slug));
  v_attempt integer := 0;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.has_permission(p_organization_id, 'venue.create') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if v_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$' then
    raise exception 'invalid_slug' using errcode = '22023';
  end if;
  if p_timezone <> 'UTC' and p_timezone !~ '^[A-Za-z_]+(?:/[A-Za-z0-9_+-]+)+$' then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;
  if p_currency_code !~ '^[A-Z]{3}$' then
    raise exception 'invalid_currency' using errcode = '22023';
  end if;
  if p_service_style not in ('wine_club', 'restaurant', 'club', 'event_venue', 'bar') then
    raise exception 'invalid_service_style' using errcode = '22023';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := public.generate_join_code();
    begin
      insert into public.venues (
        organization_id, name, slug, timezone, currency_code, country_code,
        address_line1, city, region, postal_code, service_style, status, join_code, created_by
      ) values (
        p_organization_id,
        v_name,
        v_slug,
        p_timezone,
        p_currency_code,
        coalesce(nullif(p_country_code, ''), 'US'),
        nullif(pg_catalog.btrim(p_address_line1), ''),
        nullif(pg_catalog.btrim(p_city), ''),
        nullif(pg_catalog.btrim(p_region), ''),
        nullif(pg_catalog.btrim(p_postal_code), ''),
        p_service_style,
        'opening',
        v_code,
        v_uid
      )
      returning id into v_id;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise exception 'slug_taken' using errcode = '23505';
        end if;
    end;
  end loop;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id,
    v_id,
    v_uid,
    'venue.created',
    'venue',
    v_id,
    jsonb_build_object('slug', v_slug, 'service_style', p_service_style)
  );
  return v_id;
end;
$$;

create or replace function public.venue_join_code(p_venue_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select organization_id, join_code into v_org, v_code
  from public.venues
  where id = p_venue_id and deleted_at is null;
  if v_org is null then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_org, p_venue_id, 'membership.invite')
     and not public.has_scoped_permission(v_org, p_venue_id, 'venue.update') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  return v_code;
end;
$$;

create or replace function public.create_invite(
  p_organization_id uuid,
  p_venue_id uuid,
  p_email text,
  p_role_key text,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email));
  v_hash text;
  v_existing uuid;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;
  if p_token is null or char_length(p_token) < 32 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  if not exists (select 1 from public.app_roles where key = p_role_key) then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  if p_role_key in ('host', 'server', 'bartender', 'inventory_counter') and p_venue_id is null then
    raise exception 'role_requires_venue' using errcode = '22023';
  end if;
  if p_venue_id is not null and not exists (
    select 1 from public.venues
    where id = p_venue_id and organization_id = p_organization_id and deleted_at is null
  ) then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if not public.actor_can_grant(p_organization_id, p_venue_id, p_role_key, 'membership.invite') then
    raise exception 'cannot_assign_role' using errcode = '42501';
  end if;

  select id into v_existing
  from public.invites
  where organization_id = p_organization_id
    and lower(email) = v_email
    and role_key = p_role_key
    and accepted_at is null
    and declined_at is null
    and revoked_at is null;

  if v_existing is not null then
    return jsonb_build_object('id', v_existing, 'created', false);
  end if;

  v_hash := encode(extensions.digest(convert_to(p_token, 'utf8'), 'sha256'), 'hex');
  insert into public.invites (
    organization_id, venue_id, email, role_key, token_hash, expires_at, invited_by
  ) values (
    p_organization_id,
    p_venue_id,
    v_email,
    p_role_key,
    v_hash,
    pg_catalog.now() + interval '7 days',
    v_uid
  )
  returning id into v_id;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    p_organization_id,
    p_venue_id,
    v_uid,
    'invite.created',
    'invite',
    v_id,
    jsonb_build_object('role_key', p_role_key, 'email', v_email)
  );
  return jsonb_build_object('id', v_id, 'created', true);
exception
  when unique_violation then
    select id into v_existing
    from public.invites
    where organization_id = p_organization_id
      and lower(email) = v_email
      and role_key = p_role_key
      and accepted_at is null
      and declined_at is null
      and revoked_at is null;
    if v_existing is null then
      raise exception 'slug_taken' using errcode = '23505';
    end if;
    return jsonb_build_object('id', v_existing, 'created', false);
end;
$$;

create or replace function public.revoke_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select * into v_invite from public.invites where id = p_invite_id;
  if v_invite.id is null then
    raise exception 'invite_not_found' using errcode = '22023';
  end if;
  if not public.has_scoped_permission(v_invite.organization_id, v_invite.venue_id, 'membership.invite')
     and not public.has_permission(v_invite.organization_id, 'membership.invite') then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if v_invite.accepted_at is not null or v_invite.revoked_at is not null then
    raise exception 'invite_closed' using errcode = '22023';
  end if;
  update public.invites
  set revoked_at = pg_catalog.now()
  where id = p_invite_id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id)
  values (v_invite.organization_id, v_invite.venue_id, auth.uid(), 'invite.revoked', 'invite', p_invite_id);
end;
$$;

create or replace function public.accept_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text;
  v_invite public.invites%rowtype;
  v_email text;
  v_membership uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  perform public.ensure_profile(v_uid);
  if p_token is null or char_length(p_token) < 32 then
    raise exception 'invalid_token' using errcode = '22023';
  end if;
  v_hash := encode(extensions.digest(convert_to(p_token, 'utf8'), 'sha256'), 'hex');
  select * into v_invite from public.invites where token_hash = v_hash;
  if v_invite.id is null then
    raise exception 'invite_not_found' using errcode = '22023';
  end if;
  if v_invite.revoked_at is not null or v_invite.declined_at is not null then
    raise exception 'invite_closed' using errcode = '22023';
  end if;
  if v_invite.accepted_at is not null then
    raise exception 'invite_already_accepted' using errcode = '22023';
  end if;
  if v_invite.expires_at <= pg_catalog.now() then
    raise exception 'invite_expired' using errcode = '22023';
  end if;
  select lower(email) into v_email from auth.users where id = v_uid;
  if v_email is null or v_email <> lower(v_invite.email) then
    raise exception 'invite_email_mismatch' using errcode = '42501';
  end if;

  insert into public.memberships (organization_id, user_id, venue_id, role_key, status)
  values (v_invite.organization_id, v_uid, v_invite.venue_id, v_invite.role_key, 'active')
  on conflict do nothing
  returning id into v_membership;

  if v_membership is null then
    select id into v_membership
    from public.memberships
    where organization_id = v_invite.organization_id
      and user_id = v_uid
      and role_key = v_invite.role_key
      and coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
        = coalesce(v_invite.venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
      and deleted_at is null
      and status = 'active';
  end if;

  update public.invites set accepted_at = pg_catalog.now() where id = v_invite.id;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_invite.organization_id,
    v_invite.venue_id,
    v_uid,
    'invite.accepted',
    'membership',
    v_membership,
    jsonb_build_object('role_key', v_invite.role_key)
  );
  return v_membership;
end;
$$;

create or replace function public.lookup_venue_by_code(p_code text)
returns table (
  venue_id uuid,
  venue_name text,
  organization_name text,
  service_style text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p_code, ''), '[^A-Z0-9]', '', 'g'));
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  return query
  select v.id, v.name, o.name, v.service_style
  from public.venues v
  join public.organizations o on o.id = v.organization_id
  where v.join_code = v_code
    and v.deleted_at is null
    and o.deleted_at is null;
end;
$$;

create or replace function public.request_join(
  p_code text,
  p_role_key text,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := pg_catalog.upper(pg_catalog.regexp_replace(coalesce(p_code, ''), '[^A-Z0-9]', '', 'g'));
  v_venue public.venues%rowtype;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  perform public.ensure_profile(v_uid);
  if not exists (select 1 from public.app_roles where key = p_role_key) then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  if p_role_key = 'organization_owner' then
    raise exception 'cannot_assign_role' using errcode = '42501';
  end if;
  if p_message is not null and char_length(p_message) > 500 then
    raise exception 'invalid_message' using errcode = '22023';
  end if;
  select * into v_venue
  from public.venues
  where join_code = v_code and deleted_at is null;
  if v_venue.id is null then
    raise exception 'venue_not_found' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.memberships
    where organization_id = v_venue.organization_id
      and user_id = v_uid
      and status = 'active'
      and deleted_at is null
  ) then
    raise exception 'already_member' using errcode = '23505';
  end if;
  if exists (
    select 1 from public.join_requests
    where organization_id = v_venue.organization_id
      and user_id = v_uid
      and status = 'pending'
  ) then
    raise exception 'join_already_pending' using errcode = '23505';
  end if;

  insert into public.join_requests (
    organization_id, venue_id, user_id, requested_role_key, message
  ) values (
    v_venue.organization_id,
    v_venue.id,
    v_uid,
    p_role_key,
    nullif(pg_catalog.btrim(p_message), '')
  )
  returning id into v_id;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_venue.organization_id,
    v_venue.id,
    v_uid,
    'join.requested',
    'join_request',
    v_id,
    jsonb_build_object('role_key', p_role_key)
  );
  return v_id;
exception
  when unique_violation then
    raise exception 'already_member' using errcode = '23505';
end;
$$;

create or replace function public.review_join_request(
  p_request_id uuid,
  p_decision text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_request public.join_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_decision not in ('approved', 'declined') then
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  select * into v_request from public.join_requests where id = p_request_id;
  if v_request.id is null or v_request.status <> 'pending' then
    raise exception 'join_not_found' using errcode = '22023';
  end if;
  if not public.actor_can_grant(
    v_request.organization_id,
    v_request.venue_id,
    v_request.requested_role_key,
    'membership.approve'
  ) then
    raise exception 'cannot_assign_role' using errcode = '42501';
  end if;

  if p_decision = 'approved' then
    insert into public.memberships (organization_id, user_id, venue_id, role_key, status)
    values (
      v_request.organization_id,
      v_request.user_id,
      v_request.venue_id,
      v_request.requested_role_key,
      'active'
    )
    on conflict do nothing;
  end if;

  update public.join_requests
  set status = p_decision,
      reviewed_by = v_uid,
      reviewed_at = pg_catalog.now()
  where id = p_request_id;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_request.organization_id,
    v_request.venue_id,
    v_uid,
    case when p_decision = 'approved' then 'join.approved' else 'join.declined' end,
    'join_request',
    p_request_id,
    jsonb_build_object('role_key', v_request.requested_role_key)
  );
end;
$$;

create or replace function public.assign_membership_role(
  p_membership_id uuid,
  p_role_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_membership public.memberships%rowtype;
  v_owner_count integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (select 1 from public.app_roles where key = p_role_key) then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  select * into v_membership
  from public.memberships
  where id = p_membership_id and deleted_at is null and status = 'active';
  if v_membership.id is null then
    raise exception 'join_not_found' using errcode = '22023';
  end if;
  if p_role_key in ('host', 'server', 'bartender', 'inventory_counter') and v_membership.venue_id is null then
    raise exception 'role_requires_venue' using errcode = '22023';
  end if;
  if not public.actor_can_grant(
    v_membership.organization_id,
    v_membership.venue_id,
    p_role_key,
    'membership.assign_role'
  ) then
    raise exception 'cannot_assign_role' using errcode = '42501';
  end if;
  if v_membership.role_key = 'organization_owner' and p_role_key <> 'organization_owner' then
    select count(*) into v_owner_count
    from public.memberships
    where organization_id = v_membership.organization_id
      and role_key = 'organization_owner'
      and status = 'active'
      and deleted_at is null;
    if v_owner_count <= 1 then
      raise exception 'last_owner' using errcode = '22023';
    end if;
  end if;

  update public.memberships
  set role_key = p_role_key
  where id = p_membership_id;

  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, entity_id, payload)
  values (
    v_membership.organization_id,
    v_membership.venue_id,
    v_uid,
    'membership.role_changed',
    'membership',
    p_membership_id,
    jsonb_build_object('from', v_membership.role_key, 'to', p_role_key)
  );
end;
$$;

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.venues enable row level security;
alter table public.app_roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.memberships enable row level security;
alter table public.membership_permission_overrides enable row level security;
alter table public.invites enable row level security;
alter table public.join_requests enable row level security;
alter table public.platform_admins enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_select on public.profiles
for select to authenticated
using (
  deleted_at is null
  and (
    id = (select auth.uid())
    or public.is_platform_admin()
    or exists (
      select 1
      from public.memberships mine
      join public.memberships theirs
        on theirs.organization_id = mine.organization_id
      where mine.user_id = (select auth.uid())
        and mine.status = 'active'
        and mine.deleted_at is null
        and theirs.user_id = profiles.id
        and theirs.deleted_at is null
    )
  )
);

create policy profiles_update_self on public.profiles
for update to authenticated
using (id = (select auth.uid()) and deleted_at is null)
with check (id = (select auth.uid()));

create policy organizations_select on public.organizations
for select to authenticated
using (deleted_at is null and public.is_org_member(id));

create policy venues_select on public.venues
for select to authenticated
using (deleted_at is null and public.is_org_member(organization_id));

create policy memberships_select on public.memberships
for select to authenticated
using (deleted_at is null and public.is_org_member(organization_id));

create policy app_roles_select on public.app_roles
for select to authenticated
using (true);

create policy permissions_select on public.permissions
for select to authenticated
using (true);

create policy role_permissions_select on public.role_permissions
for select to authenticated
using (true);

create policy invites_select on public.invites
for select to authenticated
using (public.has_permission(organization_id, 'membership.read'));

create policy join_requests_select on public.join_requests
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.has_permission(organization_id, 'membership.read')
);

create policy audit_select on public.audit_events
for select to authenticated
using (
  organization_id is not null
  and public.has_permission(organization_id, 'audit.read')
);

revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.organizations from public, anon, authenticated;
revoke all on table public.venues from public, anon, authenticated;
revoke all on table public.app_roles from public, anon, authenticated;
revoke all on table public.permissions from public, anon, authenticated;
revoke all on table public.role_permissions from public, anon, authenticated;
revoke all on table public.memberships from public, anon, authenticated;
revoke all on table public.membership_permission_overrides from public, anon, authenticated;
revoke all on table public.invites from public, anon, authenticated;
revoke all on table public.join_requests from public, anon, authenticated;
revoke all on table public.platform_admins from public, anon, authenticated;
revoke all on table public.audit_events from public, anon, authenticated;

grant select (id, display_name, email, phone, locale, timezone, created_at, updated_at)
  on public.profiles to authenticated;
grant update (display_name, phone, locale, timezone)
  on public.profiles to authenticated;
grant select on public.organizations to authenticated;
grant select (
  id, organization_id, name, slug, timezone, currency_code, country_code,
  address_line1, city, region, postal_code, service_style, status, created_by, created_at, updated_at
) on public.venues to authenticated;
grant select on public.app_roles to authenticated;
grant select on public.permissions to authenticated;
grant select on public.role_permissions to authenticated;
grant select on public.memberships to authenticated;
grant select (
  id, organization_id, venue_id, email, role_key, expires_at, invited_by,
  accepted_at, declined_at, revoked_at, created_at
) on public.invites to authenticated;
grant select on public.join_requests to authenticated;
grant select on public.audit_events to authenticated;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.reject_audit_mutation() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.ensure_profile(uuid) from public, anon, authenticated;
revoke all on function public.generate_join_code() from public, anon, authenticated;
revoke all on function public.is_platform_admin() from public, anon;
revoke all on function public.is_org_member(uuid) from public, anon;
revoke all on function public.membership_allows(uuid, text, text) from public, anon;
revoke all on function public.has_permission(uuid, text) from public, anon;
revoke all on function public.has_scoped_permission(uuid, uuid, text) from public, anon;
revoke all on function public.actor_can_grant(uuid, uuid, text, text) from public, anon;

grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.membership_allows(uuid, text, text) to authenticated;
grant execute on function public.has_permission(uuid, text) to authenticated;
grant execute on function public.has_scoped_permission(uuid, uuid, text) to authenticated;
grant execute on function public.actor_can_grant(uuid, uuid, text, text) to authenticated;

revoke all on function public.create_organization(text, text, text) from public, anon;
revoke all on function public.create_venue(uuid, text, text, text, text, text, text, text, text, text, text) from public, anon;
revoke all on function public.venue_join_code(uuid) from public, anon;
revoke all on function public.create_invite(uuid, uuid, text, text, text) from public, anon;
revoke all on function public.revoke_invite(uuid) from public, anon;
revoke all on function public.accept_invite(text) from public, anon;
revoke all on function public.lookup_venue_by_code(text) from public, anon;
revoke all on function public.request_join(text, text, text) from public, anon;
revoke all on function public.review_join_request(uuid, text) from public, anon;
revoke all on function public.assign_membership_role(uuid, text) from public, anon;

grant execute on function public.create_organization(text, text, text) to authenticated;
grant execute on function public.create_venue(uuid, text, text, text, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.venue_join_code(uuid) to authenticated;
grant execute on function public.create_invite(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.revoke_invite(uuid) to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.lookup_venue_by_code(text) to authenticated;
grant execute on function public.request_join(text, text, text) to authenticated;
grant execute on function public.review_join_request(uuid, text) to authenticated;
grant execute on function public.assign_membership_role(uuid, text) to authenticated;
