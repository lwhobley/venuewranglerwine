set local role authenticated;
do $test$
declare o uuid:=current_setting('workforce_test.org')::uuid; v uuid:=current_setting('workforce_test.venue')::uuid;
 h public.shifts; roleid uuid; d uuid; staff uuid:=current_setting('workforce_test.staff')::uuid;
 a jsonb; p uuid; source uuid; template uuid; entry uuid; revision integer; failed boolean; local_date date;
begin
 select job_role_id,department_id,period_id into roleid,d,source from public.shifts where id=current_setting('workforce_test.shift')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"schedule_periods","data":{"name":"Copied week","starts_on":"2027-01-11","ends_on":"2027-01-18"}}');p:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'copy_schedule',jsonb_build_object('source_period_id',source,'target_period_id',p,'revision',1,'include_assignments',false));
 if (a->>'copied')::int<>2 then raise exception 'copy did not preserve shifts'; end if;
 if exists(select 1 from public.shifts where period_id=p and status<>'draft') then raise exception 'copy published without approval'; end if;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"schedule_templates","data":{"name":"Opening team"}}');template:=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','schedule_template_shifts','data',
 jsonb_build_object('template_id',template,'job_role_id',roleid,'department_id',d,'weekday',1,'starts_local','09:00','duration_minutes',480,'headcount',1)));
 a:=public.workforce_command(o,v,gen_random_uuid(),'apply_template',jsonb_build_object('template_id',template,'target_period_id',p,'revision',2));
 if (a->>'copied')::int<>1 then raise exception 'template failed'; end if;
 failed:=false;begin perform public.wf_local_utc('2027-03-14 02:30','America/Chicago'); exception when others then failed:=true; end;
 if not failed then raise exception 'DST gap copy accepted'; end if;
 -- Server helper is intentionally private; test its DST behavior after reset role below.
 perform public.workforce_command(o,v,gen_random_uuid(),'save','{"table":"workforce_settings","data":{"geofence_address":"Test venue address","geofence_latitude":0,"geofence_longitude":0,"geofence_radius_ft":1000}}');
 local_date:=(now() at time zone 'America/Chicago')::date;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','schedule_periods','data',
 jsonb_build_object('name','Attendance test','starts_on',local_date,'ends_on',local_date+2)));p:=(a->>'id')::uuid;
 a:=public.workforce_command(o,v,gen_random_uuid(),'save_shift',jsonb_build_object('period_id',p,'job_role_id',roleid,'department_id',d,
 'starts_at',now()+interval '5 minutes','ends_at',now()+interval '65 minutes','headcount',1));
 select * into h from public.shifts where id=(a->>'id')::uuid;
 perform public.workforce_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('shift_id',h.id,'revision',1,'staff_id',staff));
 perform public.workforce_command(o,v,gen_random_uuid(),'publish',jsonb_build_object('period_id',p,'revision',1));
 a:=public.workforce_command(o,v,gen_random_uuid(),'clock_in',jsonb_build_object('shift_id',h.id,'location',jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false)));entry:=(a->>'id')::uuid;
 failed:=false;begin perform public.workforce_command(o,v,gen_random_uuid(),'clock_in',jsonb_build_object('shift_id',h.id,'location',jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false))); exception when others then failed:=sqlerrm='already_clocked_in'; end;
 if not failed then raise exception 'duplicate clock accepted'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'break_start','{}');
 failed:=false;begin perform public.workforce_command(o,v,gen_random_uuid(),'break_start','{}');exception when unique_violation then failed:=true;end;
 if not failed then raise exception 'duplicate break accepted'; end if;
 perform public.workforce_command(o,v,gen_random_uuid(),'break_end','{}');
 perform public.workforce_command(o,v,gen_random_uuid(),'clock_out',jsonb_build_object('location',jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false)));
 select time_entries.revision into revision from public.time_entries where id=entry;
 perform public.workforce_command(o,v,gen_random_uuid(),'correct_time',jsonb_build_object('id',entry,'revision',revision,
 'clock_in',now()-interval '1 minute','clock_out',clock_timestamp(),'reason','Verified clock start correction'));
 if not exists(select 1 from public.time_entry_corrections where time_entry_id=entry and previous_state is not null) then raise exception 'correction history missing'; end if;
 a:=public.workforce_labor_report(o,v,local_date,local_date+2);
 if jsonb_array_length(a)=0 then raise exception 'attendance labor report missing'; end if;
end; $test$;
reset role;
do $dst$
declare failed boolean;
begin
 failed:=false;begin perform public.wf_local_utc('2027-03-14 02:30','America/Chicago');exception when others then failed:=sqlerrm='dst_gap_or_ambiguity_choose_explicit_time';end;
 if not failed then raise exception 'server DST gap failed';end if;
 failed:=false;begin perform public.wf_local_utc('2027-11-07 01:30','America/Chicago');exception when others then failed:=sqlerrm='dst_gap_or_ambiguity_choose_explicit_time';end;
 if not failed then raise exception 'server DST fold failed';end if;
end; $dst$;
