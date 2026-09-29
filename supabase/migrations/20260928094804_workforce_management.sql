-- Workforce schema preserves existing imported shifts and attendance.
alter table public.venues add constraint venues_id_org_unique unique(id,organization_id);
alter table public.shifts add column period_id uuid, add column job_role_id uuid, add column department_id uuid, add column area_id uuid, add column event_id uuid references public.events(id), add column headcount integer not null default 1 check(headcount between 1 and 1000), add column instructions text not null default '', add column updated_at timestamptz not null default now(), add column deleted_at timestamptz, add column revision integer not null default 1;
alter table public.time_entries add column shift_id uuid references public.shifts(id), add column updated_at timestamptz not null default now(), add column created_at timestamptz not null default now(), add column created_by uuid references public.profiles(id), add column deleted_at timestamptz, add column revision integer not null default 1;
create table public.venue_areas (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, name text not null check(char_length(name) between 2 and 80), code text not null, location_id uuid references public.storage_locations(id), unique(organization_id,venue_id,code), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.venue_areas enable row level security;
revoke all on public.venue_areas from public, anon, authenticated;
create index venue_areas_scope_idx on public.venue_areas(organization_id,venue_id,updated_at);
create table public.departments (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, name text not null check(char_length(name) between 2 and 80), code text not null, unique(organization_id,venue_id,code), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.departments enable row level security;
revoke all on public.departments from public, anon, authenticated;
create index departments_scope_idx on public.departments(organization_id,venue_id,updated_at);
create table public.job_roles (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, department_id uuid references public.departments(id), key text not null, name text not null check(char_length(name) between 2 and 80), required_skills text[] not null default '{}', required_certifications text[] not null default '{}', enabled boolean not null default true, unique(organization_id,venue_id,key), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.job_roles enable row level security;
revoke all on public.job_roles from public, anon, authenticated;
create index job_roles_scope_idx on public.job_roles(organization_id,venue_id,updated_at);
create table public.staff_profiles (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, user_id uuid not null references public.profiles(id), display_name text not null check(char_length(display_name) between 1 and 80), employment_status text not null default 'active' check(employment_status in ('active','leave','suspended','terminated')), employment_type text not null default 'hourly' check(employment_type in ('hourly','salary','contract')), weekly_limit_minutes integer not null default 2400 check(weekly_limit_minutes between 60 and 10080), minimum_rest_minutes integer not null default 660 check(minimum_rest_minutes between 0 and 2880), unique(organization_id,user_id));
alter table public.staff_profiles enable row level security;
revoke all on public.staff_profiles from public, anon, authenticated;
create index staff_profiles_scope_idx on public.staff_profiles(organization_id,updated_at);
create table public.staff_role_assignments (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), job_role_id uuid not null references public.job_roles(id), unique(staff_id,job_role_id), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.staff_role_assignments enable row level security;
revoke all on public.staff_role_assignments from public, anon, authenticated;
create index staff_role_assignments_scope_idx on public.staff_role_assignments(organization_id,venue_id,updated_at);
create table public.staff_qualifications (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), skill_key text not null, approved boolean not null default false, unique(organization_id,staff_id,skill_key));
alter table public.staff_qualifications enable row level security;
revoke all on public.staff_qualifications from public, anon, authenticated;
create index staff_qualifications_scope_idx on public.staff_qualifications(organization_id,updated_at);
create table public.staff_certifications (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), certification_key text not null, expires_on date not null, status text not null default 'pending' check(status in ('pending','verified','revoked')), evidence_path text, verified_by uuid references public.profiles(id));
alter table public.staff_certifications enable row level security;
revoke all on public.staff_certifications from public, anon, authenticated;
create index staff_certifications_scope_idx on public.staff_certifications(organization_id,updated_at);
create table public.employee_wage_rates (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), job_role_id uuid references public.job_roles(id), hourly_rate numeric(14,4) not null check(hourly_rate >= 0), currency_code text not null check(currency_code ~ '^[A-Z]{3}$'), effective_from date not null, effective_until date check(effective_until > effective_from), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.employee_wage_rates enable row level security;
revoke all on public.employee_wage_rates from public, anon, authenticated;
create index employee_wage_rates_scope_idx on public.employee_wage_rates(organization_id,venue_id,updated_at);
create table public.staff_availability_rules (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), weekday integer not null check(weekday between 1 and 7), starts_local time not null, ends_local time not null, available boolean not null default true, valid_from date not null, valid_until date check(valid_until >= valid_from), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.staff_availability_rules enable row level security;
revoke all on public.staff_availability_rules from public, anon, authenticated;
create index staff_availability_rules_scope_idx on public.staff_availability_rules(organization_id,venue_id,updated_at);
create table public.staff_availability_exceptions (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), starts_at timestamptz not null, ends_at timestamptz not null check(ends_at > starts_at), available boolean not null, reason text not null default '', foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.staff_availability_exceptions enable row level security;
revoke all on public.staff_availability_exceptions from public, anon, authenticated;
create index staff_availability_exceptions_scope_idx on public.staff_availability_exceptions(organization_id,venue_id,updated_at);
create table public.time_off_balances (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), category text not null default 'paid', minutes integer not null default 0 check(minutes >= 0), unique(organization_id,staff_id,category));
alter table public.time_off_balances enable row level security;
revoke all on public.time_off_balances from public, anon, authenticated;
create index time_off_balances_scope_idx on public.time_off_balances(organization_id,updated_at);
create table public.time_off_requests (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), starts_at timestamptz not null, ends_at timestamptz not null check(ends_at > starts_at), category text not null default 'unpaid' check(category in ('paid','unpaid','sick','other')), requested_minutes integer not null default 0 check(requested_minutes >= 0), reason text not null default '', status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')), reviewed_by uuid references public.profiles(id), review_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.time_off_requests enable row level security;
revoke all on public.time_off_requests from public, anon, authenticated;
create index time_off_requests_scope_idx on public.time_off_requests(organization_id,venue_id,updated_at);
create table public.schedule_periods (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, starts_on date not null, ends_on date not null check(ends_on > starts_on and ends_on <= starts_on+31), name text not null, status text not null default 'draft' check(status in ('draft','published','retracted')), published_at timestamptz, unique(organization_id,venue_id,starts_on,ends_on), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.schedule_periods enable row level security;
revoke all on public.schedule_periods from public, anon, authenticated;
create index schedule_periods_scope_idx on public.schedule_periods(organization_id,venue_id,updated_at);
create table public.schedule_versions (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, period_id uuid not null references public.schedule_periods(id), version_number integer not null, source text not null, snapshot jsonb not null, unique(period_id,version_number), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.schedule_versions enable row level security;
revoke all on public.schedule_versions from public, anon, authenticated;
create index schedule_versions_scope_idx on public.schedule_versions(organization_id,venue_id,updated_at);
create table public.shift_assignments (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), staff_id uuid not null references public.staff_profiles(id), status text not null default 'assigned' check(status in ('assigned','released','cancelled')), override_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_assignments enable row level security;
revoke all on public.shift_assignments from public, anon, authenticated;
create index shift_assignments_scope_idx on public.shift_assignments(organization_id,venue_id,updated_at);
create table public.shift_break_rules (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), minimum_minutes integer not null default 0 check(minimum_minutes between 0 and 240), paid boolean not null default false, required boolean not null default false, unique(shift_id), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_break_rules enable row level security;
revoke all on public.shift_break_rules from public, anon, authenticated;
create index shift_break_rules_scope_idx on public.shift_break_rules(organization_id,venue_id,updated_at);
create table public.shift_notes (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), body text not null check(char_length(body) between 1 and 5000), staff_visible boolean not null default true, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_notes enable row level security;
revoke all on public.shift_notes from public, anon, authenticated;
create index shift_notes_scope_idx on public.shift_notes(organization_id,venue_id,updated_at);
create table public.shift_requirements (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, period_id uuid not null references public.schedule_periods(id), job_role_id uuid not null references public.job_roles(id), area_id uuid references public.venue_areas(id), starts_at timestamptz not null, ends_at timestamptz not null check(ends_at > starts_at), minimum_staff integer not null check(minimum_staff between 1 and 10000), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_requirements enable row level security;
revoke all on public.shift_requirements from public, anon, authenticated;
create index shift_requirements_scope_idx on public.shift_requirements(organization_id,venue_id,updated_at);
create table public.open_shift_offers (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), released_assignment_id uuid references public.shift_assignments(id), status text not null default 'open' check(status in ('open','filled','cancelled')), closes_at timestamptz not null, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.open_shift_offers enable row level security;
revoke all on public.open_shift_offers from public, anon, authenticated;
create index open_shift_offers_scope_idx on public.open_shift_offers(organization_id,venue_id,updated_at);
create table public.shift_drop_requests (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), assignment_id uuid not null references public.shift_assignments(id), staff_id uuid not null references public.staff_profiles(id), expected_shift_revision integer not null, reason text not null, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')), reviewed_by uuid references public.profiles(id), review_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_drop_requests enable row level security;
revoke all on public.shift_drop_requests from public, anon, authenticated;
create index shift_drop_requests_scope_idx on public.shift_drop_requests(organization_id,venue_id,updated_at);
create table public.shift_pickup_requests (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), offer_id uuid not null references public.open_shift_offers(id), staff_id uuid not null references public.staff_profiles(id), expected_shift_revision integer not null, status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')), reviewed_by uuid references public.profiles(id), review_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_pickup_requests enable row level security;
revoke all on public.shift_pickup_requests from public, anon, authenticated;
create index shift_pickup_requests_scope_idx on public.shift_pickup_requests(organization_id,venue_id,updated_at);
create table public.shift_swap_requests (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid not null references public.shifts(id), other_shift_id uuid not null references public.shifts(id) check(other_shift_id <> shift_id), staff_id uuid not null references public.staff_profiles(id), other_staff_id uuid not null references public.staff_profiles(id) check(other_staff_id <> staff_id), expected_shift_revision integer not null, expected_other_revision integer not null, recipient_accepted boolean not null default false, reason text not null default '', status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')), reviewed_by uuid references public.profiles(id), review_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_swap_requests enable row level security;
revoke all on public.shift_swap_requests from public, anon, authenticated;
create index shift_swap_requests_scope_idx on public.shift_swap_requests(organization_id,venue_id,updated_at);
create table public.shift_change_events (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, shift_id uuid references public.shifts(id), entity_type text not null, entity_id uuid not null, action text not null, source text not null, previous_state jsonb, next_state jsonb, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.shift_change_events enable row level security;
revoke all on public.shift_change_events from public, anon, authenticated;
create index shift_change_events_scope_idx on public.shift_change_events(organization_id,venue_id,updated_at);
create table public.schedule_templates (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, name text not null check(char_length(name) between 2 and 80), unique(organization_id,venue_id,name), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.schedule_templates enable row level security;
revoke all on public.schedule_templates from public, anon, authenticated;
create index schedule_templates_scope_idx on public.schedule_templates(organization_id,venue_id,updated_at);
create table public.schedule_template_shifts (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, template_id uuid not null references public.schedule_templates(id), job_role_id uuid not null references public.job_roles(id), department_id uuid references public.departments(id), area_id uuid references public.venue_areas(id), weekday integer not null check(weekday between 1 and 7), starts_local time not null, duration_minutes integer not null check(duration_minutes between 1 and 1440), headcount integer not null default 1 check(headcount between 1 and 1000), instructions text not null default '', break_minutes integer not null default 0, break_paid boolean not null default false, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.schedule_template_shifts enable row level security;
revoke all on public.schedule_template_shifts from public, anon, authenticated;
create index schedule_template_shifts_scope_idx on public.schedule_template_shifts(organization_id,venue_id,updated_at);
create table public.labor_targets (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, starts_on date not null, ends_on date not null check(ends_on > starts_on), target_minutes integer check(target_minutes >= 0), target_cost numeric(14,4) check(target_cost >= 0), target_percent numeric(7,4) check(target_percent between 0 and 100), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.labor_targets enable row level security;
revoke all on public.labor_targets from public, anon, authenticated;
create index labor_targets_scope_idx on public.labor_targets(organization_id,venue_id,updated_at);
create table public.labor_forecasts (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, service_date date not null, forecast_sales numeric(14,4) not null check(forecast_sales >= 0), forecast_covers integer not null default 0 check(forecast_covers >= 0), unique(organization_id,venue_id,service_date), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.labor_forecasts enable row level security;
revoke all on public.labor_forecasts from public, anon, authenticated;
create index labor_forecasts_scope_idx on public.labor_forecasts(organization_id,venue_id,updated_at);
create table public.break_entries (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, time_entry_id uuid not null references public.time_entries(id), starts_at timestamptz not null, ends_at timestamptz check(ends_at >= starts_at), paid boolean not null default false, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.break_entries enable row level security;
revoke all on public.break_entries from public, anon, authenticated;
create index break_entries_scope_idx on public.break_entries(organization_id,venue_id,updated_at);
create table public.time_entry_corrections (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, time_entry_id uuid not null references public.time_entries(id), reason text not null check(char_length(reason) between 5 and 2000), previous_state jsonb not null, next_state jsonb not null, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.time_entry_corrections enable row level security;
revoke all on public.time_entry_corrections from public, anon, authenticated;
create index time_entry_corrections_scope_idx on public.time_entry_corrections(organization_id,venue_id,updated_at);
create table public.clock_attestations (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, staff_id uuid not null references public.staff_profiles(id), time_entry_id uuid references public.time_entries(id), kind text not null check(kind in ('missed_break','offline_in','offline_out','offline_break_start','offline_break_end')), captured_at timestamptz not null, reason text not null, status text not null default 'pending' check(status in ('pending','approved','rejected')), reviewed_by uuid references public.profiles(id), review_reason text, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.clock_attestations enable row level security;
revoke all on public.clock_attestations from public, anon, authenticated;
create index clock_attestations_scope_idx on public.clock_attestations(organization_id,venue_id,updated_at);
create table public.notifications (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, recipient_id uuid not null references public.profiles(id), kind text not null, title text not null, body text not null, shift_id uuid references public.shifts(id), read_at timestamptz, reminder_at timestamptz, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.notifications enable row level security;
revoke all on public.notifications from public, anon, authenticated;
create index notifications_scope_idx on public.notifications(organization_id,venue_id,updated_at);
create table public.staff_messages (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, sender_id uuid not null references public.profiles(id), recipient_id uuid references public.profiles(id), shift_id uuid references public.shifts(id), body text not null check(char_length(body) between 1 and 5000), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.staff_messages enable row level security;
revoke all on public.staff_messages from public, anon, authenticated;
create index staff_messages_scope_idx on public.staff_messages(organization_id,venue_id,updated_at);
create table public.workforce_settings (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, require_assigned_clock boolean not null default true, clock_early_minutes integer not null default 15 check(clock_early_minutes between 0 and 240), clock_late_minutes integer not null default 120 check(clock_late_minutes between 0 and 1440), overtime_week_minutes integer not null default 2400 check(overtime_week_minutes between 60 and 10080), overtime_multiplier numeric(6,4) not null default 1.5 check(overtime_multiplier between 1 and 5), minimum_break_minutes integer not null default 30 check(minimum_break_minutes between 0 and 120), break_after_minutes integer not null default 360 check(break_after_minutes between 0 and 1440), reminder_minutes integer not null default 60 check(reminder_minutes between 0 and 1440), unique(organization_id,venue_id), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.workforce_settings enable row level security;
revoke all on public.workforce_settings from public, anon, authenticated;
create index workforce_settings_scope_idx on public.workforce_settings(organization_id,venue_id,updated_at);
create table public.workforce_commands (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, command_id uuid not null unique, actor_id uuid not null references public.profiles(id), action text not null, request_hash text not null, response jsonb not null, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.workforce_commands enable row level security;
revoke all on public.workforce_commands from public, anon, authenticated;
create index workforce_commands_scope_idx on public.workforce_commands(organization_id,venue_id,updated_at);
create table public.push_devices (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, user_id uuid not null references public.profiles(id), token text not null unique, platform text not null check(platform in ('android','ios','web')), enabled boolean not null default true, foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.push_devices enable row level security;
revoke all on public.push_devices from public, anon, authenticated;
create index push_devices_scope_idx on public.push_devices(organization_id,venue_id,updated_at);
create table public.notification_outbox (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, notification_id uuid not null references public.notifications(id), status text not null default 'pending' check(status in ('pending','processing','sent','failed','unconfigured')), attempts integer not null default 0, available_at timestamptz not null default now(), leased_until timestamptz, last_error text, unique(notification_id), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.notification_outbox enable row level security;
revoke all on public.notification_outbox from public, anon, authenticated;
create index notification_outbox_scope_idx on public.notification_outbox(organization_id,venue_id,updated_at);
create table public.workforce_push_status (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), venue_id uuid not null references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(), deleted_at timestamptz, revision integer not null default 1, configured boolean not null default false, last_delivery_at timestamptz, provider text not null default 'fcm', unique(organization_id,venue_id), foreign key(venue_id,organization_id) references public.venues(id,organization_id));
alter table public.workforce_push_status enable row level security;
revoke all on public.workforce_push_status from public, anon, authenticated;
create index workforce_push_status_scope_idx on public.workforce_push_status(organization_id,venue_id,updated_at);
alter table public.shifts add foreign key(period_id) references public.schedule_periods(id), add foreign key(job_role_id) references public.job_roles(id), add foreign key(department_id) references public.departments(id), add foreign key(area_id) references public.venue_areas(id);
create unique index shift_assignments_active_unique on public.shift_assignments(shift_id,staff_id) where status='assigned' and deleted_at is null;
create unique index open_shift_offer_active_unique on public.open_shift_offers(shift_id) where status='open' and deleted_at is null;
create unique index break_entries_open_unique on public.break_entries(time_entry_id) where ends_at is null and deleted_at is null;
create unique index drop_requests_pending_unique on public.shift_drop_requests(assignment_id) where status='pending' and deleted_at is null;
create unique index pickup_requests_pending_unique on public.shift_pickup_requests(offer_id,staff_id) where status='pending' and deleted_at is null;
create index shift_assignments_staff_idx on public.shift_assignments(staff_id,shift_id) where status='assigned' and deleted_at is null;
create index shifts_workforce_window_idx on public.shifts(organization_id,starts_at,ends_at) where deleted_at is null;
create index time_off_window_idx on public.time_off_requests(staff_id,starts_at,ends_at) where status='approved' and deleted_at is null;
create index notifications_recipient_idx on public.notifications(recipient_id,created_at desc);
create index notification_outbox_ready_idx on public.notification_outbox(status,available_at);

-- Workforce permissions generated from RoleCatalog.
insert into public.app_roles(key,label,rank) values
('organization_owner', 'Organization owner', 10),
('venue_administrator', 'Venue administrator', 20),
('general_manager', 'General manager', 30),
('beverage_director', 'Beverage director', 40),
('event_manager', 'Event manager', 40),
('floor_manager', 'Floor manager', 50),
('scheduler', 'Scheduler', 50),
('department_manager', 'Department manager', 45),
('shift_lead', 'Shift lead', 55),
('employee', 'Employee', 70),
('host', 'Host', 60),
('bartender', 'Bartender', 60),
('server', 'Server', 70),
('inventory_counter', 'Inventory counter', 70),
('auditor', 'Read-only auditor', 120)
on conflict(key) do update set label=excluded.label, rank=excluded.rank;
insert into public.permissions(key,description) values
('schedule.board', 'View all authorized schedules'),
('schedule.create', 'Create draft shifts'),
('schedule.edit', 'Edit draft and published shifts'),
('schedule.retract', 'Retract schedules'),
('schedule.copy', 'Copy schedules'),
('schedule.open', 'Offer open shifts'),
('schedule.requirements', 'Manage staffing requirements'),
('schedule.drop.review', 'Review shift releases'),
('schedule.pickup.review', 'Review shift pickups'),
('schedule.swap.review', 'Review shift swaps'),
('schedule.assign', 'Assign qualified staff'),
('schedule.override', 'Document availability and rest overrides'),
('labor.read', 'View wages and labor costs'),
('labor.wage.manage', 'Manage effective wage rates'),
('schedule.availability.edit', 'Edit staff availability'),
('schedule.availability.all', 'View staff availability'),
('schedule.timeoff.review', 'Review time off'),
('schedule.templates', 'Manage schedule templates'),
('schedule.report', 'View schedule and attendance reports'),
('schedule.settings', 'Manage workforce settings'),
('staff.manage', 'Manage employment and job roles'),
('staff.certify', 'Verify qualifications and certifications'),
('schedule.self', 'View personal shifts and availability'),
('schedule.marketplace', 'Request shift releases, pickups and swaps'),
('org.read', 'View the organization profile'),
('org.update', 'Update organization identity'),
('venue.create', 'Create a venue'),
('venue.read', 'View venue profile and hours'),
('venue.update', 'Update venue settings'),
('membership.read', 'View team memberships'),
('membership.invite', 'Invite a person to the organization'),
('membership.approve', 'Approve or decline a join request'),
('membership.assign_role', 'Change an existing membership role'),
('audit.read', 'Read the audit log'),
('wine.catalog.read', 'View the wine catalog'),
('wine.catalog.write', 'Edit wine master data'),
('wine.count.execute', 'Enter inventory counts'),
('wine.count.review', 'Review count variances'),
('wine.count.approve', 'Approve count adjustments'),
('wine.movement.write', 'Move or transfer inventory'),
('wine.receive', 'Receive purchase orders'),
('wine.purchase', 'Create purchase orders and manage vendors'),
('wine.cost.read', 'View unit cost and valuation'),
('wine.allocation.manage', 'Manage club allocations and member holdings'),
('wine.list.publish', 'Publish wine list availability'),
('reservation.read', 'View reservations'),
('reservation.write', 'Create and edit reservations'),
('reservation.seat', 'Seat, waitlist, and complete covers'),
('floor.read', 'View the live floor'),
('floor.design', 'Edit floor layouts'),
('guest.read', 'View guest profiles'),
('guest.write', 'Edit guest profiles and notes'),
('schedule.read', 'View the published schedule'),
('schedule.publish', 'Publish schedules'),
('timeclock.self', 'Clock in and out for yourself'),
('timeclock.manage', 'Review and correct time entries'),
('checklist.execute', 'Complete assigned checklist items'),
('checklist.manage', 'Manage checklist templates and signoff'),
('logbook.write', 'Write manager logbook notes'),
('document.read', 'Read authorized documents'),
('document.manage', 'Manage documents and acknowledgments'),
('chat.write', 'Send team messages'),
('event.read', 'View events and BEOs'),
('event.manage', 'Manage events and BEOs'),
('sales.read', 'View sales snapshots'),
('report.operational', 'View operational reports'),
('report.financial', 'View cost, margin, and financial reports'),
('integration.manage', 'Connect external systems'),
('billing.manage', 'Manage subscription and billing'),
('settings.manage', 'Manage venue settings')
on conflict(key) do update set description=excluded.description;
-- role_permissions
insert into public.role_permissions(role_key,permission_key) values
('organization_owner', 'schedule.board'),
('organization_owner', 'schedule.create'),
('organization_owner', 'schedule.edit'),
('organization_owner', 'schedule.retract'),
('organization_owner', 'schedule.copy'),
('organization_owner', 'schedule.open'),
('organization_owner', 'schedule.requirements'),
('organization_owner', 'schedule.drop.review'),
('organization_owner', 'schedule.pickup.review'),
('organization_owner', 'schedule.swap.review'),
('organization_owner', 'schedule.assign'),
('organization_owner', 'schedule.override'),
('organization_owner', 'labor.read'),
('organization_owner', 'labor.wage.manage'),
('organization_owner', 'schedule.availability.edit'),
('organization_owner', 'schedule.availability.all'),
('organization_owner', 'schedule.timeoff.review'),
('organization_owner', 'schedule.templates'),
('organization_owner', 'schedule.report'),
('organization_owner', 'schedule.settings'),
('organization_owner', 'staff.manage'),
('organization_owner', 'staff.certify'),
('organization_owner', 'schedule.self'),
('organization_owner', 'schedule.marketplace'),
('organization_owner', 'org.read'),
('organization_owner', 'org.update'),
('organization_owner', 'venue.create'),
('organization_owner', 'venue.read'),
('organization_owner', 'venue.update'),
('organization_owner', 'membership.read'),
('organization_owner', 'membership.invite'),
('organization_owner', 'membership.approve'),
('organization_owner', 'membership.assign_role'),
('organization_owner', 'audit.read'),
('organization_owner', 'wine.catalog.read'),
('organization_owner', 'wine.catalog.write'),
('organization_owner', 'wine.count.execute'),
('organization_owner', 'wine.count.review'),
('organization_owner', 'wine.count.approve'),
('organization_owner', 'wine.movement.write'),
('organization_owner', 'wine.receive'),
('organization_owner', 'wine.purchase'),
('organization_owner', 'wine.cost.read'),
('organization_owner', 'wine.allocation.manage'),
('organization_owner', 'wine.list.publish'),
('organization_owner', 'reservation.read'),
('organization_owner', 'reservation.write'),
('organization_owner', 'reservation.seat'),
('organization_owner', 'floor.read'),
('organization_owner', 'floor.design'),
('organization_owner', 'guest.read'),
('organization_owner', 'guest.write'),
('organization_owner', 'schedule.read'),
('organization_owner', 'schedule.publish'),
('organization_owner', 'timeclock.self'),
('organization_owner', 'timeclock.manage'),
('organization_owner', 'checklist.execute'),
('organization_owner', 'checklist.manage'),
('organization_owner', 'logbook.write'),
('organization_owner', 'document.read'),
('organization_owner', 'document.manage'),
('organization_owner', 'chat.write'),
('organization_owner', 'event.read'),
('organization_owner', 'event.manage'),
('organization_owner', 'sales.read'),
('organization_owner', 'report.operational'),
('organization_owner', 'report.financial'),
('organization_owner', 'integration.manage'),
('organization_owner', 'billing.manage'),
('organization_owner', 'settings.manage'),
('venue_administrator', 'schedule.board'),
('venue_administrator', 'schedule.create'),
('venue_administrator', 'schedule.edit'),
('venue_administrator', 'schedule.retract'),
('venue_administrator', 'schedule.copy'),
('venue_administrator', 'schedule.open'),
('venue_administrator', 'schedule.requirements'),
('venue_administrator', 'schedule.drop.review'),
('venue_administrator', 'schedule.pickup.review'),
('venue_administrator', 'schedule.swap.review'),
('venue_administrator', 'schedule.assign'),
('venue_administrator', 'schedule.override'),
('venue_administrator', 'labor.read'),
('venue_administrator', 'labor.wage.manage'),
('venue_administrator', 'schedule.availability.edit'),
('venue_administrator', 'schedule.availability.all'),
('venue_administrator', 'schedule.timeoff.review'),
('venue_administrator', 'schedule.templates'),
('venue_administrator', 'schedule.report'),
('venue_administrator', 'schedule.settings'),
('venue_administrator', 'staff.manage'),
('venue_administrator', 'staff.certify'),
('venue_administrator', 'schedule.self'),
('venue_administrator', 'schedule.marketplace'),
('venue_administrator', 'org.read'),
('venue_administrator', 'venue.create'),
('venue_administrator', 'venue.read'),
('venue_administrator', 'venue.update'),
('venue_administrator', 'membership.read'),
('venue_administrator', 'membership.invite'),
('venue_administrator', 'membership.approve'),
('venue_administrator', 'membership.assign_role'),
('venue_administrator', 'audit.read'),
('venue_administrator', 'wine.catalog.read'),
('venue_administrator', 'wine.catalog.write'),
('venue_administrator', 'wine.count.execute'),
('venue_administrator', 'wine.count.review'),
('venue_administrator', 'wine.count.approve'),
('venue_administrator', 'wine.movement.write'),
('venue_administrator', 'wine.receive'),
('venue_administrator', 'wine.purchase'),
('venue_administrator', 'wine.cost.read'),
('venue_administrator', 'wine.allocation.manage'),
('venue_administrator', 'wine.list.publish'),
('venue_administrator', 'reservation.read'),
('venue_administrator', 'reservation.write'),
('venue_administrator', 'reservation.seat'),
('venue_administrator', 'floor.read'),
('venue_administrator', 'floor.design'),
('venue_administrator', 'guest.read'),
('venue_administrator', 'guest.write'),
('venue_administrator', 'schedule.read'),
('venue_administrator', 'schedule.publish'),
('venue_administrator', 'timeclock.self'),
('venue_administrator', 'timeclock.manage'),
('venue_administrator', 'checklist.execute'),
('venue_administrator', 'checklist.manage'),
('venue_administrator', 'logbook.write'),
('venue_administrator', 'document.read'),
('venue_administrator', 'document.manage'),
('venue_administrator', 'chat.write'),
('venue_administrator', 'event.read'),
('venue_administrator', 'event.manage'),
('venue_administrator', 'sales.read'),
('venue_administrator', 'report.operational'),
('venue_administrator', 'report.financial'),
('venue_administrator', 'integration.manage'),
('venue_administrator', 'settings.manage'),
('general_manager', 'org.read'),
('general_manager', 'venue.read'),
('general_manager', 'venue.update'),
('general_manager', 'membership.read'),
('general_manager', 'membership.invite'),
('general_manager', 'membership.approve'),
('general_manager', 'audit.read'),
('general_manager', 'wine.catalog.read'),
('general_manager', 'wine.catalog.write'),
('general_manager', 'wine.count.execute'),
('general_manager', 'wine.count.review'),
('general_manager', 'wine.count.approve'),
('general_manager', 'wine.movement.write'),
('general_manager', 'wine.receive'),
('general_manager', 'wine.purchase'),
('general_manager', 'wine.cost.read'),
('general_manager', 'wine.allocation.manage'),
('general_manager', 'wine.list.publish'),
('general_manager', 'reservation.read'),
('general_manager', 'reservation.write'),
('general_manager', 'reservation.seat'),
('general_manager', 'floor.read'),
('general_manager', 'floor.design'),
('general_manager', 'guest.read'),
('general_manager', 'guest.write'),
('general_manager', 'schedule.read'),
('general_manager', 'schedule.publish'),
('general_manager', 'timeclock.self'),
('general_manager', 'timeclock.manage'),
('general_manager', 'checklist.execute'),
('general_manager', 'checklist.manage'),
('general_manager', 'logbook.write'),
('general_manager', 'document.read'),
('general_manager', 'document.manage'),
('general_manager', 'chat.write'),
('general_manager', 'event.read'),
('general_manager', 'event.manage'),
('general_manager', 'sales.read'),
('general_manager', 'report.operational'),
('general_manager', 'report.financial'),
('general_manager', 'settings.manage'),
('general_manager', 'schedule.self'),
('general_manager', 'schedule.marketplace'),
('general_manager', 'schedule.board'),
('general_manager', 'schedule.create'),
('general_manager', 'schedule.edit'),
('general_manager', 'schedule.retract'),
('general_manager', 'schedule.copy'),
('general_manager', 'schedule.open'),
('general_manager', 'schedule.requirements'),
('general_manager', 'schedule.drop.review'),
('general_manager', 'schedule.pickup.review'),
('general_manager', 'schedule.swap.review'),
('general_manager', 'schedule.assign'),
('general_manager', 'schedule.availability.edit'),
('general_manager', 'schedule.availability.all'),
('general_manager', 'schedule.timeoff.review'),
('general_manager', 'schedule.templates'),
('general_manager', 'schedule.report'),
('general_manager', 'schedule.override'),
('general_manager', 'labor.read'),
('general_manager', 'labor.wage.manage'),
('general_manager', 'schedule.settings'),
('general_manager', 'staff.manage'),
('general_manager', 'staff.certify'),
('beverage_director', 'org.read'),
('beverage_director', 'venue.read'),
('beverage_director', 'membership.read'),
('beverage_director', 'wine.catalog.read'),
('beverage_director', 'wine.catalog.write'),
('beverage_director', 'wine.count.execute'),
('beverage_director', 'wine.count.review'),
('beverage_director', 'wine.count.approve'),
('beverage_director', 'wine.movement.write'),
('beverage_director', 'wine.receive'),
('beverage_director', 'wine.purchase'),
('beverage_director', 'wine.cost.read'),
('beverage_director', 'wine.allocation.manage'),
('beverage_director', 'wine.list.publish'),
('beverage_director', 'reservation.read'),
('beverage_director', 'guest.read'),
('beverage_director', 'floor.read'),
('beverage_director', 'document.read'),
('beverage_director', 'chat.write'),
('beverage_director', 'event.read'),
('beverage_director', 'checklist.execute'),
('beverage_director', 'logbook.write'),
('beverage_director', 'timeclock.self'),
('beverage_director', 'report.operational'),
('beverage_director', 'report.financial'),
('beverage_director', 'schedule.self'),
('beverage_director', 'schedule.marketplace'),
('beverage_director', 'schedule.board'),
('beverage_director', 'schedule.create'),
('beverage_director', 'schedule.edit'),
('beverage_director', 'schedule.retract'),
('beverage_director', 'schedule.copy'),
('beverage_director', 'schedule.open'),
('beverage_director', 'schedule.requirements'),
('beverage_director', 'schedule.drop.review'),
('beverage_director', 'schedule.pickup.review'),
('beverage_director', 'schedule.swap.review'),
('beverage_director', 'schedule.assign'),
('beverage_director', 'schedule.availability.edit'),
('beverage_director', 'schedule.availability.all'),
('beverage_director', 'schedule.timeoff.review'),
('beverage_director', 'schedule.templates'),
('beverage_director', 'schedule.report'),
('event_manager', 'org.read'),
('event_manager', 'venue.read'),
('event_manager', 'membership.read'),
('event_manager', 'wine.catalog.read'),
('event_manager', 'wine.movement.write'),
('event_manager', 'reservation.read'),
('event_manager', 'reservation.write'),
('event_manager', 'floor.read'),
('event_manager', 'guest.read'),
('event_manager', 'guest.write'),
('event_manager', 'event.read'),
('event_manager', 'event.manage'),
('event_manager', 'document.read'),
('event_manager', 'document.manage'),
('event_manager', 'chat.write'),
('event_manager', 'checklist.execute'),
('event_manager', 'checklist.manage'),
('event_manager', 'logbook.write'),
('event_manager', 'schedule.read'),
('event_manager', 'report.operational'),
('event_manager', 'timeclock.self'),
('event_manager', 'schedule.self'),
('event_manager', 'schedule.marketplace'),
('event_manager', 'schedule.board'),
('event_manager', 'schedule.create'),
('event_manager', 'schedule.edit'),
('event_manager', 'schedule.retract'),
('event_manager', 'schedule.copy'),
('event_manager', 'schedule.open'),
('event_manager', 'schedule.requirements'),
('event_manager', 'schedule.drop.review'),
('event_manager', 'schedule.pickup.review'),
('event_manager', 'schedule.swap.review'),
('event_manager', 'schedule.assign'),
('event_manager', 'schedule.availability.edit'),
('event_manager', 'schedule.availability.all'),
('event_manager', 'schedule.timeoff.review'),
('event_manager', 'schedule.templates'),
('event_manager', 'schedule.report'),
('floor_manager', 'org.read'),
('floor_manager', 'venue.read'),
('floor_manager', 'reservation.read'),
('floor_manager', 'reservation.write'),
('floor_manager', 'reservation.seat'),
('floor_manager', 'floor.read'),
('floor_manager', 'floor.design'),
('floor_manager', 'guest.read'),
('floor_manager', 'guest.write'),
('floor_manager', 'schedule.read'),
('floor_manager', 'chat.write'),
('floor_manager', 'checklist.execute'),
('floor_manager', 'checklist.manage'),
('floor_manager', 'logbook.write'),
('floor_manager', 'document.read'),
('floor_manager', 'event.read'),
('floor_manager', 'wine.catalog.read'),
('floor_manager', 'timeclock.self'),
('floor_manager', 'timeclock.manage'),
('floor_manager', 'report.operational'),
('floor_manager', 'schedule.self'),
('floor_manager', 'schedule.marketplace'),
('floor_manager', 'schedule.board'),
('floor_manager', 'schedule.create'),
('floor_manager', 'schedule.edit'),
('floor_manager', 'schedule.retract'),
('floor_manager', 'schedule.copy'),
('floor_manager', 'schedule.open'),
('floor_manager', 'schedule.requirements'),
('floor_manager', 'schedule.drop.review'),
('floor_manager', 'schedule.pickup.review'),
('floor_manager', 'schedule.swap.review'),
('floor_manager', 'schedule.assign'),
('floor_manager', 'schedule.availability.edit'),
('floor_manager', 'schedule.availability.all'),
('floor_manager', 'schedule.timeoff.review'),
('floor_manager', 'schedule.templates'),
('floor_manager', 'schedule.report'),
('scheduler', 'org.read'),
('scheduler', 'venue.read'),
('scheduler', 'membership.read'),
('scheduler', 'schedule.read'),
('scheduler', 'schedule.publish'),
('scheduler', 'timeclock.manage'),
('scheduler', 'timeclock.self'),
('scheduler', 'document.read'),
('scheduler', 'chat.write'),
('scheduler', 'report.operational'),
('scheduler', 'schedule.self'),
('scheduler', 'schedule.marketplace'),
('scheduler', 'schedule.board'),
('scheduler', 'schedule.create'),
('scheduler', 'schedule.edit'),
('scheduler', 'schedule.retract'),
('scheduler', 'schedule.copy'),
('scheduler', 'schedule.open'),
('scheduler', 'schedule.requirements'),
('scheduler', 'schedule.drop.review'),
('scheduler', 'schedule.pickup.review'),
('scheduler', 'schedule.swap.review'),
('scheduler', 'schedule.assign'),
('scheduler', 'schedule.availability.edit'),
('scheduler', 'schedule.availability.all'),
('scheduler', 'schedule.timeoff.review'),
('scheduler', 'schedule.templates'),
('scheduler', 'schedule.report'),
('scheduler', 'schedule.override'),
('scheduler', 'labor.read'),
('scheduler', 'labor.wage.manage'),
('scheduler', 'schedule.settings'),
('scheduler', 'staff.manage'),
('scheduler', 'staff.certify'),
('department_manager', 'org.read'),
('department_manager', 'venue.read'),
('department_manager', 'schedule.self'),
('department_manager', 'schedule.marketplace'),
('department_manager', 'timeclock.self'),
('department_manager', 'chat.write'),
('department_manager', 'document.read'),
('department_manager', 'schedule.board'),
('department_manager', 'schedule.create'),
('department_manager', 'schedule.edit'),
('department_manager', 'schedule.retract'),
('department_manager', 'schedule.copy'),
('department_manager', 'schedule.open'),
('department_manager', 'schedule.requirements'),
('department_manager', 'schedule.drop.review'),
('department_manager', 'schedule.pickup.review'),
('department_manager', 'schedule.swap.review'),
('department_manager', 'schedule.assign'),
('department_manager', 'schedule.availability.edit'),
('department_manager', 'schedule.availability.all'),
('department_manager', 'schedule.timeoff.review'),
('department_manager', 'schedule.templates'),
('department_manager', 'schedule.report'),
('department_manager', 'schedule.override'),
('shift_lead', 'org.read'),
('shift_lead', 'venue.read'),
('shift_lead', 'schedule.self'),
('shift_lead', 'schedule.marketplace'),
('shift_lead', 'timeclock.self'),
('shift_lead', 'chat.write'),
('shift_lead', 'document.read'),
('shift_lead', 'schedule.board'),
('shift_lead', 'schedule.report'),
('employee', 'org.read'),
('employee', 'venue.read'),
('employee', 'schedule.self'),
('employee', 'schedule.marketplace'),
('employee', 'timeclock.self'),
('employee', 'chat.write'),
('employee', 'document.read'),
('host', 'org.read'),
('host', 'venue.read'),
('host', 'reservation.read'),
('host', 'reservation.write'),
('host', 'reservation.seat'),
('host', 'floor.read'),
('host', 'guest.read'),
('host', 'guest.write'),
('host', 'chat.write'),
('host', 'document.read'),
('host', 'wine.catalog.read'),
('host', 'timeclock.self'),
('host', 'event.read'),
('host', 'schedule.self'),
('host', 'schedule.marketplace'),
('bartender', 'org.read'),
('bartender', 'venue.read'),
('bartender', 'wine.catalog.read'),
('bartender', 'wine.count.execute'),
('bartender', 'wine.movement.write'),
('bartender', 'chat.write'),
('bartender', 'checklist.execute'),
('bartender', 'timeclock.self'),
('bartender', 'document.read'),
('bartender', 'floor.read'),
('bartender', 'schedule.self'),
('bartender', 'schedule.marketplace'),
('server', 'org.read'),
('server', 'venue.read'),
('server', 'reservation.read'),
('server', 'floor.read'),
('server', 'guest.read'),
('server', 'chat.write'),
('server', 'checklist.execute'),
('server', 'wine.catalog.read'),
('server', 'timeclock.self'),
('server', 'document.read'),
('server', 'schedule.self'),
('server', 'schedule.marketplace'),
('inventory_counter', 'org.read'),
('inventory_counter', 'venue.read'),
('inventory_counter', 'wine.catalog.read'),
('inventory_counter', 'wine.count.execute'),
('inventory_counter', 'checklist.execute'),
('inventory_counter', 'timeclock.self'),
('inventory_counter', 'document.read'),
('inventory_counter', 'schedule.self'),
('inventory_counter', 'schedule.marketplace'),
('inventory_counter', 'chat.write'),
('auditor', 'org.read'),
('auditor', 'venue.read'),
('auditor', 'membership.read'),
('auditor', 'audit.read'),
('auditor', 'wine.catalog.read'),
('auditor', 'wine.cost.read'),
('auditor', 'reservation.read'),
('auditor', 'floor.read'),
('auditor', 'guest.read'),
('auditor', 'schedule.read'),
('auditor', 'document.read'),
('auditor', 'event.read'),
('auditor', 'sales.read'),
('auditor', 'report.operational'),
('auditor', 'report.financial'),
('auditor', 'schedule.board'),
('auditor', 'schedule.report'),
('auditor', 'labor.read')
on conflict do nothing;
-- Only RPCs mutate workforce data. RLS still applies to all client reads.
alter table public.shifts add column created_at timestamptz not null default now();
alter table public.shifts drop constraint shifts_status_check;
alter table public.shifts add constraint shifts_status_check check(status in ('draft','published','retracted'));
alter table public.shifts add constraint workforce_shift_duration check(ends_at <= starts_at + interval '24 hours');
alter table public.time_entries add constraint workforce_clock_window check(clock_out is null or clock_out >= clock_in);
create unique index workforce_one_open_clock on public.time_entries(user_id) where clock_out is null and deleted_at is null;
alter table public.schedule_periods add column department_id uuid references public.departments(id);
alter table public.schedule_templates add column department_id uuid references public.departments(id);
create table public.workforce_department_managers(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 venue_id uuid not null, user_id uuid not null references public.profiles(id),
 department_id uuid not null references public.departments(id), created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), created_by uuid references public.profiles(id) default auth.uid(),
 deleted_at timestamptz, revision integer not null default 1,
 foreign key(venue_id,organization_id) references public.venues(id,organization_id),
 unique(venue_id,user_id,department_id));
alter table public.workforce_department_managers enable row level security;
revoke all on public.workforce_department_managers from public,anon,authenticated;

create function public.wf_can(o uuid,v uuid,p text,d uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
 select public.is_platform_admin() or exists(
 select 1 from public.memberships m where m.organization_id=o and m.user_id=auth.uid()
 and m.status='active' and m.deleted_at is null and (m.venue_id is null or m.venue_id=v)
 and public.membership_allows(m.id,m.role_key,p)
 and (m.role_key <> 'department_manager' or
 p in ('org.read','venue.read','schedule.self','schedule.marketplace','timeclock.self','chat.write','document.read')
 or (d is not null and exists(select 1 from public.workforce_department_managers dm
 where dm.organization_id=o and dm.venue_id=v and dm.user_id=m.user_id and dm.department_id=d and dm.deleted_at is null)))
 );
$$;
create function public.wf_self(o uuid,s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_profiles where id=s and organization_id=o
 and user_id=auth.uid() and deleted_at is null);
$$;
create function public.wf_staff_department(o uuid,v uuid,s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.wf_can(o,v,'schedule.board') or exists(
 select 1 from public.staff_role_assignments a join public.job_roles r on r.id=a.job_role_id
 where a.staff_id=s and a.organization_id=o and a.venue_id=v and a.deleted_at is null
 and public.wf_can(o,v,'schedule.board',r.department_id));
$$;
create function public.wf_shift_visible(s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.shifts h where h.id=s and h.deleted_at is null and
 (public.wf_can(h.organization_id,h.venue_id,'schedule.board',h.department_id)
 or (h.status='published' and public.wf_can(h.organization_id,h.venue_id,'schedule.self') and
 (exists(select 1 from public.shift_assignments a where a.shift_id=h.id and a.status='assigned' and a.deleted_at is null
 and public.wf_self(h.organization_id,a.staff_id))
 or exists(select 1 from public.open_shift_offers f where f.shift_id=h.id and f.status='open'
 and f.deleted_at is null and f.closes_at>now())))));
$$;
create function public.wf_read(t text,j jsonb) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare o uuid := (j->>'organization_id')::uuid; v uuid := (j->>'venue_id')::uuid;
 s uuid := (j->>'staff_id')::uuid; h uuid := (j->>'shift_id')::uuid;
begin
 if auth.uid() is null then return false; end if;
 if v is not null and not public.has_scoped_permission(o,v,'venue.read') then return false; end if;
 if v is null and not public.has_permission(o,'org.read') then return false; end if;
 if t in ('notification_outbox','workforce_commands','push_devices') then return false; end if;
 if t='employee_wage_rates' then return public.wf_can(o,v,'labor.read'); end if;
 if t='notifications' then return (j->>'recipient_id')::uuid=auth.uid(); end if;
 if t='staff_messages' then return (j->>'sender_id')::uuid=auth.uid()
 or (j->>'recipient_id')::uuid=auth.uid() or
 ((j->>'recipient_id') is null and (h is null or public.wf_shift_visible(h))); end if;
 if t='staff_profiles' then
 return (j->>'user_id')::uuid=auth.uid() or exists(
 select 1 from public.venues x where x.organization_id=o and x.deleted_at is null
 and public.wf_staff_department(o,x.id,(j->>'id')::uuid)); end if;
 if t in ('staff_qualifications','staff_certifications','time_off_balances') then
 return public.wf_self(o,s) or exists(select 1 from public.venues x where x.organization_id=o
 and x.deleted_at is null and public.wf_staff_department(o,x.id,s)); end if;
 if t in ('staff_availability_rules','staff_availability_exceptions','time_off_requests') then
 return public.wf_self(o,s) or public.wf_staff_department(o,v,s); end if;
 if t in ('shift_drop_requests','shift_pickup_requests','shift_swap_requests') then
 return public.wf_self(o,s) or public.wf_self(o,(j->>'other_staff_id')::uuid)
 or exists(select 1 from public.shifts x where x.id=h
 and public.wf_can(o,v,'schedule.board',x.department_id)); end if;
 if t='clock_attestations' then return public.wf_self(o,s) or public.wf_can(o,v,'timeclock.manage'); end if;
 if t='time_entries' then return (j->>'user_id')::uuid=auth.uid() or public.wf_can(o,v,'timeclock.manage'); end if;
 if t in ('break_entries','time_entry_corrections') then
 return exists(select 1 from public.time_entries x where x.id=(j->>'time_entry_id')::uuid
 and (x.user_id=auth.uid() or public.wf_can(o,v,'timeclock.manage'))); end if;
 if t='shifts' then return public.wf_shift_visible((j->>'id')::uuid); end if;
 if t='shift_assignments' then return public.wf_self(o,s) or exists(
 select 1 from public.shifts x where x.id=h and public.wf_can(o,v,'schedule.board',x.department_id)); end if;
 if t='staff_role_assignments' then return public.wf_self(o,s) or public.wf_staff_department(o,v,s); end if;
 if t='job_roles' then return public.wf_can(o,v,'schedule.self')
 or public.wf_can(o,v,'schedule.board',(j->>'department_id')::uuid); end if;
 if t in ('venue_areas','departments','workforce_settings','workforce_push_status') then
 return public.wf_can(o,v,'schedule.self') or public.has_scoped_permission(o,v,'schedule.board'); end if;
 if t='workforce_department_managers' then return (j->>'user_id')::uuid=auth.uid()
 or public.wf_can(o,v,'staff.manage'); end if;
 if t='shift_notes' then return public.wf_shift_visible(h) and
 ((j->>'staff_visible')::boolean or exists(select 1 from public.shifts x where x.id=h
 and public.wf_can(o,v,'schedule.board',x.department_id))); end if;
 if t in ('shift_break_rules','open_shift_offers') then return public.wf_shift_visible(h); end if;
 if t in ('labor_targets','labor_forecasts') then return public.wf_can(o,v,'labor.read'); end if;
 if t='shift_change_events' then
 if j->>'entity_type'='employee_wage_rates' then return public.wf_can(o,v,'labor.read'); end if;
 return public.wf_can(o,v,'schedule.report'); end if;
 if t='shift_requirements' then return public.wf_can(o,v,'schedule.board',
 (select department_id from public.job_roles where id=(j->>'job_role_id')::uuid)); end if;
 return public.wf_can(o,v,'schedule.board',(j->>'department_id')::uuid);
end; $$;

-- Every referenced workforce/business record must belong to the row's tenant and venue.
create function public.wf_integrity() returns trigger language plpgsql security definer set search_path='' as $$
declare j jsonb:=to_jsonb(new); ref record; r jsonb; col text; parent text;
begin
 if tg_op='UPDATE' then
 if new.organization_id<>old.organization_id or j->>'venue_id' is distinct from to_jsonb(old)->>'venue_id'
 or new.created_by is distinct from old.created_by then raise exception 'immutable_scope'; end if;
 new.revision:=old.revision+1; new.updated_at:=now();
 end if;
 for ref in select a.attname as col,c.confrelid::regclass as parent
 from pg_catalog.pg_constraint c join pg_catalog.pg_attribute a
 on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
 where c.conrelid=tg_relid and c.contype='f' and array_length(c.conkey,1)=1
 and a.attname not in ('organization_id','venue_id','created_by','user_id','recipient_id','sender_id','reviewed_by','verified_by')
 loop
 col:=ref.col; parent:=ref.parent::text;
 if nullif(j->>col,'') is not null then
 execute format('select to_jsonb(x) from %s x where id=$1',ref.parent) into r using (j->>col)::uuid;
 if r is null or r->>'organization_id' is distinct from j->>'organization_id'
 or (r ? 'venue_id' and r->>'venue_id' is not null and r->>'venue_id' is distinct from j->>'venue_id')
 or r->>'deleted_at' is not null then raise exception 'cross_scope_reference: %',col; end if;
 end if;
 end loop;
 if tg_table_name='shifts' then
 if new.job_role_id is not null and exists(select 1 from public.job_roles r where r.id=new.job_role_id
 and (r.key<>new.role_key or r.department_id is distinct from new.department_id)) then
 raise exception 'shift_role_department_mismatch'; end if;
 if new.period_id is not null and not exists(select 1 from public.schedule_periods p
 join public.venues v on v.id=new.venue_id where p.id=new.period_id
 and (new.starts_at at time zone v.timezone)::date>=p.starts_on
 and (new.ends_at at time zone v.timezone)::date<=p.ends_on) then raise exception 'outside_schedule_period'; end if;
 if new.period_id is not null and exists(select 1 from public.schedule_periods p where p.id=new.period_id
 and p.department_id is not null and p.department_id is distinct from new.department_id) then raise exception 'period_department_mismatch'; end if;
 end if;
 return new;
end; $$;
create function public.wf_audit() returns trigger language plpgsql security definer set search_path='' as $$
declare j jsonb:=to_jsonb(new); previous jsonb; h uuid;
begin
 if tg_op='UPDATE' then previous:=to_jsonb(old); end if;
 h:=case when tg_table_name='shifts' then new.id else (j->>'shift_id')::uuid end;
 insert into public.shift_change_events(organization_id,venue_id,shift_id,entity_type,entity_id,action,source,previous_state,next_state)
 values(new.organization_id,coalesce((j->>'venue_id')::uuid,
 nullif(current_setting('app.workforce_venue',true),'')::uuid),h,tg_table_name,new.id,tg_op,
 coalesce(nullif(current_setting('app.workforce_action',true),''),'import'),previous,j);
 return new;
end; $$;
create function public.wf_immutable() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'workforce_history_immutable'; end; $$;

do $$
declare t text;
begin
 foreach t in array array['venue_areas','departments','job_roles','staff_profiles','staff_role_assignments','staff_qualifications','staff_certifications','employee_wage_rates','staff_availability_rules','staff_availability_exceptions','time_off_balances','time_off_requests','schedule_periods','schedule_versions','shift_assignments','shift_break_rules','shift_notes','shift_requirements','open_shift_offers','shift_drop_requests','shift_pickup_requests','shift_swap_requests','shift_change_events','schedule_templates','schedule_template_shifts','labor_targets','labor_forecasts','break_entries','time_entry_corrections','clock_attestations','notifications','staff_messages','workforce_settings','workforce_commands','push_devices','notification_outbox','workforce_push_status','workforce_department_managers','shifts','time_entries'] loop
 execute format('grant select on public.%I to authenticated',t);
 if t='shifts' then execute 'drop policy if exists shifts_select on public.shifts'; end if;
 if t='time_entries' then execute 'drop policy if exists time_entries_select on public.time_entries'; end if;
 execute format('create policy wf_select on public.%I for select to authenticated using(deleted_at is null and public.wf_read(%L,to_jsonb(%I)))',t,t,t);
 if t not in ('shift_change_events','schedule_versions','workforce_commands','notification_outbox','workforce_push_status','push_devices') then
 execute format('create trigger wf_integrity before insert or update on public.%I for each row execute function public.wf_integrity()',t);
 end if;
 if t not in ('shift_change_events','schedule_versions','workforce_commands','notification_outbox','workforce_push_status','push_devices','notifications') then
 execute format('create trigger wf_audit after insert or update on public.%I for each row execute function public.wf_audit()',t);
 end if;
 end loop;
 foreach t in array array['shift_change_events','schedule_versions','time_entry_corrections','workforce_commands'] loop
 execute format('create trigger wf_immutable before update or delete on public.%I for each row execute function public.wf_immutable()',t);
 end loop;
end; $$;
-- Helpers used by RLS are read-only; all other internal functions stay private.
revoke all on function public.wf_integrity(),public.wf_audit(),public.wf_immutable() from public,anon,authenticated;
revoke all on function public.wf_can(uuid,uuid,text,uuid),public.wf_self(uuid,uuid),
public.wf_staff_department(uuid,uuid,uuid),public.wf_shift_visible(uuid),public.wf_read(text,jsonb) from public,anon;
grant execute on function public.wf_can(uuid,uuid,text,uuid),public.wf_self(uuid,uuid),
public.wf_staff_department(uuid,uuid,uuid),public.wf_shift_visible(uuid),public.wf_read(text,jsonb) to authenticated;
create function public.wf_require(o uuid,v uuid,p text,d uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.wf_can(o,v,p,d)
 or not exists(select 1 from public.venues where id=v and organization_id=o and deleted_at is null) then
 raise exception 'workforce_permission_denied' using errcode='42501'; end if;
end; $$;
create function public.wf_eligible(h uuid,s uuid,override_reason text default null,ignore_shift uuid default null)
returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare x public.shifts; staff public.staff_profiles; r public.job_roles; zone text;
 local_start timestamp; local_end timestamp; soft boolean:=false; week_start timestamptz; minutes numeric;
begin
 select * into strict x from public.shifts where id=h and deleted_at is null;
 select * into strict staff from public.staff_profiles where id=s and organization_id=x.organization_id and deleted_at is null;
 select timezone into zone from public.venues where id=x.venue_id;
 if staff.employment_status<>'active' or not exists(select 1 from public.memberships m
 where m.user_id=staff.user_id and m.organization_id=x.organization_id and m.status='active'
 and m.deleted_at is null and (m.venue_id is null or m.venue_id=x.venue_id)) then raise exception 'staff_not_authorized'; end if;
 select * into strict r from public.job_roles where id=x.job_role_id and enabled and deleted_at is null;
 if not exists(select 1 from public.staff_role_assignments a where a.staff_id=s and a.job_role_id=r.id and a.deleted_at is null)
 then raise exception 'staff_role_not_qualified'; end if;
 if exists(select 1 from unnest(r.required_skills) k where not exists(select 1 from public.staff_qualifications q
 where q.staff_id=s and q.skill_key=k and q.approved and q.deleted_at is null))
 then raise exception 'required_skill_missing'; end if;
 local_start:=x.starts_at at time zone zone; local_end:=x.ends_at at time zone zone;
 if exists(select 1 from unnest(r.required_certifications) k where not exists(select 1 from public.staff_certifications c
 where c.staff_id=s and c.certification_key=k and c.status='verified' and c.expires_on>=local_end::date and c.deleted_at is null))
 then raise exception 'required_certification_missing'; end if;
 if exists(select 1 from public.shift_assignments a join public.shifts b on b.id=a.shift_id
 where a.staff_id=s and a.status='assigned' and a.deleted_at is null and b.deleted_at is null
 and b.status<>'retracted' and b.id<>h and (ignore_shift is null or b.id<>ignore_shift)
 and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(x.starts_at,x.ends_at,'[)'))
 then raise exception 'assignment_overlap'; end if;
 if exists(select 1 from public.time_off_requests t where t.staff_id=s and t.status='approved' and t.deleted_at is null
 and tstzrange(t.starts_at,t.ends_at,'[)') && tstzrange(x.starts_at,x.ends_at,'[)'))
 then raise exception 'approved_time_off_conflict'; end if;
 soft:=exists(select 1 from public.shift_assignments a join public.shifts b on b.id=a.shift_id
 where a.staff_id=s and a.status='assigned' and a.deleted_at is null and b.deleted_at is null
 and b.status<>'retracted' and b.id<>h and (ignore_shift is null or b.id<>ignore_shift)
 and ((b.ends_at<=x.starts_at and x.starts_at-b.ends_at<make_interval(mins=>staff.minimum_rest_minutes))
 or (b.starts_at>=x.ends_at and b.starts_at-x.ends_at<make_interval(mins=>staff.minimum_rest_minutes))));
 week_start:=date_trunc('week',local_start) at time zone zone;
 select coalesce(sum(extract(epoch from least(b.ends_at,week_start+interval '7 days')-
 greatest(b.starts_at,week_start))/60),0) into minutes
 from public.shift_assignments a join public.shifts b on b.id=a.shift_id where a.staff_id=s
 and a.status='assigned' and a.deleted_at is null and b.deleted_at is null and b.status<>'retracted'
 and b.id<>h and (ignore_shift is null or b.id<>ignore_shift) and b.starts_at<week_start+interval '7 days' and b.ends_at>week_start;
 soft:=soft or minutes+extract(epoch from x.ends_at-x.starts_at)/60>staff.weekly_limit_minutes;
 soft:=soft or exists(select 1 from public.staff_availability_exceptions e where e.staff_id=s and e.venue_id=x.venue_id
 and not e.available and e.deleted_at is null and tstzrange(e.starts_at,e.ends_at,'[)') && tstzrange(x.starts_at,x.ends_at,'[)'));
 -- Recurrence expands local dates, including the prior day for overnight rules.
 soft:=soft or exists(select 1 from public.staff_availability_rules a,
 generate_series(local_start::date-1,local_end::date,interval '1 day') day
 where a.staff_id=s and a.venue_id=x.venue_id and not a.available and a.deleted_at is null
 and extract(isodow from day)=a.weekday and day::date>=a.valid_from
 and (a.valid_until is null or day::date<=a.valid_until)
 and tsrange(day::date+a.starts_local,day::date+a.ends_local+
 case when a.ends_local<=a.starts_local then interval '1 day' else interval '0' end,'[)')
 && tsrange(local_start,local_end,'[)'));
 if exists(select 1 from public.staff_availability_rules where staff_id=s and venue_id=x.venue_id and available and deleted_at is null)
 and not exists(select 1 from public.staff_availability_rules a,
 generate_series(local_start::date-1,local_end::date,interval '1 day') day
 where a.staff_id=s and a.venue_id=x.venue_id and a.available and a.deleted_at is null
 and extract(isodow from day)=a.weekday and day::date>=a.valid_from and (a.valid_until is null or day::date<=a.valid_until)
 and day::date+a.starts_local<=local_start and day::date+a.ends_local+
 case when a.ends_local<=a.starts_local then interval '1 day' else interval '0' end>=local_end)
 and not exists(select 1 from public.staff_availability_exceptions e where e.staff_id=s and e.venue_id=x.venue_id
 and e.available and e.deleted_at is null and e.starts_at<=x.starts_at and e.ends_at>=x.ends_at)
 then soft:=true; end if;
 if soft and (char_length(coalesce(override_reason,''))<5 or not public.wf_can(x.organization_id,x.venue_id,'schedule.override',x.department_id))
 then raise exception 'availability_rest_or_hours_conflict'; end if;
end; $$;

create function public.wf_notify(o uuid,v uuid,u uuid,title text,body text,h uuid default null)
returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare n uuid;
begin
 if u is null then return; end if;
 insert into public.notifications(organization_id,venue_id,recipient_id,kind,title,body,shift_id)
 values(o,v,u,'schedule',title,body,h) returning id into n;
 insert into public.notification_outbox(organization_id,venue_id,notification_id) values(o,v,n);
end; $$;
create function public.wf_notify_shift(h uuid,title text) returns void
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare a record; x public.shifts;
begin
 select * into x from public.shifts where id=h;
 for a in select p.user_id from public.shift_assignments a join public.staff_profiles p on p.id=a.staff_id
 where a.shift_id=h and a.status='assigned' and a.deleted_at is null loop
 perform public.wf_notify(x.organization_id,x.venue_id,a.user_id,title,'Open your schedule to review the change.',h);
 end loop;
end; $$;

-- Metadata writes use a fixed table/field allowlist; protected operational states have dedicated commands.
create function public.wf_save(o uuid,v uuid,p jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare t text:=p->>'table'; data jsonb:=p->'data'; v_id uuid:=coalesce((p->>'id')::uuid,gen_random_uuid());
 previous jsonb; result jsonb; allowed text[]; permission text; orgwide boolean:=false; self_allowed boolean:=false;
 dept uuid; staff uuid; col text; cols text; vals text;
begin
 case t
 when 'departments' then allowed:=array['name','code']; permission:='staff.manage';
 when 'venue_areas' then allowed:=array['name','code','location_id']; permission:='staff.manage';
 when 'job_roles' then allowed:=array['name','key','department_id','required_skills','required_certifications','enabled']; permission:='staff.manage';
 when 'staff_profiles' then allowed:=array['user_id','display_name','employment_status','employment_type','weekly_limit_minutes','minimum_rest_minutes']; permission:='staff.manage'; orgwide:=true;
 when 'staff_role_assignments' then allowed:=array['staff_id','job_role_id']; permission:='staff.manage';
 when 'staff_qualifications' then allowed:=array['staff_id','skill_key','approved']; permission:='staff.certify'; orgwide:=true;
 when 'staff_certifications' then allowed:=array['staff_id','certification_key','expires_on','status','evidence_path']; permission:='staff.certify'; orgwide:=true;
 when 'employee_wage_rates' then allowed:=array['staff_id','job_role_id','hourly_rate','currency_code','effective_from','effective_until']; permission:='labor.wage.manage';
 when 'staff_availability_rules' then allowed:=array['staff_id','weekday','starts_local','ends_local','available','valid_from','valid_until']; permission:='schedule.availability.edit'; self_allowed:=true;
 when 'staff_availability_exceptions' then allowed:=array['staff_id','starts_at','ends_at','available','reason']; permission:='schedule.availability.edit'; self_allowed:=true;
 when 'time_off_requests' then allowed:=array['staff_id','starts_at','ends_at','category','requested_minutes','reason']; permission:='schedule.timeoff.review'; self_allowed:=true;
 when 'time_off_balances' then allowed:=array['staff_id','category','minutes']; permission:='staff.manage'; orgwide:=true;
 when 'schedule_periods' then allowed:=array['starts_on','ends_on','name','department_id']; permission:='schedule.create';
 when 'shift_requirements' then allowed:=array['period_id','job_role_id','area_id','starts_at','ends_at','minimum_staff']; permission:='schedule.requirements';
 when 'shift_notes' then allowed:=array['shift_id','body','staff_visible']; permission:='schedule.edit';
 when 'shift_break_rules' then allowed:=array['shift_id','minimum_minutes','paid','required']; permission:='schedule.edit';
 when 'schedule_templates' then allowed:=array['name','department_id']; permission:='schedule.templates';
 when 'schedule_template_shifts' then allowed:=array['template_id','job_role_id','department_id','area_id','weekday','starts_local','duration_minutes','headcount','instructions','break_minutes','break_paid']; permission:='schedule.templates';
 when 'labor_targets' then allowed:=array['starts_on','ends_on','target_minutes','target_cost','target_percent']; permission:='labor.wage.manage';
 when 'labor_forecasts' then allowed:=array['service_date','forecast_sales','forecast_covers']; permission:='labor.wage.manage';
 when 'workforce_settings' then allowed:=array['require_assigned_clock','clock_early_minutes','clock_late_minutes','overtime_week_minutes','overtime_multiplier','minimum_break_minutes','break_after_minutes','reminder_minutes']; permission:='schedule.settings';
 when 'workforce_department_managers' then allowed:=array['user_id','department_id']; permission:='staff.manage';
 else raise exception 'unsupported_workforce_table'; end case;
 if jsonb_typeof(data)<>'object' or octet_length(data::text)>20000 then raise exception 'invalid_fields'; end if;
 for col in select jsonb_object_keys(data) loop
 if not col=any(allowed) then raise exception 'unknown_field: %',col; end if;
 end loop;
 execute format('select to_jsonb(x) from public.%I x where id=$1 and organization_id=$2 for update',t)
 into previous using v_id,o;
 if previous is not null then
 if previous->>'deleted_at' is not null or (not orgwide and (previous->>'venue_id')::uuid<>v)
 then raise exception 'record_scope_mismatch'; end if;
 if (p->>'revision')::integer is distinct from (previous->>'revision')::integer then raise exception 'stale_revision' using errcode='40001'; end if;
 if t='staff_profiles' and data ? 'user_id' and data->>'user_id'<>previous->>'user_id' then raise exception 'immutable_employee'; end if;
 if t='time_off_requests' and previous->>'status'<>'pending' then raise exception 'request_already_reviewed'; end if;
 if t='schedule_periods' and previous->>'status'<>'draft' then raise exception 'published_period_metadata_locked'; end if;
 end if;
 staff:=coalesce((data->>'staff_id')::uuid,(previous->>'staff_id')::uuid);
 dept:=coalesce((data->>'department_id')::uuid,(previous->>'department_id')::uuid);
 if coalesce(data->>'job_role_id',previous->>'job_role_id') is not null then
 select department_id into dept from public.job_roles where id=coalesce((data->>'job_role_id')::uuid,(previous->>'job_role_id')::uuid);
 end if;
 if coalesce(data->>'shift_id',previous->>'shift_id') is not null then
 select department_id into dept from public.shifts where id=coalesce((data->>'shift_id')::uuid,(previous->>'shift_id')::uuid);
 if t in ('shift_notes','shift_break_rules') and exists(select 1 from public.shifts where id=coalesce((data->>'shift_id')::uuid,(previous->>'shift_id')::uuid) and status='published')
 and not coalesce((p->>'confirm_published')::boolean,false) then raise exception 'published_confirmation_required'; end if;
 end if;
 if self_allowed and public.wf_self(o,staff) then perform public.wf_require(o,v,'schedule.self');
 else
 if self_allowed and public.wf_staff_department(o,v,staff) then
 if not public.has_scoped_permission(o,v,permission) then raise exception 'workforce_permission_denied'; end if;
 else perform public.wf_require(o,v,permission,dept); end if;
 end if;
 if previous is not null and staff is distinct from (previous->>'staff_id')::uuid and previous ? 'staff_id' then raise exception 'immutable_employee'; end if;
 if t='staff_profiles' and not exists(select 1 from public.memberships where organization_id=o
 and user_id=(data->>'user_id')::uuid and status='active' and deleted_at is null)
 and previous is null then raise exception 'staff_membership_required'; end if;
 if t='staff_certifications' then data:=data||jsonb_build_object('verified_by',auth.uid()); end if;
 if t='employee_wage_rates' and exists(select 1 from public.employee_wage_rates w
 where w.staff_id=staff and w.venue_id=v and w.id<>v_id and w.deleted_at is null
 and w.job_role_id is not distinct from (coalesce(data,previous)->>'job_role_id')::uuid
 and daterange(w.effective_from,w.effective_until,'[)') &&
 daterange((coalesce(data->>'effective_from',previous->>'effective_from'))::date,
 (coalesce(data->>'effective_until',previous->>'effective_until'))::date,'[)'))
 then raise exception 'overlapping_wage_rate'; end if;
 if previous is null then
 data:=data||jsonb_build_object('id',v_id,'organization_id',o,'created_by',auth.uid());
 if not orgwide then data:=data||jsonb_build_object('venue_id',v); end if;
 select string_agg(format('%I',k),','),string_agg(format('(jsonb_populate_record(null::public.%I,$1)).%I',t,k),',')
 into cols,vals from jsonb_object_keys(data) k;
 execute format('insert into public.%I(%s) select %s returning to_jsonb(%I)',t,cols,vals,t) into result using data;
 else
 select string_agg(format('%I=(jsonb_populate_record(null::public.%I,$1)).%I',k,t,k),',')
 into cols from jsonb_object_keys(data) k;
 if cols is null then raise exception 'empty_update'; end if;
 execute format('update public.%I set %s where id=$2 returning to_jsonb(%I)',t,cols,t) into result using previous||data,v_id;
 end if;
 if t in ('shift_notes','shift_break_rules') then
 perform public.wf_notify_shift(coalesce((data->>'shift_id')::uuid,(previous->>'shift_id')::uuid),'Shift instructions updated');
 end if;
 return jsonb_build_object('id',v_id,'revision',result->'revision');
end; $$;

create function public.workforce_command(p_org uuid,p_venue uuid,p_command uuid,p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare cached public.workforce_commands; digest text; result jsonb; h public.shifts; other public.shifts;
 v_id uuid; staff uuid; myself uuid; assignment public.shift_assignments; request jsonb; t text; perm text;
 r record; x record; stamp timestamptz:=clock_timestamp(); cfg public.workforce_settings; entry public.time_entries;
 decision text; reason text:=p_payload->>'reason'; accepted boolean; period public.schedule_periods; old_state jsonb;
begin
 perform public.wf_require(p_org,p_venue,'venue.read');
 if p_command is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>100000 then raise exception 'invalid_command'; end if;
 perform pg_advisory_xact_lock(hashtextextended('workforce:'||p_org::text,0));
 -- A user-level lock also serializes time clocks across different organizations.
 perform pg_advisory_xact_lock(hashtextextended('workforce-user:'||auth.uid()::text,0));
 digest:=md5(jsonb_build_object('org',p_org,'venue',p_venue,'action',p_action,'payload',p_payload)::text);
 select * into cached from public.workforce_commands where command_id=p_command;
 if found then
 if cached.actor_id<>auth.uid() or cached.request_hash<>digest then raise exception 'idempotency_key_reused'; end if;
 return cached.response; end if;
 perform set_config('app.workforce_venue',p_venue::text,true);
 perform set_config('app.workforce_action',p_action,true);
 select id into myself from public.staff_profiles where organization_id=p_org and user_id=auth.uid() and deleted_at is null;
 select * into cfg from public.workforce_settings where venue_id=p_venue and deleted_at is null;
 if not found then cfg.require_assigned_clock:=true; cfg.clock_early_minutes:=15; cfg.clock_late_minutes:=120;
 cfg.minimum_break_minutes:=30; cfg.break_after_minutes:=360; end if;
 if p_action='save' then result:=public.wf_save(p_org,p_venue,p_payload);
 elsif p_action in ('copy_schedule','apply_template') then
 result:=public.wf_copy(p_org,p_venue,p_payload,p_action='apply_template');
 elsif p_action='save_shift' then
 v_id:=coalesce((p_payload->>'id')::uuid,gen_random_uuid());
 select * into h from public.shifts s where s.id=coalesce((p_payload->>'id')::uuid,v_id) for update;
 if found then
 if h.organization_id<>p_org or h.venue_id<>p_venue or h.deleted_at is not null then raise exception 'shift_scope_mismatch'; end if;
 perform public.wf_require(p_org,p_venue,'schedule.edit',h.department_id);
 if (p_payload->>'revision')::integer is distinct from h.revision then raise exception 'stale_revision' using errcode='40001'; end if;
 if h.status='published' and coalesce((p_payload->>'confirm_published')::boolean,false)=false then raise exception 'published_confirmation_required'; end if;
 else perform public.wf_require(p_org,p_venue,'schedule.create',(p_payload->>'department_id')::uuid); end if;
 perform public.wf_require(p_org,p_venue,case when h.id is null then 'schedule.create' else 'schedule.edit' end,(p_payload->>'department_id')::uuid);
 if h.id is null then
 insert into public.shifts(id,organization_id,venue_id,period_id,job_role_id,department_id,area_id,event_id,role_key,
 starts_at,ends_at,headcount,instructions,created_by) values(v_id,p_org,p_venue,(p_payload->>'period_id')::uuid,
 (p_payload->>'job_role_id')::uuid,(p_payload->>'department_id')::uuid,(p_payload->>'area_id')::uuid,(p_payload->>'event_id')::uuid,
 (select key from public.job_roles where id=(p_payload->>'job_role_id')::uuid),(p_payload->>'starts_at')::timestamptz,
 (p_payload->>'ends_at')::timestamptz,coalesce((p_payload->>'headcount')::integer,1),coalesce(p_payload->>'instructions',''),auth.uid())
 returning * into h;
 else
 if h.starts_at<=stamp then raise exception 'historical_shift_locked'; end if;
 update public.shifts s set period_id=(p_payload->>'period_id')::uuid,job_role_id=(p_payload->>'job_role_id')::uuid,
 department_id=(p_payload->>'department_id')::uuid,area_id=(p_payload->>'area_id')::uuid,event_id=(p_payload->>'event_id')::uuid,
 role_key=(select key from public.job_roles where id=(p_payload->>'job_role_id')::uuid),starts_at=(p_payload->>'starts_at')::timestamptz,
 ends_at=(p_payload->>'ends_at')::timestamptz,headcount=(p_payload->>'headcount')::integer,
 instructions=coalesce(p_payload->>'instructions','') where s.id=h.id returning * into h;
 end if;
 if h.headcount<(select count(*) from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null)
 then raise exception 'headcount_below_assignments'; end if;
 for r in select * from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null loop
 perform public.wf_eligible(h.id,r.staff_id,p_payload->>'override_reason'); end loop;
 if h.status='published' then perform public.wf_notify_shift(h.id,'Shift updated'); end if;
 result:=jsonb_build_object('id',h.id,'revision',h.revision);
 elsif p_action in ('assign','open','remove_assignment','retract_shift') then
 select * into strict h from public.shifts s where s.id=(p_payload->>'shift_id')::uuid and s.organization_id=p_org and s.venue_id=p_venue and s.deleted_at is null for update;
 if h.revision is distinct from (p_payload->>'revision')::integer then raise exception 'stale_revision' using errcode='40001'; end if;
 perform public.wf_require(p_org,p_venue,case p_action when 'assign' then 'schedule.assign'
 when 'open' then 'schedule.open' when 'remove_assignment' then 'schedule.assign' else 'schedule.retract' end,h.department_id);
 if h.starts_at<=stamp then raise exception 'historical_shift_locked'; end if;
 if p_action='assign' then
 staff:=(p_payload->>'staff_id')::uuid; perform public.wf_eligible(h.id,staff,p_payload->>'override_reason');
 if (select count(*) from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null)>=h.headcount then raise exception 'shift_full'; end if;
 insert into public.shift_assignments(organization_id,venue_id,shift_id,staff_id,override_reason)
 values(p_org,p_venue,h.id,staff,p_payload->>'override_reason');
 elsif p_action='open' then
 if h.status<>'published' then raise exception 'publish_before_open'; end if;
 if (select count(*) from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null)>=h.headcount then raise exception 'shift_full'; end if;
 insert into public.open_shift_offers(organization_id,venue_id,shift_id,closes_at) values(p_org,p_venue,h.id,h.starts_at);
 elsif p_action='remove_assignment' then
 select * into strict assignment from public.shift_assignments where id=(p_payload->>'assignment_id')::uuid and shift_id=h.id and status='assigned' and deleted_at is null;
 if char_length(coalesce(reason,''))<5 then raise exception 'reason_required'; end if;
 update public.shift_assignments set status='cancelled' where id=assignment.id;
 perform public.wf_notify(p_org,p_venue,(select user_id from public.staff_profiles where id=assignment.staff_id),'Assignment removed',reason,h.id);
 else
 perform public.wf_notify_shift(h.id,'Shift retracted');
 update public.shifts set status='retracted' where shifts.id=h.id;
 update public.open_shift_offers set status='cancelled' where shift_id=h.id and status='open';
 end if;
 update public.shifts set instructions=instructions where shifts.id=h.id returning revision into h.revision;
 if h.status='published' then perform public.wf_notify_shift(h.id,'Assignment updated'); end if;
 result:=jsonb_build_object('id',h.id,'revision',h.revision);
 elsif p_action in ('publish','retract') then
 select * into strict period from public.schedule_periods where schedule_periods.id=(p_payload->>'period_id')::uuid and organization_id=p_org and venue_id=p_venue and deleted_at is null for update;
 if period.revision is distinct from (p_payload->>'revision')::integer then raise exception 'stale_revision' using errcode='40001'; end if;
 for h in select * from public.shifts where period_id=period.id and deleted_at is null loop
 perform public.wf_require(p_org,p_venue,case when p_action='publish' then 'schedule.publish' else 'schedule.retract' end,h.department_id);
 if p_action='publish' then
 for r in select * from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null loop
 perform public.wf_eligible(h.id,r.staff_id,r.override_reason); end loop;
 end if; end loop;
 if not exists(select 1 from public.shifts where period_id=period.id and deleted_at is null) then
 perform public.wf_require(p_org,p_venue,case when p_action='publish' then 'schedule.publish' else 'schedule.retract' end); end if;
 if p_action='publish' and exists(select 1 from public.shift_requirements q where q.period_id=period.id and q.deleted_at is null
 and (select count(*) from public.shift_assignments a join public.shifts s on s.id=a.shift_id where s.period_id=period.id
 and s.deleted_at is null and a.deleted_at is null and a.status='assigned' and s.job_role_id=q.job_role_id
 and (q.area_id is null or s.area_id=q.area_id) and s.starts_at<=q.starts_at and s.ends_at>=q.ends_at)<q.minimum_staff)
 then raise exception 'staffing_requirement_unmet'; end if;
 update public.shifts set status=case when p_action='publish' then 'published' else 'retracted' end where period_id=period.id and deleted_at is null;
 update public.schedule_periods set status=case when p_action='publish' then 'published' else 'retracted' end,published_at=case when p_action='publish' then stamp else null end where schedule_periods.id=period.id;
 insert into public.schedule_versions(organization_id,venue_id,period_id,version_number,source,snapshot)
 values(p_org,p_venue,period.id,period.revision,p_action,coalesce((select jsonb_agg(to_jsonb(s)) from public.shifts s where s.period_id=period.id),'[]'));
 for h in select * from public.shifts where period_id=period.id and deleted_at is null loop
 perform public.wf_notify_shift(h.id,case when p_action='publish' then 'Schedule published' else 'Schedule retracted' end); end loop;
 if p_action='retract' then update public.open_shift_offers set status='cancelled' where shift_id in(select shifts.id from public.shifts where period_id=period.id) and status='open'; end if;
 result:=jsonb_build_object('id',period.id);
 elsif p_action in ('drop','pickup','swap') then
 perform public.wf_require(p_org,p_venue,'schedule.marketplace');
 if myself is null then raise exception 'staff_profile_required'; end if;
 select * into strict h from public.shifts where shifts.id=(p_payload->>'shift_id')::uuid and organization_id=p_org and venue_id=p_venue and status='published' and deleted_at is null;
 if h.revision is distinct from (p_payload->>'revision')::integer or h.starts_at<=stamp then raise exception 'shift_changed_or_started'; end if;
 if p_action='pickup' then
 perform public.wf_eligible(h.id,myself);
 insert into public.shift_pickup_requests(organization_id,venue_id,shift_id,offer_id,staff_id,expected_shift_revision)
 select p_org,p_venue,h.id,f.id,myself,h.revision from public.open_shift_offers f where f.id=(p_payload->>'offer_id')::uuid and f.shift_id=h.id and f.status='open' and f.closes_at>stamp and f.deleted_at is null returning shift_pickup_requests.id into v_id;
 if v_id is null then raise exception 'offer_closed'; end if;
 else
 select * into strict assignment from public.shift_assignments where shift_id=h.id and staff_id=myself and status='assigned' and deleted_at is null;
 if p_action='drop' then
 if char_length(coalesce(reason,''))<5 then raise exception 'reason_required'; end if;
 insert into public.shift_drop_requests(organization_id,venue_id,shift_id,assignment_id,staff_id,expected_shift_revision,reason)
 values(p_org,p_venue,h.id,assignment.id,myself,h.revision,reason) returning shift_drop_requests.id into v_id;
 else
 select * into strict other from public.shifts where shifts.id=(p_payload->>'other_shift_id')::uuid and organization_id=p_org and venue_id=p_venue and status='published' and deleted_at is null;
 staff:=(p_payload->>'other_staff_id')::uuid;
 if other.revision is distinct from (p_payload->>'other_revision')::integer or other.starts_at<=stamp
 or not exists(select 1 from public.shift_assignments where shift_id=other.id and staff_id=staff and status='assigned' and deleted_at is null) then raise exception 'other_assignment_changed'; end if;
 perform public.wf_eligible(h.id,staff,null,other.id); perform public.wf_eligible(other.id,myself,null,h.id);
 insert into public.shift_swap_requests(organization_id,venue_id,shift_id,other_shift_id,staff_id,other_staff_id,expected_shift_revision,expected_other_revision,reason)
 values(p_org,p_venue,h.id,other.id,myself,staff,h.revision,other.revision,coalesce(reason,'')) returning shift_swap_requests.id into v_id;
 perform public.wf_notify(p_org,p_venue,(select user_id from public.staff_profiles where staff_profiles.id=staff),'Swap invitation','Review and accept the proposed swap.',h.id);
 end if; end if;
 for r in select distinct m.user_id from public.memberships m where m.organization_id=p_org and (m.venue_id is null or m.venue_id=p_venue) and m.status='active' and m.deleted_at is null
 and public.membership_allows(m.id,m.role_key,'schedule.pickup.review') loop
 perform public.wf_notify(p_org,p_venue,r.user_id,'Shift request','A staff shift request needs review.',h.id); end loop;
 result:=jsonb_build_object('id',v_id);
 elsif p_action in ('accept_swap','review_request') then
 t:=p_payload->>'table';
 if t not in ('shift_drop_requests','shift_pickup_requests','shift_swap_requests','time_off_requests','clock_attestations') then raise exception 'invalid_request'; end if;
 execute format('select to_jsonb(x) from public.%I x where id=$1 and organization_id=$2 and venue_id=$3 and deleted_at is null for update',t)
 into request using (p_payload->>'id')::uuid,p_org,p_venue;
 if request is null or request->>'status'<>'pending' or (request->>'revision')::integer is distinct from (p_payload->>'revision')::integer then raise exception 'request_changed' using errcode='40001'; end if;
 if p_action='accept_swap' then
 if t<>'shift_swap_requests' or not public.wf_self(p_org,(request->>'other_staff_id')::uuid) then raise exception 'swap_recipient_required'; end if;
 update public.shift_swap_requests set recipient_accepted=true where shift_swap_requests.id=(request->>'id')::uuid;
 else
 perm:=case t when 'shift_drop_requests' then 'schedule.drop.review' when 'shift_pickup_requests' then 'schedule.pickup.review'
 when 'shift_swap_requests' then 'schedule.swap.review' when 'time_off_requests' then 'schedule.timeoff.review' else 'timeclock.manage' end;
 if request ? 'shift_id' then
 select * into strict h from public.shifts where shifts.id=(request->>'shift_id')::uuid and organization_id=p_org and venue_id=p_venue;
 perform public.wf_require(p_org,p_venue,perm,h.department_id);
 elsif t='time_off_requests' and public.wf_staff_department(p_org,p_venue,(request->>'staff_id')::uuid)
 and public.has_scoped_permission(p_org,p_venue,perm) then null;
 else perform public.wf_require(p_org,p_venue,perm); end if;
 decision:=p_payload->>'decision';
 if decision not in ('approved','rejected') or char_length(coalesce(reason,''))<5 then raise exception 'decision_and_reason_required'; end if;
 if decision='approved' then
 if request ? 'shift_id' and (h.status<>'published' or h.starts_at<=stamp or h.revision<>(request->>'expected_shift_revision')::integer)
 then raise exception 'shift_changed_or_started'; end if;
 if t='shift_drop_requests' then
 update public.shift_assignments set status='released' where shift_assignments.id=(request->>'assignment_id')::uuid and status='assigned';
 if not found then raise exception 'assignment_changed'; end if;
 insert into public.open_shift_offers(organization_id,venue_id,shift_id,released_assignment_id,closes_at)
 values(p_org,p_venue,h.id,(request->>'assignment_id')::uuid,h.starts_at) on conflict do nothing;
 elsif t='shift_pickup_requests' then
 perform public.wf_eligible(h.id,(request->>'staff_id')::uuid);
 if not exists(select 1 from public.open_shift_offers where open_shift_offers.id=(request->>'offer_id')::uuid and status='open' and closes_at>stamp) then raise exception 'offer_closed'; end if;
 if (select count(*) from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null)>=h.headcount then raise exception 'shift_full'; end if;
 insert into public.shift_assignments(organization_id,venue_id,shift_id,staff_id) values(p_org,p_venue,h.id,(request->>'staff_id')::uuid);
 if (select count(*) from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null)>=h.headcount then
 update public.open_shift_offers set status='filled' where open_shift_offers.id=(request->>'offer_id')::uuid; end if;
 elsif t='shift_swap_requests' then
 if not (request->>'recipient_accepted')::boolean then raise exception 'recipient_acceptance_required'; end if;
 select * into strict other from public.shifts where shifts.id=(request->>'other_shift_id')::uuid and organization_id=p_org and venue_id=p_venue and deleted_at is null;
 perform public.wf_require(p_org,p_venue,perm,other.department_id);
 if other.revision<>(request->>'expected_other_revision')::integer or other.status<>'published' or other.starts_at<=stamp then raise exception 'other_shift_changed'; end if;
 perform public.wf_eligible(h.id,(request->>'other_staff_id')::uuid,null,other.id);
 perform public.wf_eligible(other.id,(request->>'staff_id')::uuid,null,h.id);
 update public.shift_assignments set status='released' where status='assigned' and deleted_at is null
 and ((shift_id=h.id and staff_id=(request->>'staff_id')::uuid) or (shift_id=other.id and staff_id=(request->>'other_staff_id')::uuid));
 if (select count(*) from public.shift_assignments where status='released' and
 ((shift_id=h.id and staff_id=(request->>'staff_id')::uuid) or (shift_id=other.id and staff_id=(request->>'other_staff_id')::uuid)))<2 then raise exception 'assignment_changed'; end if;
 insert into public.shift_assignments(organization_id,venue_id,shift_id,staff_id) values
 (p_org,p_venue,h.id,(request->>'other_staff_id')::uuid),(p_org,p_venue,other.id,(request->>'staff_id')::uuid);
 update public.shifts set instructions=instructions where shifts.id=other.id;
 perform public.wf_notify_shift(other.id,'Swap approved');
 elsif t='time_off_requests' then
 if exists(select 1 from public.shift_assignments a join public.shifts s on s.id=a.shift_id
 where a.staff_id=(request->>'staff_id')::uuid and a.status='assigned' and a.deleted_at is null and s.deleted_at is null and s.status<>'retracted'
 and tstzrange(s.starts_at,s.ends_at,'[)') && tstzrange((request->>'starts_at')::timestamptz,(request->>'ends_at')::timestamptz,'[)')) then raise exception 'release_conflicting_assignments_first'; end if;
 if request->>'category'='paid' then
 update public.time_off_balances set minutes=minutes-(request->>'requested_minutes')::integer
 where staff_id=(request->>'staff_id')::uuid and category='paid' and minutes>=(request->>'requested_minutes')::integer and deleted_at is null;
 if not found then raise exception 'insufficient_time_off_balance'; end if; end if;
 elsif t='clock_attestations' then
 -- Approval records acceptance; a separate audited correction applies the claimed timestamp.
 null;
 end if;
 if request ? 'shift_id' then update public.shifts set instructions=instructions where shifts.id=h.id; perform public.wf_notify_shift(h.id,'Shift request approved'); end if;
 end if;
 execute format('update public.%I set status=$1,reviewed_by=$2,review_reason=$3 where id=$4',t) using decision,auth.uid(),reason,(request->>'id')::uuid;
 perform public.wf_notify(p_org,p_venue,(select user_id from public.staff_profiles where staff_profiles.id=(request->>'staff_id')::uuid),'Request '||decision,reason,(request->>'shift_id')::uuid);
 end if;
 result:=jsonb_build_object('id',request->>'id');
 elsif p_action in ('clock_in','clock_out','break_start','break_end','correct_time','attest') then
 perform public.wf_require(p_org,p_venue,case when p_action='correct_time' then 'timeclock.manage' else 'timeclock.self' end);
 if p_action='clock_in' then
 if myself is null then raise exception 'staff_profile_required'; end if;
 if exists(select 1 from public.time_entries where user_id=auth.uid() and clock_out is null and deleted_at is null) then raise exception 'already_clocked_in'; end if;
 if p_payload->>'shift_id' is not null then
 select * into strict h from public.shifts where shifts.id=(p_payload->>'shift_id')::uuid and organization_id=p_org and venue_id=p_venue and status='published' and deleted_at is null;
 perform public.wf_eligible(h.id,myself);
 if not exists(select 1 from public.shift_assignments where shift_id=h.id and staff_id=myself and status='assigned' and deleted_at is null)
 or stamp<h.starts_at-make_interval(mins=>cfg.clock_early_minutes) or stamp>h.ends_at+make_interval(mins=>cfg.clock_late_minutes) then raise exception 'outside_assigned_clock_window'; end if;
 elsif cfg.require_assigned_clock or not public.wf_can(p_org,p_venue,'timeclock.manage') or char_length(coalesce(reason,''))<5 then
 raise exception 'assigned_shift_required'; end if;
 insert into public.time_entries(organization_id,venue_id,user_id,shift_id,clock_in,created_by)
 values(p_org,p_venue,auth.uid(),h.id,stamp,auth.uid()) returning time_entries.id into v_id;
 elsif p_action='attest' then
 if myself is null or char_length(coalesce(reason,''))<5 then raise exception 'staff_and_reason_required'; end if;
 if p_payload->>'time_entry_id' is not null and not exists(select 1 from public.time_entries where time_entries.id=(p_payload->>'time_entry_id')::uuid
 and organization_id=p_org and venue_id=p_venue and user_id=auth.uid() and deleted_at is null) then raise exception 'time_entry_not_owned'; end if;
 insert into public.clock_attestations(organization_id,venue_id,staff_id,time_entry_id,kind,captured_at,reason)
 values(p_org,p_venue,myself,(p_payload->>'time_entry_id')::uuid,p_payload->>'kind',(p_payload->>'captured_at')::timestamptz,reason) returning clock_attestations.id into v_id;
 elsif p_action='correct_time' then
 if char_length(coalesce(reason,''))<5 then raise exception 'reason_required'; end if;
 select * into strict entry from public.time_entries where time_entries.id=(p_payload->>'id')::uuid and organization_id=p_org and venue_id=p_venue and deleted_at is null for update;
 if entry.revision is distinct from (p_payload->>'revision')::integer then raise exception 'stale_revision' using errcode='40001'; end if;
 old_state:=to_jsonb(entry);
 if (p_payload->>'clock_in')::timestamptz>stamp or (p_payload->>'clock_out')::timestamptz>stamp+interval '5 minutes' then raise exception 'future_clock_correction'; end if;
 update public.time_entries set clock_in=(p_payload->>'clock_in')::timestamptz,clock_out=(p_payload->>'clock_out')::timestamptz where time_entries.id=entry.id returning * into entry;
 if exists(select 1 from public.time_entries b where b.user_id=entry.user_id and b.id<>entry.id and b.deleted_at is null
 and tstzrange(b.clock_in,b.clock_out,'[)') && tstzrange(entry.clock_in,entry.clock_out,'[)')) then raise exception 'time_entry_overlap'; end if;
 if exists(select 1 from public.break_entries b where b.time_entry_id=entry.id and b.deleted_at is null
 and (b.starts_at<entry.clock_in or (entry.clock_out is not null and coalesce(b.ends_at,'infinity')>entry.clock_out))) then raise exception 'correction_excludes_break'; end if;
 insert into public.time_entry_corrections(organization_id,venue_id,time_entry_id,reason,previous_state,next_state)
 values(p_org,p_venue,entry.id,reason,old_state,to_jsonb(entry)); v_id:=entry.id;
 else
 select * into strict entry from public.time_entries where organization_id=p_org and venue_id=p_venue and user_id=auth.uid() and clock_out is null and deleted_at is null for update;
 if p_action='break_start' then
 insert into public.break_entries(organization_id,venue_id,time_entry_id,starts_at,paid)
 values(p_org,p_venue,entry.id,stamp,coalesce((select paid from public.shift_break_rules where shift_id=entry.shift_id),false)) returning break_entries.id into v_id;
 elsif p_action='break_end' then
 update public.break_entries set ends_at=stamp where time_entry_id=entry.id and ends_at is null and deleted_at is null returning break_entries.id into v_id;
 if v_id is null then raise exception 'no_open_break'; end if;
 else
 update public.break_entries set ends_at=stamp where time_entry_id=entry.id and ends_at is null and deleted_at is null;
 update public.time_entries set clock_out=stamp where time_entries.id=entry.id; v_id:=entry.id;
 if extract(epoch from stamp-entry.clock_in)/60>=cfg.break_after_minutes
 and coalesce((select sum(extract(epoch from b.ends_at-b.starts_at)/60) from public.break_entries b where b.time_entry_id=entry.id and b.deleted_at is null),0)<cfg.minimum_break_minutes then
 insert into public.clock_attestations(organization_id,venue_id,staff_id,time_entry_id,kind,captured_at,reason)
 values(p_org,p_venue,myself,entry.id,'missed_break',stamp,coalesce(reason,'Required break not recorded; manager review requested.')); end if;
 end if; end if;
 result:=jsonb_build_object('id',v_id);
 elsif p_action='attach_evidence' then
 select to_jsonb(c) into strict request from public.staff_certifications c where c.id=(p_payload->>'id')::uuid and c.organization_id=p_org and c.deleted_at is null;
 if (p_payload->>'revision')::integer is distinct from (request->>'revision')::integer then raise exception 'stale_revision' using errcode='40001'; end if;
 if not public.wf_can(p_org,p_venue,'staff.certify') and
 (not public.wf_self(p_org,(request->>'staff_id')::uuid) or request->>'status'<>'pending') then raise exception 'certification_verifier_required'; end if;
 if p_payload->>'evidence_path' not like p_org::text||'/'||p_venue::text||'/'||(request->>'staff_id')||'/%'
 or not exists(select 1 from storage.objects where bucket_id='workforce-certificates' and name=p_payload->>'evidence_path') then raise exception 'evidence_not_found'; end if;
 update public.staff_certifications set evidence_path=p_payload->>'evidence_path',status='pending',verified_by=null
 where staff_certifications.id=(request->>'id')::uuid;
 result:=jsonb_build_object('id',request->>'id');
 elsif p_action='message' then
 perform public.wf_require(p_org,p_venue,'chat.write');
 if p_payload->>'shift_id' is not null and not public.wf_shift_visible((p_payload->>'shift_id')::uuid) then raise exception 'shift_not_visible'; end if;
 if p_payload->>'recipient_id' is not null and not exists(select 1 from public.memberships where organization_id=p_org and user_id=(p_payload->>'recipient_id')::uuid and status='active' and deleted_at is null and (venue_id is null or venue_id=p_venue)) then raise exception 'recipient_not_authorized'; end if;
 insert into public.staff_messages(organization_id,venue_id,sender_id,recipient_id,shift_id,body)
 values(p_org,p_venue,auth.uid(),(p_payload->>'recipient_id')::uuid,(p_payload->>'shift_id')::uuid,p_payload->>'body') returning staff_messages.id into v_id;
 perform public.wf_notify(p_org,p_venue,(p_payload->>'recipient_id')::uuid,'Team message','Open scheduling to read your message.',(p_payload->>'shift_id')::uuid);
 result:=jsonb_build_object('id',v_id);
 elsif p_action='read_notification' then
 update public.notifications set read_at=stamp where notifications.id=(p_payload->>'id')::uuid and recipient_id=auth.uid() and organization_id=p_org and venue_id=p_venue;
 if not found then raise exception 'notification_not_found'; end if; result:='{}';
 elsif p_action='register_push' then
 if char_length(p_payload->>'token') not between 20 and 4096 then raise exception 'invalid_push_token'; end if;
 insert into public.push_devices(organization_id,venue_id,user_id,token,platform)
 values(p_org,p_venue,auth.uid(),p_payload->>'token',p_payload->>'platform')
 on conflict(token) do update set user_id=excluded.user_id,organization_id=excluded.organization_id,venue_id=excluded.venue_id,enabled=true,updated_at=stamp;
 result:='{}';
 elsif p_action='disable_push' then
 update public.push_devices set enabled=false where user_id=auth.uid() and token=p_payload->>'token'; result:='{}';
 else raise exception 'unsupported_workforce_action'; end if;
 insert into public.workforce_commands(organization_id,venue_id,command_id,actor_id,action,request_hash,response)
 values(p_org,p_venue,p_command,auth.uid(),p_action,digest,result);
 return result;
end; $$;

create function public.workforce_snapshot(p_org uuid,p_venue uuid,p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql security invoker set search_path='' as $$
#variable_conflict use_column
declare result jsonb:='{}'; t text; rows jsonb;
begin
 if auth.uid() is null or not public.has_scoped_permission(p_org,p_venue,'venue.read')
 or p_end<=p_start or p_end>p_start+interval '40 days' then raise exception 'invalid_snapshot_scope'; end if;
 foreach t in array array['venue_areas','departments','job_roles','staff_profiles','staff_role_assignments','staff_qualifications','staff_certifications','employee_wage_rates','staff_availability_rules','staff_availability_exceptions','time_off_balances','time_off_requests','schedule_periods','schedule_versions','shift_assignments','shift_break_rules','shift_notes','shift_requirements','open_shift_offers','shift_drop_requests','shift_pickup_requests','shift_swap_requests','shift_change_events','schedule_templates','schedule_template_shifts','labor_targets','labor_forecasts','break_entries','time_entry_corrections','clock_attestations','notifications','staff_messages','workforce_settings','workforce_push_status','shifts','time_entries','workforce_department_managers'] loop
 if t in ('staff_profiles','staff_qualifications','staff_certifications','time_off_balances') then
 execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where organization_id=$1 and deleted_at is null',t) into rows using p_org;
 elsif t='shifts' then
 execute 'select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.shifts x where organization_id=$1 and venue_id=$2 and deleted_at is null and starts_at<$4 and ends_at>$3' into rows using p_org,p_venue,p_start,p_end;
 elsif t='employee_wage_rates' then
 select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('hourly_rate',x.hourly_rate::text)),'[]') into rows from public.employee_wage_rates x where organization_id=p_org and venue_id=p_venue and deleted_at is null;
 elsif t='labor_targets' then
 select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('target_cost',x.target_cost::text,'target_percent',x.target_percent::text)),'[]') into rows from public.labor_targets x where organization_id=p_org and venue_id=p_venue and deleted_at is null;
 elsif t='labor_forecasts' then
 select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('forecast_sales',x.forecast_sales::text)),'[]') into rows from public.labor_forecasts x where organization_id=p_org and venue_id=p_venue and deleted_at is null;
 elsif t='workforce_settings' then
 select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('overtime_multiplier',x.overtime_multiplier::text)),'[]') into rows from public.workforce_settings x where organization_id=p_org and venue_id=p_venue and deleted_at is null;
 else
 execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I x where organization_id=$1 and venue_id=$2 and deleted_at is null',t) into rows using p_org,p_venue;
 end if;
 result:=result||jsonb_build_object(t,rows);
 end loop;
 if public.wf_can(p_org,p_venue,'schedule.marketplace') then
 result:=result||jsonb_build_object('marketplace',public.workforce_marketplace(p_org,p_venue,p_start,p_end));
 end if;
 return result;
end; $$;
-- Legacy routes cannot bypass workforce eligibility/publication checks.
revoke execute on function public.create_shift(uuid,uuid,text,timestamptz,timestamptz),public.publish_shifts(uuid),public.clock_in(uuid),public.clock_out(uuid) from authenticated;
revoke all on function public.wf_require(uuid,uuid,text,uuid),public.wf_eligible(uuid,uuid,text,uuid),
public.wf_notify(uuid,uuid,uuid,text,text,uuid),public.wf_notify_shift(uuid,text),public.wf_save(uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.workforce_command(uuid,uuid,uuid,text,jsonb),public.workforce_snapshot(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.workforce_command(uuid,uuid,uuid,text,jsonb),public.workforce_snapshot(uuid,uuid,timestamptz,timestamptz) to authenticated;
create function public.wf_local_utc(local_time timestamp,zone text) returns timestamptz
language plpgsql stable set search_path='' as $$
declare choices timestamptz[];
begin
 select array_agg(distinct u) into choices from (
 select (local_time at time zone 'UTC')-((x at time zone zone)-(x at time zone 'UTC')) u
 from generate_series((local_time at time zone zone)-interval '36 hours',
 (local_time at time zone zone)+interval '36 hours',interval '1 hour') x) candidates
 where u at time zone zone=local_time;
 if cardinality(choices) is distinct from 1 then raise exception 'dst_gap_or_ambiguity_choose_explicit_time'; end if;
 return choices[1];
end; $$;
create function public.wf_copy(o uuid,v uuid,p jsonb,is_template boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target public.schedule_periods; source public.schedule_periods; zone text; h public.shifts; row record;
 new_id uuid; start_time timestamptz; end_time timestamptz; local_start timestamp; local_end timestamp; n integer:=0; a record;
begin
 select * into strict target from public.schedule_periods where id=(p->>'target_period_id')::uuid and organization_id=o and venue_id=v and deleted_at is null;
 if target.status<>'draft' or target.revision is distinct from (p->>'revision')::integer then raise exception 'target_period_changed'; end if;
 select timezone into zone from public.venues where id=v;
 if is_template then
 perform public.wf_require(o,v,'schedule.copy',target.department_id);
 if not exists(select 1 from public.schedule_templates where id=(p->>'template_id')::uuid and organization_id=o and venue_id=v and deleted_at is null) then raise exception 'template_not_found'; end if;
 for row in select * from public.schedule_template_shifts where template_id=(p->>'template_id')::uuid and deleted_at is null loop
 perform public.wf_require(o,v,'schedule.copy',row.department_id);
 for a in select day::date calendar_date from generate_series(target.starts_on,target.ends_on-1,interval '1 day') day where extract(isodow from day)=row.weekday loop
 local_start:=a.calendar_date+row.starts_local; local_end:=local_start+make_interval(mins=>row.duration_minutes);
 start_time:=public.wf_local_utc(local_start,zone); end_time:=public.wf_local_utc(local_end,zone);
 if target.department_id is not null and target.department_id is distinct from row.department_id then raise exception 'template_department_mismatch'; end if;
 insert into public.shifts(organization_id,venue_id,period_id,job_role_id,department_id,area_id,role_key,starts_at,ends_at,headcount,instructions,created_by)
 values(o,v,target.id,row.job_role_id,row.department_id,row.area_id,(select key from public.job_roles where id=row.job_role_id),start_time,end_time,row.headcount,row.instructions,auth.uid()) returning id into new_id;
 insert into public.shift_break_rules(organization_id,venue_id,shift_id,minimum_minutes,paid,required)
 values(o,v,new_id,row.break_minutes,row.break_paid,row.break_minutes>0); n:=n+1;
 end loop; end loop;
 else
 select * into strict source from public.schedule_periods where id=(p->>'source_period_id')::uuid and organization_id=o and venue_id=v and deleted_at is null;
 if source.id=target.id then raise exception 'copy_to_distinct_period'; end if;
 for h in select * from public.shifts where period_id=source.id and deleted_at is null and status<>'retracted' loop
 perform public.wf_require(o,v,'schedule.copy',h.department_id);
 local_start:=(h.starts_at at time zone zone)+make_interval(days=>target.starts_on-source.starts_on);
 local_end:=(h.ends_at at time zone zone)+make_interval(days=>target.starts_on-source.starts_on);
 start_time:=public.wf_local_utc(local_start,zone); end_time:=public.wf_local_utc(local_end,zone);
 insert into public.shifts(organization_id,venue_id,period_id,job_role_id,department_id,area_id,event_id,role_key,starts_at,ends_at,headcount,instructions,created_by)
 values(o,v,target.id,h.job_role_id,h.department_id,h.area_id,null,h.role_key,start_time,end_time,h.headcount,h.instructions,auth.uid()) returning id into new_id;
 insert into public.shift_break_rules(organization_id,venue_id,shift_id,minimum_minutes,paid,required)
 select o,v,new_id,minimum_minutes,paid,required from public.shift_break_rules where shift_id=h.id and deleted_at is null;
 if coalesce((p->>'include_assignments')::boolean,false) then
 for row in select * from public.shift_assignments where shift_id=h.id and status='assigned' and deleted_at is null loop
 perform public.wf_eligible(new_id,row.staff_id);
 insert into public.shift_assignments(organization_id,venue_id,shift_id,staff_id) values(o,v,new_id,row.staff_id);
 end loop; end if; n:=n+1;
 end loop;
 end if;
 update public.schedule_periods set name=name where id=target.id;
 return jsonb_build_object('id',target.id,'copied',n);
end; $$;
create function public.workforce_push_disable() returns void language sql security definer set search_path='' as $$
 update public.push_devices set enabled=false where user_id=auth.uid();
$$;
revoke all on function public.wf_copy(uuid,uuid,jsonb,boolean),public.wf_local_utc(timestamp,text) from public,anon,authenticated;
revoke all on function public.workforce_push_disable() from public,anon;
grant execute on function public.workforce_push_disable() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('workforce-certificates','workforce-certificates',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create function public.wf_evidence_access(path text,write_access boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare parts text[]:=string_to_array(path,'/'); o uuid; v uuid; s uuid;
begin
 if cardinality(parts)<>4 then return false; end if;
 begin o:=parts[1]::uuid; v:=parts[2]::uuid; s:=parts[3]::uuid;
 exception when invalid_text_representation then return false; end;
 if not exists(select 1 from public.venues where id=v and organization_id=o and deleted_at is null)
 or not exists(select 1 from public.staff_profiles where id=s and organization_id=o and deleted_at is null)
 then return false; end if;
 return public.has_scoped_permission(o,v,'venue.read')
 and (public.wf_can(o,v,'staff.certify') or public.wf_self(o,s));
end; $$;
revoke all on function public.wf_evidence_access(text,boolean) from public,anon;
grant execute on function public.wf_evidence_access(text,boolean) to authenticated;
create policy workforce_evidence_read on storage.objects for select to authenticated
using(bucket_id='workforce-certificates' and public.wf_evidence_access(name,false));
create policy workforce_evidence_insert on storage.objects for insert to authenticated
with check(bucket_id='workforce-certificates' and public.wf_evidence_access(name,true));
-- Uploads are append-only; verified evidence cannot be replaced or removed by staff.

alter publication supabase_realtime add table public.notifications,public.shifts,public.shift_assignments,public.shift_drop_requests,public.shift_pickup_requests,public.shift_swap_requests;

create function public.workforce_outbox_claim() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 with claimed as (
 update public.notification_outbox set status='processing',attempts=attempts+1,leased_until=now()+interval '2 minutes'
 where id in(select id from public.notification_outbox where (status in ('pending','failed','unconfigured') or
 (status='processing' and leased_until<now())) and available_at<=now() and attempts<8
 order by available_at for update skip locked limit 50) returning *)
 select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('notification',to_jsonb(n),
 'tokens',coalesce((select jsonb_agg(d.token) from public.push_devices d where d.user_id=n.recipient_id
 and d.organization_id=n.organization_id and d.venue_id=n.venue_id and d.enabled),'[]'))),'[]')
 into result from claimed c join public.notifications n on n.id=c.notification_id;
 return result;
end; $$;
create function public.workforce_outbox_complete(p_id uuid,p_status text,p_error text default null) returns void
language plpgsql security definer set search_path='' as $$
declare item public.notification_outbox;
begin
 if p_status not in ('sent','failed','unconfigured') then raise exception 'invalid_delivery_state'; end if;
 update public.notification_outbox set status=p_status,last_error=left(p_error,200),leased_until=null,
 available_at=now()+case when p_status='unconfigured' then interval '1 hour' else interval '5 minutes' end
 where id=p_id returning * into item;
 if p_status='sent' then
 insert into public.workforce_push_status(organization_id,venue_id,configured,last_delivery_at)
 values(item.organization_id,item.venue_id,true,now()) on conflict(organization_id,venue_id)
 do update set configured=true,last_delivery_at=now();
 end if;
end; $$;
revoke all on function public.workforce_outbox_claim(),public.workforce_outbox_complete(uuid,text,text) from public,anon,authenticated;
grant execute on function public.workforce_outbox_claim(),public.workforce_outbox_complete(uuid,text,text) to service_role;
create function public.workforce_labor_report(p_org uuid,p_venue uuid,p_start date,p_end date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare zone text; cfg public.workforce_settings; result jsonb;
begin
 perform public.wf_require(p_org,p_venue,'labor.read');
 if p_end<=p_start or p_end>p_start+31 then raise exception 'invalid_labor_window'; end if;
 select timezone into zone from public.venues where id=p_venue;
 select * into cfg from public.workforce_settings where venue_id=p_venue and deleted_at is null;
 -- Expand weekly boundaries so earlier shifts across venues count toward overtime.
 with raw as (
 select 'planned' kind,s.id,a.staff_id,s.venue_id,s.job_role_id,s.starts_at start_at,s.ends_at end_at,
 greatest(0,extract(epoch from s.ends_at-s.starts_at)/60-coalesce((select minimum_minutes from public.shift_break_rules
 where shift_id=s.id and not paid and deleted_at is null),0)) paid
 from public.shifts s join public.shift_assignments a on a.shift_id=s.id
 where s.organization_id=p_org and s.status<>'retracted' and s.deleted_at is null and a.status='assigned' and a.deleted_at is null
 union all
 select 'actual',e.id,p.id,e.venue_id,s.job_role_id,e.clock_in,e.clock_out,
 greatest(0,extract(epoch from e.clock_out-e.clock_in)/60-coalesce((select sum(extract(epoch from b.ends_at-b.starts_at)/60)
 from public.break_entries b where b.time_entry_id=e.id and not b.paid and b.deleted_at is null),0))
 from public.time_entries e join public.staff_profiles p on p.user_id=e.user_id and p.organization_id=e.organization_id
 left join public.shifts s on s.id=e.shift_id where e.organization_id=p_org and e.deleted_at is null and e.clock_out is not null
 ), expanded as (
 select r.*,day::date work_date,(date_trunc('week',day))::date work_week,
 r.paid * greatest(0,extract(epoch from least(r.end_at,(day::date+1)::timestamp at time zone zone)-
 greatest(r.start_at,day::date::timestamp at time zone zone))/60)
 /nullif(extract(epoch from r.end_at-r.start_at)/60,0) minutes
 from raw r,generate_series((r.start_at at time zone zone)::date,((r.end_at-interval '1 microsecond') at time zone zone)::date,interval '1 day') day
 where r.start_at < (p_end::timestamp at time zone zone) and r.end_at > (date_trunc('week',p_start::timestamp) at time zone zone)
 ), ordered as (
 select *,coalesce(sum(minutes) over(partition by kind,staff_id,work_week order by start_at,id,work_date rows between unbounded preceding and 1 preceding),0) prior
 from expanded
 ), costed as (
 select r.*,greatest(0,least(minutes,prior+minutes-coalesce(cfg.overtime_week_minutes,2400))) ot,w.hourly_rate,w.currency_code
 from ordered r left join lateral (
 select * from public.employee_wage_rates w where w.staff_id=r.staff_id and w.venue_id=r.venue_id and w.deleted_at is null
 and (w.job_role_id is null or w.job_role_id=r.job_role_id) and w.effective_from<=r.work_date
 and (w.effective_until is null or w.effective_until>r.work_date) order by (w.job_role_id is not null) desc,w.effective_from desc limit 1) w on true
 where r.venue_id=p_venue and r.work_date>=p_start and r.work_date<p_end
 ), totals as (
 select kind,coalesce(currency_code,'MISSING') currency,round(sum(minutes),2)::text paid_minutes,
 round(sum(ot),2)::text overtime_minutes,count(*) filter(where hourly_rate is null) missing_rates,
 round(sum(hourly_rate*(minutes-ot+ot*coalesce(cfg.overtime_multiplier,1.5))/60),2)::text cost
 from costed group by kind,currency_code)
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into result from totals t;
 return result;
end; $$;
revoke all on function public.workforce_labor_report(uuid,uuid,date,date) from public,anon;
grant execute on function public.workforce_labor_report(uuid,uuid,date,date) to authenticated;
-- Public staff marketplace cards omit employment limits, wages and private notes.
create function public.workforce_marketplace(p_org uuid,p_venue uuid,p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.wf_require(p_org,p_venue,'schedule.marketplace');
 if p_end<=p_start or p_end>p_start+interval '40 days' then raise exception 'invalid_marketplace_window'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',a.id,'shift_id',s.id,'staff_id',p.id,'staff_name',p.display_name,'role_key',s.role_key,
 'starts_at',s.starts_at,'ends_at',s.ends_at,'revision',s.revision)),'[]') into result
 from public.shift_assignments a join public.shifts s on s.id=a.shift_id join public.staff_profiles p on p.id=a.staff_id
 where s.organization_id=p_org and s.venue_id=p_venue and s.status='published' and s.deleted_at is null
 and a.status='assigned' and a.deleted_at is null and s.starts_at>=p_start and s.ends_at<=p_end
 and p.deleted_at is null and p.employment_status='active';
 return result;
end; $$;
revoke all on function public.workforce_marketplace(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.workforce_marketplace(uuid,uuid,timestamptz,timestamptz) to authenticated;
