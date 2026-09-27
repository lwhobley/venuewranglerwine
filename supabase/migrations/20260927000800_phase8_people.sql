-- Phase 8: published schedules, time clock, checklists, logbook, documents.

create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  role_key text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'draft',
  created_by uuid not null references public.profiles (id),
  constraint shifts_window_check check (ends_at > starts_at),
  constraint shifts_status_check check (status in ('draft', 'published'))
);

create table public.time_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  user_id uuid not null references public.profiles (id),
  clock_in timestamptz not null default now(),
  clock_out timestamptz
);

create unique index time_entries_one_open
  on public.time_entries (venue_id, user_id)
  where clock_out is null;

create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  name text not null,
  constraint checklist_templates_name_len check (char_length(name) between 2 and 80)
);

create table public.checklist_items (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.checklist_templates (id),
  organization_id uuid not null references public.organizations (id),
  label text not null
);

create table public.checklist_runs (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.checklist_templates (id),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  run_on date not null default current_date,
  status text not null default 'open',
  constraint checklist_runs_status_check check (status in ('open', 'complete'))
);

create table public.checklist_completions (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.checklist_runs (id),
  item_id uuid not null references public.checklist_items (id),
  organization_id uuid not null references public.organizations (id),
  completed_by uuid not null references public.profiles (id),
  completed_at timestamptz not null default now(),
  constraint checklist_completions_unique unique (run_id, item_id)
);

create table public.logbook_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  body text not null,
  handoff boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint logbook_entries_body_len check (char_length(body) between 1 and 2000)
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  venue_id uuid not null references public.venues (id),
  title text not null,
  body text not null,
  requires_ack boolean not null default true,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint documents_title_len check (char_length(title) between 2 and 120)
);

create table public.document_acknowledgments (
  document_id uuid not null references public.documents (id),
  user_id uuid not null references public.profiles (id),
  acknowledged_at timestamptz not null default now(),
  primary key (document_id, user_id)
);

