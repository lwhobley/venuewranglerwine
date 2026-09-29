-- Clock geofences are mandatory, venue scoped and capped at 1,000 feet.
alter table public.workforce_settings
 add column geofence_address text,
 add column geofence_latitude double precision,
 add column geofence_longitude double precision,
 add column geofence_radius_ft integer not null default 1000 check (geofence_radius_ft between 1 and 1000),
 add constraint workforce_geofence_center check (
   (geofence_latitude is null and geofence_longitude is null) or
   (geofence_latitude is not null and geofence_longitude is not null and
    geofence_latitude between -90 and 90 and geofence_longitude between -180 and 180)),
 add constraint workforce_geofence_address check (geofence_latitude is null or coalesce(length(trim(geofence_address)),0) > 0);

create function public.wf_check_clock_geofence(o uuid,v uuid,p jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare cfg public.workforce_settings; lat double precision; lon double precision;
 accuracy double precision; captured timestamptz; distance_m double precision; a double precision;
begin
 select * into cfg from public.workforce_settings where organization_id=o and venue_id=v and deleted_at is null;
 if not found or cfg.geofence_latitude is null or cfg.geofence_longitude is null then
   raise exception 'clock_geofence_not_configured'; end if;
 if jsonb_typeof(p) is distinct from 'object' or
    jsonb_typeof(p->'latitude') is distinct from 'number' or
    jsonb_typeof(p->'longitude') is distinct from 'number' or
    jsonb_typeof(p->'accuracy_m') is distinct from 'number' or
    jsonb_typeof(p->'captured_at') is distinct from 'string' or
    jsonb_typeof(p->'is_mocked') is distinct from 'boolean' then
   raise exception 'clock_location_required'; end if;
 if (p->>'is_mocked')::boolean then raise exception 'clock_mock_location'; end if;
 begin
   lat:=(p->>'latitude')::double precision; lon:=(p->>'longitude')::double precision;
   accuracy:=(p->>'accuracy_m')::double precision; captured:=(p->>'captured_at')::timestamptz;
 exception when others then raise exception 'clock_location_invalid'; end;
 if not (lat between -90 and 90) or not (lon between -180 and 180) or not (accuracy between 0 and 50) then
   raise exception 'clock_location_invalid'; end if;
 if not (captured between clock_timestamp()-interval '90 seconds' and clock_timestamp()+interval '15 seconds') then
   raise exception 'clock_location_stale'; end if;
 if accuracy > least(50.0,cfg.geofence_radius_ft*0.3048/2.0) then
   raise exception 'clock_location_inaccurate'; end if;
 a:=power(sin(radians(lat-cfg.geofence_latitude)/2),2)+cos(radians(lat))*cos(radians(cfg.geofence_latitude))*power(sin(radians(lon-cfg.geofence_longitude)/2),2);
 distance_m:=6371008.8*2*asin(sqrt(least(1.0,greatest(0.0,a))));
 -- The accuracy circle must fit inside the boundary; uncertain edge fixes must retry.
 if distance_m+accuracy > cfg.geofence_radius_ft*0.3048 then
   raise exception 'clock_outside_geofence'; end if;
end; $$;
revoke all on function public.wf_check_clock_geofence(uuid,uuid,jsonb) from public,anon,authenticated;


-- Preserve existing workforce command bodies and ACLs. Abort on unexpected code.
do $patch$
declare body text; anchor text;
begin
 body:=pg_get_functiondef('public.wf_save(uuid,uuid,jsonb)'::regprocedure);
 anchor:=$anchor$'break_after_minutes','reminder_minutes']; permission:='schedule.settings';$anchor$;
 if (length(body)-length(replace(body,anchor,'')))/length(anchor) <> 1 then
   raise exception 'unexpected_workforce_settings_definition'; end if;
 execute replace(body,anchor,$new$'break_after_minutes','reminder_minutes','geofence_address','geofence_latitude','geofence_longitude','geofence_radius_ft']; permission:='schedule.settings';$new$);
 body:=pg_get_functiondef('public.workforce_command(uuid,uuid,uuid,text,jsonb)'::regprocedure);
 anchor:=E' if p_action=''clock_in'' then\n if myself is null';
 if (length(body)-length(replace(body,anchor,'')))/length(anchor) <> 1 then
   raise exception 'unexpected_workforce_clock_definition'; end if;
 execute replace(body,anchor,E' if p_action in (''clock_in'',''clock_out'') then perform public.wf_check_clock_geofence(p_org,p_venue,p_payload->''location''); end if;\n'||anchor);
end; $patch$;


-- Venue creation and initial geofence configuration commit together.
create function public.create_venue_geofenced(
 p_organization_id uuid,p_name text,p_slug text,p_timezone text,p_currency_code text,
 p_country_code text,p_address_line1 text,p_city text,p_region text,p_postal_code text,
 p_service_style text,p_latitude double precision,p_longitude double precision,p_radius_ft integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare v uuid;
begin
 if p_latitude is null or p_longitude is null or not (p_latitude between -90 and 90)
 or not (p_longitude between -180 and 180) or p_radius_ft is null or not (p_radius_ft between 1 and 1000)
 or nullif(trim(p_address_line1),'') is null then raise exception 'venue_geofence_required'; end if;
 v:=public.create_venue(p_organization_id,p_name,p_slug,p_timezone,p_currency_code,p_country_code,
   p_address_line1,p_city,p_region,p_postal_code,p_service_style);
 perform set_config('app.workforce_venue',v::text,true);
 perform set_config('app.workforce_action','save',true);
 perform public.wf_save(p_organization_id,v,jsonb_build_object('table','workforce_settings','data',
   jsonb_build_object('geofence_address',p_address_line1,'geofence_latitude',p_latitude,
   'geofence_longitude',p_longitude,'geofence_radius_ft',p_radius_ft)));
 return v;
end; $$;
revoke all on function public.create_venue_geofenced(uuid,text,text,text,text,text,text,text,text,text,text,double precision,double precision,integer) from public,anon;
grant execute on function public.create_venue_geofenced(uuid,text,text,text,text,text,text,text,text,text,text,double precision,double precision,integer) to authenticated;
-- Existing integrations may create an unconfigured venue; its clock punches fail closed.
