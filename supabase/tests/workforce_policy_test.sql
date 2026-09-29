set local role authenticated;
do $test$
declare o uuid:=current_setting('workforce_test.org')::uuid; v uuid:=current_setting('workforce_test.venue')::uuid;
 staff uuid:=current_setting('workforce_test.staff')::uuid; h public.shifts; a jsonb; cmd uuid; area uuid;
 d uuid; roleid uuid; shiftid uuid; failed boolean; cert uuid; cfg public.workforce_settings;
begin
 select * into h from public.shifts where id=current_setting('workforce_test.shift')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"venue_areas","data":{"name":"North outlet","code":"NORTH"}}');area:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_qualifications','data',jsonb_build_object('staff_id',staff,'skill_key','service','approved',true)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_availability_rules','data',
 jsonb_build_object('staff_id',staff,'weekday',2,'starts_local','17:00','ends_local','21:00','available',false,'valid_from','2027-01-01')));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_availability_exceptions','data',
 jsonb_build_object('staff_id',staff,'starts_at','2027-01-12T23:00:00Z','ends_at','2027-01-13T02:00:00Z','available',false,'reason','Appointment')));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','time_off_balances','data',jsonb_build_object('staff_id',staff,'category','paid','minutes',480)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','shift_requirements','data',
 jsonb_build_object('period_id',h.period_id,'job_role_id',h.job_role_id,'starts_at',h.starts_at,'ends_at',h.ends_at,'minimum_staff',1)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','shift_notes','confirm_published',true,'data',jsonb_build_object('shift_id',h.id,'body','Arrive in uniform','staff_visible',true)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','shift_break_rules','confirm_published',true,'data',jsonb_build_object('shift_id',h.id,'minimum_minutes',30,'paid',false,'required',true)));
 perform public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"labor_targets","data":{"starts_on":"2027-01-04","ends_on":"2027-01-11","target_minutes":480,"target_cost":"123.4567","target_percent":"24.0000"}}');
 perform public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"labor_forecasts","data":{"service_date":"2027-01-05","forecast_sales":"1000.1234","forecast_covers":50}}');
 select * into cfg from public.workforce_settings where organization_id=o and venue_id=v and deleted_at is null;
 if cfg.id is null then raise exception 'attendance fixture did not create workforce settings'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','workforce_settings',
 'id',cfg.id,'revision',cfg.revision,'data','{"reminder_minutes":30,"overtime_multiplier":"1.5000"}'::jsonb));
 if not exists(select 1 from public.workforce_settings where id=cfg.id and reminder_minutes=30 and overtime_multiplier=1.5)
 then raise exception 'workforce settings update failed'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'message','{"body":"Schedule verification message"}');
 perform public.workforce_command(o,v,gen_random_uuid(),'read_notification',jsonb_build_object('id',(select id from public.notifications where recipient_id=auth.uid() limit 1)));
 perform public.workforce_command(o,v,gen_random_uuid(),'register_push','{"token":"workforce-fixture-token-not-real","platform":"android"}');
 perform public.workforce_push_disable();
 a:=public.workforce_snapshot(o,v,'2027-01-04','2027-01-12');
 if a->'labor_forecasts'->0->>'forecast_sales'<>'1000.1234' then raise exception 'forecast decimal mismatch';end if;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save_shift',jsonb_build_object('period_id',h.period_id,'job_role_id',h.job_role_id,
 'department_id',h.department_id,'area_id',area,'starts_at','2027-01-05T23:00:00Z','ends_at','2027-01-06T02:00:00Z','headcount',1));shiftid:=(a->>'id')::uuid;
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',shiftid,'revision',1,'staff_id',staff));
 exception when others then failed:=sqlerrm='availability_rest_or_hours_conflict';end;
 if not failed then raise exception 'unavailable assignment accepted';end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',shiftid,'revision',1,'staff_id',staff,'override_reason','Verified employee exception'));
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"departments","data":{"name":"Kitchen","code":"BOH"}}');d:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','job_roles','data',jsonb_build_object('name','Cook','key','cook','department_id',d)));roleid:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save_shift',jsonb_build_object('period_id',h.period_id,'job_role_id',roleid,'department_id',d,
 'starts_at','2027-01-08T16:00:00Z','ends_at','2027-01-08T22:00:00Z','headcount',1));shiftid:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','workforce_department_managers','data',
 jsonb_build_object('user_id','10000000-0000-4000-8000-000000000001','department_id',h.department_id)));
 perform set_config('workforce_test.other_shift',shiftid::text,true);
 perform set_config('workforce_test.department',h.department_id::text,true);
end; $test$;
reset role;
update public.memberships set role_key='department_manager' where organization_id=current_setting('workforce_test.org')::uuid and user_id='10000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $department$
declare o uuid:=current_setting('workforce_test.org')::uuid; v uuid:=current_setting('workforce_test.venue')::uuid; failed boolean; a jsonb;
begin
 if exists(select 1 from public.shifts where id=current_setting('workforce_test.other_shift')::uuid) then raise exception 'department scope leaked draft';end if;
 if exists(select 1 from public.employee_wage_rates) then raise exception 'department wage leak';end if;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','schedule_periods','data',
 jsonb_build_object('name','Department draft','starts_on','2027-02-01','ends_on','2027-02-08','department_id',current_setting('workforce_test.department')::uuid)));
 failed:=false;begin perform public.workforce_command(o,v,gen_random_uuid(),'save_shift',jsonb_build_object('id',current_setting('workforce_test.other_shift'),
 'revision',1,'starts_at','2027-01-08T17:00:00Z','ends_at','2027-01-08T23:00:00Z'));
 exception when insufficient_privilege then failed:=true;end;
 if not failed then raise exception 'other department mutation accepted';end if;
end; $department$;
reset role;
