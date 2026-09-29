begin;
-- Local CI has no users; the fixture admin is rolled back with the test.
do $fixture$ begin
 if not exists(select 1 from public.platform_admins) then
 insert into auth.users(id,email,raw_user_meta_data) values('10000000-0000-4000-8000-000000000088','floor-ci@example.invalid','{"display_name":"Floor CI"}');
 insert into public.profiles(id,display_name,email) values('10000000-0000-4000-8000-000000000088','Floor CI','floor-ci@example.invalid') on conflict(id) do nothing;
 insert into public.platform_admins(user_id) values('10000000-0000-4000-8000-000000000088');
 end if;
end $fixture$;
select set_config('request.jwt.claim.sub',(select user_id::text from public.platform_admins order by created_at limit 1),true);
set local role authenticated;
do $test$
declare o uuid;v uuid;other uuid;p uuid:=gen_random_uuid();a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();c uuid:=gen_random_uuid();
 layout jsonb; snap jsonb; command uuid; answer jsonb;party uuid;second uuid; groupid uuid;version int; failed boolean; serverid uuid;
begin
 o:=public.create_organization('Floor verification','floor-'||substr(gen_random_uuid()::text,1,8),null);
 v:=public.create_venue(o,'Dining','dining','America/Chicago','USD','US',null,null,null,null,'restaurant');
 other:=public.create_venue(o,'Other room venue','other','America/Chicago','USD','US',null,null,null,null,'restaurant');
 perform set_config('floor_test.org',o::text,true);perform set_config('floor_test.venue',v::text,true);
 snap:=public.floor_snapshot(o,v);
 if jsonb_array_length(snap->'plans')<>0 or jsonb_array_length(snap->'tables')<>0 then raise exception 'New floor not blank';end if;
 layout:=jsonb_build_object('id',p,'revision',0,'name','Dining room','width',1200,'height',800,'tables',jsonb_build_array(
 jsonb_build_object('id',a,'label','T1','capacity',4,'x',100,'y',100,'width',100,'height',80,'angle',0,'shape','rectangle','accessible',true),
 jsonb_build_object('id',b,'label','T2','capacity',4,'x',220,'y',100,'width',100,'height',80,'angle',0,'shape','round'),
 jsonb_build_object('id',c,'label','T3','capacity',8,'x',400,'y',100,'width',160,'height',80,'angle',0,'shape','booth','accessible',true)),
 'objects',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'table_id',a,'kind','chair','x',100,'y',65,'width',30,'height',30)));
 command:=gen_random_uuid();answer:=public.floor_command(o,v,command,'save_layout',layout);
 if public.floor_command(o,v,command,'save_layout',layout)<>answer then raise exception 'Replay failed';end if;
 failed:=false;begin perform public.floor_command(o,v,command,'save_layout',layout||'{"name":"Changed"}');exception when others then failed:=sqlerrm like '%command_reuse%';end;if not failed then raise exception 'Changed replay accepted';end if;
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'save_layout',layout);exception when others then failed:=sqlerrm like '%floor_stale%';end;if not failed then raise exception 'Stale layout accepted';end if;
 snap:=public.floor_snapshot(o,v);
 if jsonb_array_length(snap->'tables')<>3 or jsonb_array_length(snap->'objects')<>1 then raise exception 'Furniture missing';end if;
 failed:=false;begin perform public.floor_command(o,other,gen_random_uuid(),'save_layout',layout);exception when others then failed:=sqlerrm like '%floor_scope%';end;if not failed then raise exception 'Cross venue layout accepted';end if;
 answer:=public.floor_command(o,v,gen_random_uuid(),'combine',jsonb_build_object('table_ids',jsonb_build_array(a,b),'revisions',jsonb_build_object(a::text,1,b::text,1),'label','T1 + T2'));groupid:=(answer->>'id')::uuid;
 answer:=public.floor_command(o,v,gen_random_uuid(),'create_party','{"guest_name":"Test walk in","party_size":6,"walk_in":true,"accessibility_requested":true,"duration_minutes":90,"quoted_wait_minutes":15}');party:=(answer->>'id')::uuid;
 perform public.floor_command(o,v,gen_random_uuid(),'seat',jsonb_build_object('id',party,'revision',1,'table_ids',jsonb_build_array(a)));
 snap:=public.floor_snapshot(o,v);
 if (select count(*) from jsonb_array_elements(snap->'tables') x where x->>'status'='seated')<>2 then raise exception 'Combined seat did not occupy both';end if;
 -- Probe imports inside subtransactions so the rest of the revision fixture remains fixed.
 begin
 perform public.import_venue_data(o,v,'tables','[{"label":"T1","capacity":"3"}]');
 raise exception 'rollback successful capacity probe' using errcode='P7777';
 exception when sqlstate 'P7777' then null;end;
 failed:=false;begin perform public.import_venue_data(o,v,'tables','[{"label":"T1","capacity":"1"}]');exception when others then failed:=sqlerrm like '%party_exceeds_capacity%';end;if not failed then raise exception 'Import reduced combined capacity below seated party';end if;
 answer:=public.floor_command(o,v,gen_random_uuid(),'create_party','{"guest_name":"Second walk in","party_size":2,"walk_in":true}');second:=(answer->>'id')::uuid;
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'seat',jsonb_build_object('id',second,'revision',1,'table_ids',jsonb_build_array(b)));exception when others then failed:=sqlerrm like '%table_unavailable%' or sqlerrm like '%floor_booking_conflict%';end;if not failed then raise exception 'Double seating accepted';end if;
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'table_status',jsonb_build_object('table_ids',jsonb_build_array(a),'revisions',jsonb_build_object(a::text,3,b::text,3),'status','available'));exception when others then failed:=sqlerrm like '%table_occupied%';end;if not failed then raise exception 'Occupied table cleaned';end if;
 perform public.floor_command(o,v,gen_random_uuid(),'transfer',jsonb_build_object('id',party,'revision',2,'table_ids',jsonb_build_array(c)));
 snap:=public.floor_snapshot(o,v);
 if (select count(*) from jsonb_array_elements(snap->'tables') x where x->>'status'='dirty')<>2 then raise exception 'Transfer did not dirty old unit';end if;
 perform public.complete_reservation(party);
 snap:=public.floor_snapshot(o,v);
 if exists(select 1 from jsonb_array_elements(snap->'tables') x where x->>'status'='seated') then raise exception 'Completion retained occupancy';end if;
 perform public.floor_command(o,v,gen_random_uuid(),'table_status',jsonb_build_object('table_ids',jsonb_build_array(a),'revisions',jsonb_build_object(a::text,4,b::text,4),'status','cleaning'));
 perform public.clear_table(a);
 snap:=public.floor_snapshot(o,v);
 if (select count(*) from jsonb_array_elements(snap->'tables') x where x->>'status'='available')<>2 then raise exception 'Combined clear not atomic';end if;
 perform public.floor_command(o,v,gen_random_uuid(),'uncombine',jsonb_build_object('table_ids',jsonb_build_array(a),'revisions',jsonb_build_object(a::text,6,b::text,6)));
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'seat',jsonb_build_object('id',second,'revision',1,'table_ids',jsonb_build_array(a,b)));exception when others then failed:=sqlerrm like '%floor_combine_first%';end;if not failed then raise exception 'Ungrouped multi seat accepted';end if;
 perform public.floor_command(o,v,gen_random_uuid(),'seat',jsonb_build_object('id',second,'revision',1,'table_ids',jsonb_build_array(a)));
 perform public.complete_reservation(second);perform public.clear_table(a);perform public.clear_table(c);
 answer:=public.floor_command(o,v,gen_random_uuid(),'create_party','{"guest_name":"Booked guest","party_size":2,"reserved_at":"2027-01-01T18:00:00Z","duration_minutes":90}');party:=(answer->>'id')::uuid;
 perform public.floor_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('id',party,'revision',1,'table_ids',jsonb_build_array(c)));
 answer:=public.floor_command(o,v,gen_random_uuid(),'create_party','{"guest_name":"Overlapping booking","party_size":2,"reserved_at":"2027-01-01T18:30:00Z","duration_minutes":90}');second:=(answer->>'id')::uuid;
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('id',second,'revision',1,'table_ids',jsonb_build_array(c)));exception when others then failed:=sqlerrm like '%floor_booking_conflict%';end;if not failed then raise exception 'Overlap assigned';end if;
 failed:=false;begin perform public.floor_command(o,v,gen_random_uuid(),'archive_plan',jsonb_build_object('id',p,'revision',1));exception when others then failed:=sqlerrm like '%floor_in_use%';end;if not failed then raise exception 'Assigned room archived';end if;
 perform public.floor_command(o,v,gen_random_uuid(),'cancel',jsonb_build_object('id',party,'revision',2));
 perform public.floor_command(o,v,gen_random_uuid(),'assign',jsonb_build_object('id',second,'revision',1,'table_ids',jsonb_build_array(c)));
 failed:=false;begin update public.floor_tables set status='available' where id=a;exception when insufficient_privilege then failed:=true;end;if not failed then raise exception 'Direct table write permitted';end if;
end $test$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000099',true);
do $test$
declare failed boolean:=false;
begin
 begin perform public.floor_snapshot(current_setting('floor_test.org')::uuid,current_setting('floor_test.venue')::uuid);exception when insufficient_privilege then failed:=true;end;
 if not failed then raise exception 'Outsider floor read permitted';end if;
 if exists(select 1 from public.floor_plans where venue_id=current_setting('floor_test.venue')::uuid) then raise exception 'Outsider direct floor read';end if;
end $test$;
reset role;
select 'PASS: blank layouts, geometry, replay, stale edits, combined seating, transfers, cleaning, booking overlap, write denial, and venue isolation' as result;
rollback;