create or replace function public.create_shift(
  p_organization_id uuid,
  p_venue_id uuid,
  p_role_key text,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'schedule.publish');
  if p_ends_at is null or p_starts_at is null or p_ends_at <= p_starts_at then
    raise exception 'invalid_shift' using errcode = '22023';
  end if;
  if not exists (select 1 from public.app_roles where key = p_role_key) then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  insert into public.shifts (organization_id, venue_id, role_key, starts_at, ends_at, created_by)
  values (p_organization_id, p_venue_id, p_role_key, p_starts_at, p_ends_at, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.publish_shifts(p_venue_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_count integer;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  perform public.require_venue_permission(v_org, p_venue_id, 'schedule.publish');
  update public.shifts set status = 'published'
  where venue_id = p_venue_id and status = 'draft';
  get diagnostics v_count = row_count;
  insert into public.audit_events (organization_id, venue_id, actor_id, action, entity_type, payload)
  values (v_org, p_venue_id, auth.uid(), 'schedule.published', 'shift', jsonb_build_object('count', v_count));
  return v_count;
end;
$$;

create or replace function public.clock_in(p_venue_id uuid)
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
  perform public.require_venue_permission(v_org, p_venue_id, 'timeclock.self');
  if exists (
    select 1 from public.time_entries
    where venue_id = p_venue_id and user_id = auth.uid() and clock_out is null
  ) then
    raise exception 'already_clocked_in' using errcode = '23505';
  end if;
  insert into public.time_entries (organization_id, venue_id, user_id)
  values (v_org, p_venue_id, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.clock_out(p_venue_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  perform public.require_venue_permission(v_org, p_venue_id, 'timeclock.self');
  update public.time_entries
  set clock_out = pg_catalog.now()
  where venue_id = p_venue_id and user_id = auth.uid() and clock_out is null;
  if not found then
    raise exception 'not_clocked_in' using errcode = '22023';
  end if;
end;
$$;

create or replace function public.create_checklist(
  p_organization_id uuid,
  p_venue_id uuid,
  p_name text,
  p_item_label text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'checklist.manage');
  if pg_catalog.btrim(p_name) is null or char_length(pg_catalog.btrim(p_name)) < 2 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  insert into public.checklist_templates (organization_id, venue_id, name)
  values (p_organization_id, p_venue_id, pg_catalog.btrim(p_name))
  returning id into v_id;
  insert into public.checklist_items (template_id, organization_id, label)
  values (v_id, p_organization_id, pg_catalog.btrim(p_item_label));
  return v_id;
end;
$$;

create or replace function public.start_checklist_run(p_template_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template public.checklist_templates%rowtype;
  v_id uuid;
begin
  select * into v_template from public.checklist_templates where id = p_template_id;
  if v_template.id is null then
    raise exception 'checklist_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_template.organization_id, v_template.venue_id, 'checklist.execute');
  insert into public.checklist_runs (template_id, organization_id, venue_id)
  values (p_template_id, v_template.organization_id, v_template.venue_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.complete_checklist_item(p_run_id uuid, p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run public.checklist_runs%rowtype;
begin
  select * into v_run from public.checklist_runs where id = p_run_id;
  if v_run.id is null or v_run.status <> 'open' then
    raise exception 'checklist_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_run.organization_id, v_run.venue_id, 'checklist.execute');
  if not exists (
    select 1 from public.checklist_items
    where id = p_item_id and template_id = v_run.template_id
  ) then
    raise exception 'checklist_not_found' using errcode = '22023';
  end if;
  insert into public.checklist_completions (run_id, item_id, organization_id, completed_by)
  values (p_run_id, p_item_id, v_run.organization_id, auth.uid());
  if not exists (
    select 1
    from public.checklist_items i
    where i.template_id = v_run.template_id
      and not exists (
        select 1 from public.checklist_completions c
        where c.run_id = p_run_id and c.item_id = i.id
      )
  ) then
    update public.checklist_runs set status = 'complete' where id = p_run_id;
  end if;
exception
  when unique_violation then
    raise exception 'checklist_already_done' using errcode = '23505';
end;
$$;

create or replace function public.write_logbook(p_venue_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_id uuid;
  v_body text := pg_catalog.btrim(p_body);
begin
  select organization_id into v_org from public.venues where id = p_venue_id and deleted_at is null;
  perform public.require_venue_permission(v_org, p_venue_id, 'logbook.write');
  if v_body is null or char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'invalid_message' using errcode = '22023';
  end if;
  insert into public.logbook_entries (organization_id, venue_id, body, created_by)
  values (v_org, p_venue_id, v_body, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.create_document(
  p_organization_id uuid,
  p_venue_id uuid,
  p_title text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.require_venue_permission(p_organization_id, p_venue_id, 'document.manage');
  if char_length(pg_catalog.btrim(p_title)) < 2 or char_length(pg_catalog.btrim(p_body)) < 1 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  insert into public.documents (organization_id, venue_id, title, body, created_by)
  values (p_organization_id, p_venue_id, pg_catalog.btrim(p_title), pg_catalog.btrim(p_body), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.acknowledge_document(p_document_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc public.documents%rowtype;
begin
  select * into v_doc from public.documents where id = p_document_id;
  if v_doc.id is null then
    raise exception 'document_not_found' using errcode = '22023';
  end if;
  perform public.require_venue_permission(v_doc.organization_id, v_doc.venue_id, 'document.read');
  insert into public.document_acknowledgments (document_id, user_id)
  values (p_document_id, auth.uid());
exception
  when unique_violation then
    raise exception 'already_acknowledged' using errcode = '23505';
end;
$$;

alter table public.shifts enable row level security;
alter table public.time_entries enable row level security;
alter table public.checklist_templates enable row level security;
alter table public.checklist_items enable row level security;
alter table public.checklist_runs enable row level security;
alter table public.checklist_completions enable row level security;
alter table public.logbook_entries enable row level security;
alter table public.documents enable row level security;
alter table public.document_acknowledgments enable row level security;

create policy shifts_select on public.shifts for select to authenticated
using (public.has_permission(organization_id, 'schedule.read') or public.has_permission(organization_id, 'schedule.publish'));
create policy time_entries_select on public.time_entries for select to authenticated
using (user_id = (select auth.uid()) or public.has_permission(organization_id, 'timeclock.manage'));
create policy checklist_templates_select on public.checklist_templates for select to authenticated
using (public.has_permission(organization_id, 'checklist.execute') or public.has_permission(organization_id, 'checklist.manage'));
create policy checklist_items_select on public.checklist_items for select to authenticated
using (public.has_permission(organization_id, 'checklist.execute') or public.has_permission(organization_id, 'checklist.manage'));
create policy checklist_runs_select on public.checklist_runs for select to authenticated
using (public.has_permission(organization_id, 'checklist.execute'));
create policy checklist_completions_select on public.checklist_completions for select to authenticated
using (public.has_permission(organization_id, 'checklist.execute'));
create policy logbook_select on public.logbook_entries for select to authenticated
using (public.has_permission(organization_id, 'logbook.write') or public.has_permission(organization_id, 'schedule.read'));
create policy documents_select on public.documents for select to authenticated
using (public.has_permission(organization_id, 'document.read'));
create policy document_ack_select on public.document_acknowledgments for select to authenticated
using (user_id = (select auth.uid()));

revoke all on table public.shifts from public, anon, authenticated;
revoke all on table public.time_entries from public, anon, authenticated;
revoke all on table public.checklist_templates from public, anon, authenticated;
revoke all on table public.checklist_items from public, anon, authenticated;
revoke all on table public.checklist_runs from public, anon, authenticated;
revoke all on table public.checklist_completions from public, anon, authenticated;
revoke all on table public.logbook_entries from public, anon, authenticated;
revoke all on table public.documents from public, anon, authenticated;
revoke all on table public.document_acknowledgments from public, anon, authenticated;

grant select (id, organization_id, venue_id, role_key, starts_at, ends_at, status) on public.shifts to authenticated;
grant select (id, organization_id, venue_id, user_id, clock_in, clock_out) on public.time_entries to authenticated;
grant select (id, organization_id, venue_id, name) on public.checklist_templates to authenticated;
grant select (id, template_id, organization_id, label) on public.checklist_items to authenticated;
grant select (id, template_id, organization_id, venue_id, status) on public.checklist_runs to authenticated;
grant select (id, run_id, item_id, organization_id, completed_at) on public.checklist_completions to authenticated;
grant select (id, organization_id, venue_id, body, handoff, created_at) on public.logbook_entries to authenticated;
grant select (id, organization_id, venue_id, title, body, requires_ack) on public.documents to authenticated;
grant select (document_id, user_id, acknowledged_at) on public.document_acknowledgments to authenticated;

revoke all on function public.create_shift(uuid, uuid, text, timestamptz, timestamptz) from public, anon;
revoke all on function public.publish_shifts(uuid) from public, anon;
revoke all on function public.clock_in(uuid) from public, anon;
revoke all on function public.clock_out(uuid) from public, anon;
revoke all on function public.create_checklist(uuid, uuid, text, text) from public, anon;
revoke all on function public.start_checklist_run(uuid) from public, anon;
revoke all on function public.complete_checklist_item(uuid, uuid) from public, anon;
revoke all on function public.write_logbook(uuid, text) from public, anon;
revoke all on function public.create_document(uuid, uuid, text, text) from public, anon;
revoke all on function public.acknowledge_document(uuid) from public, anon;
grant execute on function public.create_shift(uuid, uuid, text, timestamptz, timestamptz) to authenticated;
grant execute on function public.publish_shifts(uuid) to authenticated;
grant execute on function public.clock_in(uuid) to authenticated;
grant execute on function public.clock_out(uuid) to authenticated;
grant execute on function public.create_checklist(uuid, uuid, text, text) to authenticated;
grant execute on function public.start_checklist_run(uuid) to authenticated;
grant execute on function public.complete_checklist_item(uuid, uuid) to authenticated;
grant execute on function public.write_logbook(uuid, text) to authenticated;
grant execute on function public.create_document(uuid, uuid, text, text) to authenticated;
grant execute on function public.acknowledge_document(uuid) to authenticated;
