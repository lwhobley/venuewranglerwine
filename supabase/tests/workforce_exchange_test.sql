-- Append after workforce_test.sql in its rollback transaction.
insert into auth.users(id,email,raw_user_meta_data) values
 ('10000000-0000-4000-8000-000000000001','workforce-fixture-one@example.invalid','{"display_name":"Employee one"}'),
 ('10000000-0000-4000-8000-000000000002','workforce-fixture-two@example.invalid','{"display_name":"Employee two"}');
insert into public.profiles(id,display_name,email) values
 ('10000000-0000-4000-8000-000000000001','Employee one','workforce-fixture-one@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','Employee two','workforce-fixture-two@example.invalid') on conflict(id) do nothing;
insert into public.memberships(organization_id,venue_id,user_id,role_key)
select current_setting('workforce_test.org')::uuid,current_setting('workforce_test.venue')::uuid,id,'employee'
from public.profiles where id in('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002');
set local role authenticated;
do $test$
declare o uuid:=current_setting('workforce_test.org')::uuid; v uuid:=current_setting('workforce_test.venue')::uuid;
 h uuid:=current_setting('workforce_test.shift')::uuid; admin uuid:=auth.uid(); staff_one uuid; staff_two uuid; h2 uuid; roleid uuid; d uuid;
 req uuid; offer uuid; version integer; a jsonb; failed boolean; snap jsonb;
begin
 select job_role_id,department_id into roleid,d from public.shifts where id=h;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_profiles','data',
 jsonb_build_object('user_id','10000000-0000-4000-8000-000000000001','display_name','Employee one'))); staff_one:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_profiles','data',
 jsonb_build_object('user_id','10000000-0000-4000-8000-000000000002','display_name','Employee two'))); staff_two:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_role_assignments','data',jsonb_build_object('staff_id',staff_one,'job_role_id',roleid)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_role_assignments','data',jsonb_build_object('staff_id',staff_two,'job_role_id',roleid)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_certifications','data',jsonb_build_object('staff_id',staff_one,'certification_key','food','expires_on','2028-01-01','status','verified')));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_certifications','data',jsonb_build_object('staff_id',staff_two,'certification_key','food','expires_on','2028-01-01','status','verified')));
 -- Release the initial administrator assignment and directly assign employee one.
 select revision into version from public.shifts where id=h;
 perform public.workforce_command(o,v,gen_random_uuid(),'remove_assignment',jsonb_build_object('shift_id',h,'revision',version,'assignment_id',(select id from public.shift_assignments where shift_id=h and status='assigned'),'reason','Fixture reassignment'));
 select revision into version from public.shifts where id=h;
 perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',h,'revision',version,'staff_id',staff_one));
 select revision into version from public.shifts where id=h;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 a:=public.workforce_command(o,v,gen_random_uuid(),'drop',jsonb_build_object('shift_id',h,'revision',version,'reason','Family appointment')); req:=(a->>'id')::uuid;
 if not exists(select 1 from public.shift_assignments where shift_id=h and staff_id=staff_one and status='assigned') then raise exception 'pending drop released responsibility'; end if;
 if exists(select 1 from public.employee_wage_rates) then raise exception 'employee wage leak'; end if;
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"workforce_settings","data":{"reminder_minutes":30}}'); exception when insufficient_privilege then failed:=true; end;
 if not failed then raise exception 'employee settings mutation accepted'; end if;
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform public.workforce_command(o,v,gen_random_uuid(),'review_request',jsonb_build_object('table','shift_drop_requests','id',req,'revision',1,'decision','approved','reason','Coverage replacement requested'));
 select id into offer from public.open_shift_offers where shift_id=h and status='open';
 select revision into version from public.shifts where id=h;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
 a:=public.workforce_command(o,v,gen_random_uuid(),'pickup',jsonb_build_object('shift_id',h,'revision',version,'offer_id',offer));req:=(a->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform public.workforce_command(o,v,gen_random_uuid(),'review_request',jsonb_build_object('table','shift_pickup_requests','id',req,'revision',1,'decision','approved','reason','Qualified replacement approved'));
 if not exists(select 1 from public.shift_assignments where shift_id=h and staff_id=staff_two and status='assigned') then raise exception 'pickup not assigned'; end if;
 if not exists(select 1 from public.open_shift_offers where id=offer and status='filled') then raise exception 'filled offer still open'; end if;
 -- Make the other employee's shift for a two-party exchange.
 a:=public.workforce_command(o,v,gen_random_uuid(),'save_shift',jsonb_build_object('period_id',(select period_id from public.shifts where id=h),
 'job_role_id',roleid,'department_id',d,'starts_at','2027-01-06T16:00:00Z','ends_at','2027-01-06T22:00:00Z','headcount',1)); h2:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',h2,'revision',1,'staff_id',staff_one));
 perform public.workforce_command(o,v,gen_random_uuid(),'publish',jsonb_build_object('period_id',(select period_id from public.shifts where id=h),
 'revision',(select revision from public.schedule_periods where id=(select period_id from public.shifts where id=h))));
 select revision into version from public.shifts where id=h;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
 a:=public.workforce_command(o,v,gen_random_uuid(),'swap',jsonb_build_object('shift_id',h,'revision',version,
 'other_shift_id',h2,'other_revision',3,'other_staff_id',staff_one,'reason','Exchange requested')); req:=(a->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',admin::text,true);
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'review_request',jsonb_build_object('table','shift_swap_requests','id',req,'revision',1,'decision','approved','reason','Manager approval'));
 exception when others then failed:=sqlerrm='recipient_acceptance_required'; end;
 if not failed then raise exception 'swap without consent accepted'; end if;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 perform public.workforce_command(o,v,gen_random_uuid(),'accept_swap',jsonb_build_object('table','shift_swap_requests','id',req,'revision',1));
 perform set_config('request.jwt.claim.sub',admin::text,true);
 perform public.workforce_command(o,v,gen_random_uuid(),'review_request',jsonb_build_object('table','shift_swap_requests','id',req,'revision',2,'decision','approved','reason','Both employees qualified'));
 if not exists(select 1 from public.shift_assignments where shift_id=h and staff_id=staff_one and status='assigned')
 or not exists(select 1 from public.shift_assignments where shift_id=h2 and staff_id=staff_two and status='assigned') then raise exception 'swap assignments incorrect'; end if;
 -- Offline claims stay separate from the authoritative clock ledger.
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 perform public.workforce_command(o,v,gen_random_uuid(),'attest','{"kind":"offline_in","captured_at":"2027-01-05T16:00:00Z","reason":"No network at shift start"}');
 if exists(select 1 from public.time_entries where user_id=auth.uid()) then raise exception 'offline claim became trusted punch'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 if exists(select 1 from public.shifts where organization_id=o) then raise exception 'outsider shift leak'; end if;
 failed:=false; begin perform public.workforce_snapshot(o,v,'2027-01-04','2027-01-12'); exception when others then failed:=true; end;
 if not failed then raise exception 'outsider snapshot accepted'; end if;
 perform set_config('request.jwt.claim.sub',admin::text,true);
end; $test$;
reset role;
