-- Execute after staged migrations inside the same transaction; rollback all fixtures.
select set_config('request.jwt.claim.sub',(select user_id::text from public.platform_admins order by created_at limit 1),true);
set local role authenticated;
do $test$
declare o uuid; v uuid; v2 uuid; d uuid; roleid uuid; staff uuid; period uuid; h uuid;
 cmd uuid:=gen_random_uuid(); payload jsonb; a jsonb; b jsonb; failed boolean; snap jsonb;
begin
 o:=public.create_organization('Workforce verification','wf-'||substr(gen_random_uuid()::text,1,8),null);
 v:=public.create_venue(o,'First venue','first','America/Chicago','USD','US',null,null,null,null,'restaurant');
 v2:=public.create_venue(o,'Second venue','second','America/Chicago','USD','US',null,null,null,null,'restaurant');
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"departments","data":{"name":"Service","code":"FOH"}}'); d:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','job_roles','data',
 jsonb_build_object('name','Server','key','server','department_id',d,'required_certifications',jsonb_build_array('food')))); roleid:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_profiles','data',
 jsonb_build_object('user_id',auth.uid(),'display_name','Verification staff'))); staff:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_role_assignments','data',jsonb_build_object('staff_id',staff,'job_role_id',roleid)));
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"schedule_periods","data":{"name":"Test week","starts_on":"2027-01-04","ends_on":"2027-01-11"}}'); period:=(a->>'id')::uuid;
 payload:=jsonb_build_object('period_id',period,'job_role_id',roleid,'department_id',d,'starts_at','2027-01-05T16:00:00Z','ends_at','2027-01-05T22:00:00Z','headcount',1);
 a:=public.workforce_command(o,v,cmd,'save_shift',payload); h:=(a->>'id')::uuid;
 b:=public.workforce_command(o,v,cmd,'save_shift',payload);
 if a<>b then raise exception 'idempotency replay changed'; end if;
 failed:=false; begin perform public.workforce_command(o,v,cmd,'save_shift',payload||'{"headcount":2}'); exception when others then failed:=true; end;
 if not failed then raise exception 'idempotency reuse accepted'; end if;
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',h,'revision',1,'staff_id',staff)); exception when others then failed:=sqlerrm='required_certification_missing'; end;
 if not failed then raise exception 'certification guard failed'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','staff_certifications','data',jsonb_build_object('staff_id',staff,'certification_key','food','expires_on','2028-01-01','status','verified')));
 a:=public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',h,'revision',1,'staff_id',staff));
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'save_shift',payload||jsonb_build_object('id',h,'revision',1)); exception when serialization_failure then failed:=true; end;
 if not failed then raise exception 'stale update accepted'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'publish',jsonb_build_object('period_id',period,'revision',1));
 if not exists(select 1 from public.shifts where id=h and status='published') then raise exception 'publish failed'; end if;
 failed:=false; begin perform public.workforce_command(o,v2,gen_random_uuid(),'save',jsonb_build_object('table','staff_role_assignments','data',jsonb_build_object('staff_id',staff,'job_role_id',roleid))); exception when others then failed:=position('cross_scope_reference' in sqlerrm)>0; end;
 if not failed then raise exception 'cross venue reference accepted'; end if;
 failed:=false; begin update public.shifts set headcount=2 where id=h; exception when insufficient_privilege then failed:=true; end;
 if not failed then raise exception 'direct write accepted'; end if;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','employee_wage_rates','data',jsonb_build_object('staff_id',staff,'hourly_rate','12.3456','currency_code','USD','effective_from','2027-01-01')));
 snap:=public.workforce_snapshot(o,v,'2027-01-04T00:00:00Z','2027-01-12T00:00:00Z');
 if snap->'employee_wage_rates'->0->>'hourly_rate'<>'12.3456' then raise exception 'decimal serialization lost precision'; end if;
 if jsonb_array_length(snap->'schedule_versions')<>1 or jsonb_array_length(snap->'shift_change_events')<6 then raise exception 'history missing'; end if;
 perform set_config('workforce_test.org',o::text,true); perform set_config('workforce_test.venue',v::text,true);
 perform set_config('workforce_test.shift',h::text,true); perform set_config('workforce_test.staff',staff::text,true);
end; $test$;
reset role;
