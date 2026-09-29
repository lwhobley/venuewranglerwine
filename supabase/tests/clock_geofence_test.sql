-- Run within tool/verify_workforce.sql's rollback transaction.
set local role authenticated;
do $test$
declare o uuid:=current_setting('workforce_test.org')::uuid;
 v uuid:=current_setting('workforce_test.venue')::uuid; cfg public.workforce_settings;
 action text; failed boolean; location jsonb;
begin
 select * into cfg from public.workforce_settings where venue_id=v;
 perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','workforce_settings',
 'id',cfg.id,'revision',cfg.revision,'data',jsonb_build_object('geofence_address','Test venue address',
 'geofence_latitude',0,'geofence_longitude',0,'geofence_radius_ft',1000)));
 location:=jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false);
 foreach action in array array['clock_in','clock_out'] loop
   failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),action,'{}');
   exception when others then failed:=sqlerrm='clock_location_required'; end;
   if not failed then raise exception '% accepted missing location',action; end if;
   failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),action,jsonb_build_object('location',location||'{"latitude":0.01}'));
   exception when others then failed:=sqlerrm='clock_outside_geofence'; end;
   if not failed then raise exception '% accepted outside location',action; end if;
 end loop;
 select * into cfg from public.workforce_settings where venue_id=v;
 failed:=false; begin perform public.workforce_command(o,v,gen_random_uuid(),'save',jsonb_build_object('table','workforce_settings',
 'id',cfg.id,'revision',cfg.revision,'data','{"geofence_radius_ft":1001}'::jsonb));
 exception when check_violation then failed:=true; end;
 if not failed then raise exception 'radius exceeded 1000 feet'; end if;
 failed:=false; begin perform public.wf_check_clock_geofence(o,v,location); exception when insufficient_privilege then failed:=true; end;
 if not failed then raise exception 'private helper executable'; end if;
end; $test$;
reset role;
do $test$
declare o uuid:=current_setting('workforce_test.org')::uuid; v uuid:=current_setting('workforce_test.venue')::uuid;
 p jsonb; bad jsonb; expected text; failed boolean;
begin
 p:=jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false);
 perform public.wf_check_clock_geofence(o,v,p);
 -- One thousand feet is 304.8 metres, not one thousand metres.
 perform public.wf_check_clock_geofence(o,v,p||'{"latitude":0.0026}');
 for bad,expected in select * from (values
   (p||'{"latitude":0.0028}'::jsonb,'clock_outside_geofence'),
   (p||'{"latitude":0.0027,"accuracy_m":10}'::jsonb,'clock_outside_geofence'),
   (p||'{"latitude":91}'::jsonb,'clock_location_invalid'),
   (p||'{"accuracy_m":-1}'::jsonb,'clock_location_invalid'),
   (p||'{"is_mocked":true}'::jsonb,'clock_mock_location'),
   (p||jsonb_build_object('captured_at',clock_timestamp()-interval '5 minutes'),'clock_location_stale'),
   (p||jsonb_build_object('captured_at',clock_timestamp()+interval '5 minutes'),'clock_location_stale')) t(payload,error)
 loop
   failed:=false; begin perform public.wf_check_clock_geofence(o,v,bad); exception when others then failed:=sqlerrm=expected; end;
   if not failed then raise exception 'geofence guard failed: %',expected; end if;
 end loop;
 failed:=false; begin perform public.wf_check_clock_geofence(o,gen_random_uuid(),p);
 exception when others then failed:=sqlerrm='clock_geofence_not_configured'; end;
 if not failed then raise exception 'unconfigured venue accepted'; end if;
end; $test$;
