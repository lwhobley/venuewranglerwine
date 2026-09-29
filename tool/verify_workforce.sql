\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('10000000-0000-4000-8000-000000000099','workforce-ci@example.invalid','{"display_name":"Workforce CI"}') on conflict(id) do nothing;
insert into public.profiles(id,display_name,email) values
('10000000-0000-4000-8000-000000000099','Workforce CI','workforce-ci@example.invalid') on conflict(id) do nothing;
insert into public.platform_admins(user_id) values('10000000-0000-4000-8000-000000000099') on conflict do nothing;
\i supabase/tests/workforce_test.sql
\i supabase/tests/workforce_exchange_test.sql
\i supabase/tests/workforce_attendance_copy_test.sql
\i supabase/tests/clock_geofence_test.sql
\i supabase/tests/workforce_policy_test.sql
rollback;
