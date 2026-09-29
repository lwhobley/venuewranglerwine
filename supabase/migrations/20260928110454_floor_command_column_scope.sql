create or replace function public.floor_command(p_org uuid,p_venue uuid,p_command uuid,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare req jsonb:=jsonb_build_object('action',p_action,'payload',p_payload); previous public.floor_commands;
 p public.floor_plans; t public.floor_tables; r public.reservations; rowdata jsonb; ids uuid[]; oldids uuid[]; pid uuid;
 tid uuid; gid uuid; rid uuid; guest uuid; v_capacity integer; count_ids integer; result jsonb; v_server uuid;
 start_time timestamptz; end_time timestamptz; v_status text; occupied boolean;
begin
 if auth.uid() is null then raise exception 'not_authenticated'; end if;
 if p_command is null or p_payload is null or jsonb_typeof(p_payload)<>'object' then raise exception 'invalid_floor_command'; end if;
 if not exists(select 1 from public.venues where id=p_venue and organization_id=p_org and deleted_at is null) then raise exception 'venue_not_found'; end if;
 -- Every path, including legacy RPC wrappers, takes the same venue lock before row locks.
 perform pg_advisory_xact_lock(hashtextextended('floor:'||p_venue::text,0));
 select * into previous from public.floor_commands where id=p_command;
 if previous.id is not null then
 if previous.actor_id<>auth.uid() or previous.organization_id<>p_org or previous.venue_id<>p_venue or previous.request<>req then raise exception 'command_reuse'; end if;
 if not public.has_scoped_permission(p_org,p_venue,'floor.read') and not public.has_scoped_permission(p_org,p_venue,'reservation.read') then raise exception 'permission_denied' using errcode='42501'; end if;
 return previous.result; end if;
 if p_action in ('save_layout','archive_plan') then
 perform public.require_venue_permission(p_org,p_venue,'floor.design');
 pid:=(p_payload->>'id')::uuid;
 select * into p from public.floor_plans where id=pid;
 if p.id is not null and (p.organization_id<>p_org or p.venue_id<>p_venue or p.deleted_at is not null) then raise exception 'floor_scope'; end if;
 if (p.id is null and coalesce((p_payload->>'revision')::int,0)<>0) or (p.id is not null and p.revision is distinct from (p_payload->>'revision')::int) then raise exception 'floor_stale' using errcode='40001'; end if;
 if p_action='archive_plan' then
 if p.id is null then raise exception 'floor_not_found'; end if;
 if exists(select 1 from public.floor_tables f where f.plan_id=pid and (f.status='seated' or exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=f.id and b.status in ('booked','waiting','seated')))) then raise exception 'floor_in_use'; end if;
 update public.floor_tables set deleted_at=now(),revision=revision+1 where plan_id=pid;
 delete from public.floor_objects where plan_id=pid;
 update public.floor_plans set deleted_at=now(),revision=revision+1,updated_at=now() where id=pid;
 result:=jsonb_build_object('id',pid);
 else
 if jsonb_typeof(p_payload->'tables')<>'array' or jsonb_typeof(p_payload->'objects')<>'array' or jsonb_array_length(p_payload->'tables')>200 or jsonb_array_length(p_payload->'objects')>600 then raise exception 'invalid_floor_layout'; end if;
 if nullif(p_payload->>'background_path','') is not null and
 (p_payload->>'background_path' not like p_org::text||'/'||p_venue::text||'/'||pid::text||'/%' or not exists(select 1 from storage.objects where bucket_id='floor-plan-images' and name=p_payload->>'background_path')) then raise exception 'floor_image_not_found'; end if;
 insert into public.floor_plans(id,organization_id,venue_id,name,width,height,background_path,background_x,background_y,background_width,background_height,background_angle,background_opacity)
 values(pid,p_org,p_venue,btrim(p_payload->>'name'),(p_payload->>'width')::int,(p_payload->>'height')::int,nullif(p_payload->>'background_path',''),
 coalesce((p_payload->>'background_x')::float8,0),coalesce((p_payload->>'background_y')::float8,0),coalesce((p_payload->>'background_width')::float8,1200),coalesce((p_payload->>'background_height')::float8,800),coalesce((p_payload->>'background_angle')::float8,0),coalesce((p_payload->>'background_opacity')::float8,.45))
 on conflict(id) do update set name=excluded.name,width=excluded.width,height=excluded.height,background_path=excluded.background_path,
 background_x=excluded.background_x,background_y=excluded.background_y,background_width=excluded.background_width,background_height=excluded.background_height,
 background_angle=excluded.background_angle,background_opacity=excluded.background_opacity,revision=floor_plans.revision+1,updated_at=now();
 select array_agg((value->>'id')::uuid) into ids from jsonb_array_elements(p_payload->'tables');
 ids:=coalesce(ids,'{}');
 if cardinality(ids)<>(select count(distinct x) from unnest(ids) x) then raise exception 'invalid_floor_layout'; end if;
 for t in select * from public.floor_tables where plan_id=pid and deleted_at is null and not(id=any(ids)) loop
 if t.group_id is not null or t.status='seated' or exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=t.id and b.status in ('booked','waiting','seated')) then raise exception 'floor_in_use'; end if;
 update public.floor_tables set deleted_at=now(),revision=revision+1 where id=t.id;
 end loop;
 for rowdata in select value from jsonb_array_elements(p_payload->'tables') loop
 tid:=(rowdata->>'id')::uuid; select * into t from public.floor_tables where id=tid;
 if t.id is not null and (t.organization_id<>p_org or t.venue_id<>p_venue or (t.plan_id is not null and t.plan_id<>pid) or t.deleted_at is not null) then raise exception 'floor_scope'; end if;
 if t.id is not null and t.revision is distinct from (rowdata->>'revision')::int then raise exception 'floor_stale' using errcode='40001'; end if;
 if not public.floor_server_valid(p_org,p_venue,(rowdata->>'server_user_id')::uuid) then raise exception 'floor_server_invalid'; end if;
 if t.status='seated' and (t.label is distinct from rowdata->>'label' or t.capacity is distinct from (rowdata->>'capacity')::int or t.x is distinct from (rowdata->>'x')::float8 or t.y is distinct from (rowdata->>'y')::float8 or t.width is distinct from (rowdata->>'width')::float8 or t.height is distinct from (rowdata->>'height')::float8 or t.angle is distinct from (rowdata->>'angle')::float8 or t.shape is distinct from rowdata->>'shape') then raise exception 'floor_in_use'; end if;
 if t.id is not null and (rowdata->>'capacity')::int<t.capacity and exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=t.id and b.status in ('booked','waiting')) then raise exception 'floor_in_use'; end if;
 if (rowdata->>'x')::float8+(rowdata->>'width')::float8>(p_payload->>'width')::int or (rowdata->>'y')::float8+(rowdata->>'height')::float8>(p_payload->>'height')::int then raise exception 'floor_out_of_bounds'; end if;
 insert into public.floor_tables(id,organization_id,venue_id,plan_id,label,capacity,section,server_user_id,x,y,width,height,angle,shape,accessible,notes)
 values(tid,p_org,p_venue,pid,btrim(rowdata->>'label'),(rowdata->>'capacity')::int,coalesce(rowdata->>'section',''),(rowdata->>'server_user_id')::uuid,
 (rowdata->>'x')::float8,(rowdata->>'y')::float8,(rowdata->>'width')::float8,(rowdata->>'height')::float8,(rowdata->>'angle')::float8,rowdata->>'shape',coalesce((rowdata->>'accessible')::boolean,false),coalesce(rowdata->>'notes',''))
 on conflict(id) do update set plan_id=excluded.plan_id,label=excluded.label,capacity=excluded.capacity,section=excluded.section,server_user_id=excluded.server_user_id,
 x=excluded.x,y=excluded.y,width=excluded.width,height=excluded.height,angle=excluded.angle,shape=excluded.shape,accessible=excluded.accessible,notes=excluded.notes,revision=floor_tables.revision+1;
 end loop;
 delete from public.floor_objects where plan_id=pid;
 for rowdata in select value from jsonb_array_elements(p_payload->'objects') loop
 if exists(select 1 from public.floor_objects where id=(rowdata->>'id')::uuid) then raise exception 'floor_scope'; end if;
 if rowdata->>'table_id' is not null and not((rowdata->>'table_id')::uuid=any(ids)) then raise exception 'floor_scope'; end if;
 if (rowdata->>'x')::float8+(rowdata->>'width')::float8>(p_payload->>'width')::int or (rowdata->>'y')::float8+(rowdata->>'height')::float8>(p_payload->>'height')::int then raise exception 'floor_out_of_bounds'; end if;
 insert into public.floor_objects(id,organization_id,venue_id,plan_id,table_id,kind,x,y,width,height,angle,label)
 values((rowdata->>'id')::uuid,p_org,p_venue,pid,(rowdata->>'table_id')::uuid,rowdata->>'kind',(rowdata->>'x')::float8,(rowdata->>'y')::float8,(rowdata->>'width')::float8,(rowdata->>'height')::float8,coalesce((rowdata->>'angle')::float8,0),coalesce(rowdata->>'label',''));
 end loop;
 select jsonb_build_object('id',pid,'revision',revision) into result from public.floor_plans where id=pid;
 end if;
 elsif p_action='create_party' then
 perform public.require_venue_permission(p_org,p_venue,'reservation.write');
 guest:=(p_payload->>'guest_id')::uuid;
 if guest is null then guest:=public.create_guest(p_org,p_venue,p_payload->>'guest_name',p_payload->>'allergies',p_payload->>'seating_preference',coalesce((p_payload->>'vip')::boolean,false)); end if;
 if not exists(select 1 from public.guests where id=guest and organization_id=p_org and venue_id=p_venue) then raise exception 'guest_not_found'; end if;
 if not public.floor_server_valid(p_org,p_venue,(p_payload->>'server_user_id')::uuid) then raise exception 'floor_server_invalid'; end if;
 v_status:=case when coalesce((p_payload->>'walk_in')::boolean,false) then 'waiting' else 'booked' end;
 start_time:=case when v_status='waiting' then now() else (p_payload->>'reserved_at')::timestamptz end;
 if start_time is null or char_length(coalesce(p_payload->>'notes',''))>2000 or char_length(coalesce(p_payload->>'preferred_section',''))>80 then raise exception 'invalid_floor_party'; end if;
 insert into public.reservations(organization_id,venue_id,guest_id,party_size,reserved_at,status,notes,created_by,duration_minutes,arrived_at,quoted_wait_minutes,preferred_section,accessibility_requested,high_chair,server_user_id)
 values(p_org,p_venue,guest,(p_payload->>'party_size')::int,start_time,v_status,nullif(p_payload->>'notes',''),auth.uid(),coalesce((p_payload->>'duration_minutes')::int,90),case when v_status='waiting' then now() end,(p_payload->>'quoted_wait_minutes')::int,coalesce(p_payload->>'preferred_section',''),coalesce((p_payload->>'accessibility_requested')::boolean,false),coalesce((p_payload->>'high_chair')::boolean,false),(p_payload->>'server_user_id')::uuid)
 returning id into rid; result:=jsonb_build_object('id',rid);
 elsif p_action in ('assign','seat','transfer','complete','arrive','cancel','no_show','edit_party') then
 if p_action in ('assign','cancel','no_show','edit_party') then perform public.require_venue_permission(p_org,p_venue,'reservation.write'); else perform public.require_venue_permission(p_org,p_venue,'reservation.seat'); end if;
 rid:=(p_payload->>'id')::uuid; select * into r from public.reservations where id=rid and organization_id=p_org and venue_id=p_venue for update;
 if r.id is null then raise exception 'reservation_not_found'; end if;
 if r.revision is distinct from (p_payload->>'revision')::int then raise exception 'floor_stale' using errcode='40001'; end if;
 if p_action in ('assign','seat','transfer') then
 if (p_action='transfer' and r.status<>'seated') or (p_action<>'transfer' and r.status not in ('booked','waiting')) then raise exception 'reservation_not_booked'; end if;
 if jsonb_typeof(p_payload->'table_ids')<>'array' or jsonb_array_length(p_payload->'table_ids') not between 1 and 8 then raise exception 'floor_choose_tables'; end if;
 select array_agg(distinct value::uuid) into ids from jsonb_array_elements_text(p_payload->'table_ids');
 -- Selecting a member of a combination always selects the whole seating unit.
 select array_agg(distinct f.id) into ids from public.floor_tables f where f.organization_id=p_org and f.venue_id=p_venue and f.deleted_at is null and
 (f.id=any(ids) or f.group_id in(select group_id from public.floor_tables where id=any(ids) and group_id is not null));
 if ids is null or cardinality(ids)>8 then raise exception 'floor_choose_tables'; end if;
 if exists(select 1 from jsonb_array_elements_text(p_payload->'table_ids') x where not(x.value::uuid=any(ids))) then raise exception 'floor_scope'; end if;
 select count(*),sum(capacity) into count_ids,v_capacity from public.floor_tables where id=any(ids) and plan_id is not null and deleted_at is null;
 if count_ids<>cardinality(ids) or (select count(distinct plan_id) from public.floor_tables where id=any(ids))<>1 then raise exception 'floor_choose_tables'; end if;
 if cardinality(ids)>1 and (select count(distinct coalesce(group_id,id)) from public.floor_tables where id=any(ids))<>1 then raise exception 'floor_combine_first'; end if;
 if r.party_size>v_capacity then raise exception 'party_exceeds_capacity'; end if;
 if r.accessibility_requested and not exists(select 1 from public.floor_tables where id=any(ids) and accessible) then raise exception 'floor_accessibility'; end if;
 if exists(select 1 from public.floor_tables where id=any(ids) and (status in ('dirty','cleaning','blocked') or (status='seated' and not exists(select 1 from public.reservation_floor_tables a where a.reservation_id=rid and a.table_id=floor_tables.id and a.seated)))) then raise exception 'table_unavailable'; end if;
 start_time:=case when p_action='assign' then r.reserved_at else now() end; end_time:=start_time+make_interval(mins=>r.duration_minutes);
 if exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=any(ids) and b.id<>rid and
 (a.seated or (b.status in ('booked','waiting') and tstzrange(b.reserved_at,b.reserved_at+make_interval(mins=>b.duration_minutes),'[)') && tstzrange(start_time,end_time,'[)')))) then raise exception 'floor_booking_conflict'; end if;
 select array_agg(table_id) into oldids from public.reservation_floor_tables where reservation_id=rid;
 if p_action='transfer' then update public.floor_tables set status='dirty',revision=revision+1 where id=any(oldids) and not(id=any(ids)); end if;
 delete from public.reservation_floor_tables where reservation_id=rid;
 insert into public.reservation_floor_tables(reservation_id,table_id,organization_id,venue_id,seated) select rid,x,p_org,p_venue,p_action<>'assign' from unnest(ids) x;
 v_server:=coalesce((p_payload->>'server_user_id')::uuid,r.server_user_id,(select server_user_id from public.floor_tables where id=any(ids) and server_user_id is not null order by label limit 1));
 if not public.floor_server_valid(p_org,p_venue,v_server) then raise exception 'floor_server_invalid'; end if;
 update public.reservations set table_id=ids[1],server_user_id=v_server,status=case when p_action='assign' then status else 'seated' end,seated_at=case when p_action='seat' then now() else seated_at end,revision=revision+1 where id=rid;
 if p_action<>'assign' then update public.floor_tables set status='seated',revision=revision+1 where id=any(ids); end if;
 elsif p_action='complete' then
 if r.status<>'seated' then raise exception 'reservation_not_seated'; end if;
 update public.floor_tables set status='dirty',revision=revision+1 where id in(select table_id from public.reservation_floor_tables where reservation_id=rid);
 update public.reservation_floor_tables set seated=false where reservation_id=rid;
 update public.reservations set status='completed',completed_at=now(),revision=revision+1 where id=rid;
 elsif p_action='arrive' then
 if r.status not in ('booked','waiting') then raise exception 'reservation_not_booked'; end if;
 update public.reservations set arrived_at=coalesce(arrived_at,now()),revision=revision+1 where id=rid;
 elsif p_action in ('cancel','no_show') then
 if r.status not in ('booked','waiting') then raise exception 'reservation_not_booked'; end if;
 update public.reservations set status=case when p_action='cancel' then 'cancelled' else 'no_show' end,revision=revision+1 where id=rid;
 else
 if r.status not in ('booked','waiting','seated') then raise exception 'reservation_not_booked'; end if;
 if not public.floor_server_valid(p_org,p_venue,(p_payload->>'server_user_id')::uuid) or char_length(coalesce(p_payload->>'notes',''))>2000 then raise exception 'invalid_floor_party'; end if;
 update public.reservations set quoted_wait_minutes=(p_payload->>'quoted_wait_minutes')::int,notes=coalesce(p_payload->>'notes',''),server_user_id=(p_payload->>'server_user_id')::uuid,revision=revision+1 where id=rid;
 end if;
 result:=jsonb_build_object('id',rid);
 elsif p_action in ('table_status','combine','uncombine','table_server') then
 if p_action in ('combine','uncombine') then perform public.require_venue_permission(p_org,p_venue,'floor.design'); else perform public.require_venue_permission(p_org,p_venue,'reservation.seat'); end if;
 if jsonb_typeof(p_payload->'table_ids')<>'array' or jsonb_array_length(p_payload->'table_ids') not between 1 and 8 then raise exception 'floor_choose_tables'; end if;
 select array_agg(distinct value::uuid) into ids from jsonb_array_elements_text(p_payload->'table_ids');
 if (select count(*) from public.floor_tables where id=any(ids) and organization_id=p_org and venue_id=p_venue and deleted_at is null)<>cardinality(ids) then raise exception 'floor_scope'; end if;
 for t in select * from public.floor_tables where id=any(ids) loop
 if (p_payload->'revisions'->>t.id::text)::int is distinct from t.revision then raise exception 'floor_stale' using errcode='40001'; end if;
 end loop;
 if p_action='combine' then
 if cardinality(ids)<2 or (select count(distinct plan_id) from public.floor_tables where id=any(ids))<>1 or exists(select 1 from public.floor_tables where id=any(ids) and (plan_id is null or group_id is not null or status<>'available')) then raise exception 'floor_combine_invalid'; end if;
 if exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=any(ids) and b.status in ('booked','waiting','seated')) then raise exception 'floor_in_use'; end if;
 insert into public.floor_table_groups(organization_id,venue_id,plan_id,label) select p_org,p_venue,min(plan_id::text)::uuid,btrim(p_payload->>'label') from public.floor_tables where id=any(ids) returning id into gid;
 update public.floor_tables set group_id=gid,revision=revision+1 where id=any(ids);
 result:=jsonb_build_object('id',gid);
 else
 select array_agg(distinct f.id) into ids from public.floor_tables f where f.organization_id=p_org and f.venue_id=p_venue and f.deleted_at is null and
 (f.id=any(ids) or f.group_id in(select group_id from public.floor_tables where id=any(ids) and group_id is not null));
 -- Revisions of every affected member are required, even if only one was selected.
 for t in select * from public.floor_tables where id=any(ids) loop
 if (p_payload->'revisions'->>t.id::text)::int is distinct from t.revision then raise exception 'floor_stale' using errcode='40001'; end if;
 end loop;
 if p_action='uncombine' then
 if exists(select 1 from public.floor_tables where id=any(ids) and status='seated') or exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=any(ids) and b.status in ('booked','waiting','seated')) then raise exception 'floor_in_use'; end if;
 select array_agg(distinct group_id) into oldids from public.floor_tables where id=any(ids) and group_id is not null;
 update public.floor_tables set group_id=null,revision=revision+1 where id=any(ids);
 delete from public.floor_table_groups where id=any(oldids);
 elsif p_action='table_server' then
 if not public.floor_server_valid(p_org,p_venue,(p_payload->>'server_user_id')::uuid) then raise exception 'floor_server_invalid'; end if;
 update public.floor_tables set server_user_id=(p_payload->>'server_user_id')::uuid,revision=revision+1 where id=any(ids);
 else
 v_status:=p_payload->>'status';
 if v_status not in ('available','reserved','dirty','cleaning','blocked') then raise exception 'invalid_floor_status'; end if;
 if exists(select 1 from public.reservation_floor_tables where table_id=any(ids) and seated) or exists(select 1 from public.floor_tables where id=any(ids) and status='seated') then raise exception 'table_occupied'; end if;
 if v_status in ('blocked','dirty','cleaning') and exists(select 1 from public.reservation_floor_tables a join public.reservations b on b.id=a.reservation_id where a.table_id=any(ids) and b.status in ('booked','waiting')) then raise exception 'floor_in_use'; end if;
 update public.floor_tables set status=v_status,revision=revision+1 where id=any(ids);
 end if;
 result:=jsonb_build_object('table_ids',ids);
 end if;
 else raise exception 'invalid_floor_command'; end if;
 insert into public.audit_events(organization_id,venue_id,actor_id,action,entity_type,entity_id,payload)
 values(p_org,p_venue,auth.uid(),'floor.'||p_action,'floor',coalesce(pid,rid,gid,ids[1]),jsonb_build_object('command_id',p_command,'result',result));
 insert into public.floor_commands(id,organization_id,venue_id,actor_id,request,result) values(p_command,p_org,p_venue,auth.uid(),req,result);
 return result;
end $$;
