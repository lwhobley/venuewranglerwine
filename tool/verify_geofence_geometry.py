"""Exercise the actual SQL boundary checker in an isolated temporary Postgres.

This checks geometry and validation, not Supabase authorization/integration.
Requires a local PostgreSQL installation. Never connects to production.
"""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
bin_dir = Path(os.environ.get('GEOFENCE_PG_BIN', r'C:\Program Files\PostgreSQL\18\bin'))
sql = (root / 'supabase/migrations/20260929090000_clock_geofence.sql').read_text()
helper = sql[sql.index('create function public.wf_check_clock_geofence'):sql.index('-- Preserve existing workforce')]
ddl = sql[sql.index('alter table'):sql.index('create function')]
test = '''
create role anon; create role authenticated;
create table public.workforce_settings(organization_id uuid,venue_id uuid,deleted_at timestamptz);
''' + ddl + helper + '''
insert into public.workforce_settings(organization_id,venue_id,geofence_address,geofence_latitude,geofence_longitude)
values ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','Fixture',0,0);
do $test$
declare o uuid:='00000000-0000-0000-0000-000000000001'; v uuid:='00000000-0000-0000-0000-000000000002';
 p jsonb; bad jsonb; expected text; failed boolean;
begin
 p:=jsonb_build_object('latitude',0,'longitude',0,'accuracy_m',1,'captured_at',clock_timestamp(),'is_mocked',false);
 perform public.wf_check_clock_geofence(o,v,p);
 perform public.wf_check_clock_geofence(o,v,p||'{"latitude":0.0026}');
 for bad,expected in select * from (values
   (p||'{"latitude":0.0028}'::jsonb,'clock_outside_geofence'),
   (p||'{"latitude":0.0027,"accuracy_m":10}'::jsonb,'clock_outside_geofence'),
   (p||'{"latitude":91}'::jsonb,'clock_location_invalid'),
   (p||'{"accuracy_m":-1}'::jsonb,'clock_location_invalid'),
   (p||'{"is_mocked":true}'::jsonb,'clock_mock_location'),
   (p-'accuracy_m','clock_location_required'),
   (p||jsonb_build_object('captured_at',clock_timestamp()-interval '5 minutes'),'clock_location_stale'),
   (p||jsonb_build_object('captured_at',clock_timestamp()+interval '5 minutes'),'clock_location_stale')) t(payload,error)
 loop
   failed:=false; begin perform public.wf_check_clock_geofence(o,v,bad); exception when others then failed:=sqlerrm=expected; end;
   if not failed then raise exception 'geofence guard failed: %',expected; end if;
 end loop;
 failed:=false; begin perform public.wf_check_clock_geofence(o,gen_random_uuid(),p);
 exception when others then failed:=sqlerrm='clock_geofence_not_configured'; end;
 if not failed then raise exception 'unconfigured venue accepted'; end if;
 failed:=false; begin update public.workforce_settings set geofence_radius_ft=1001; exception when check_violation then failed:=true; end;
 if not failed then raise exception 'radius cap failed'; end if;
 update public.workforce_settings set geofence_radius_ft=100;
 failed:=false; begin perform public.wf_check_clock_geofence(o,v,p||'{"accuracy_m":20}');
 exception when others then failed:=sqlerrm='clock_location_inaccurate'; end;
 if not failed then raise exception 'accuracy guard failed'; end if;
 raise notice 'Geofence geometry and validation passed';
end; $test$;
'''
def run(name, *args):
    # Windows server children can inherit pipes; use a file rather than PIPE.
    with tempfile.TemporaryFile(mode='w+t') as output:
        result = subprocess.run([str(bin_dir / (name+'.exe')), *map(str,args)], stdout=output, stderr=output, text=True)
        if result.returncode:
            output.seek(0)
            raise RuntimeError(output.read())

with tempfile.TemporaryDirectory(prefix='vw-geofence-') as directory:
    base = Path(directory); cluster = base / 'data'; fixture = base / 'test.sql'
    fixture.write_text(test)
    run('initdb','-D',cluster,'-U','geofence_test','-A','trust','--no-locale','-E','UTF8')
    started = False
    try:
        run('pg_ctl','-D',cluster,'-l',base/'postgres.log','-o','-p 55439 -h 127.0.0.1','-w','start')
        started = True
        run('psql','-h','127.0.0.1','-p','55439','-U','geofence_test','-d','postgres','-v','ON_ERROR_STOP=1','-f',fixture)
        print('PASS: actual SQL geofence geometry, radius cap, missing/stale/mock/uncertain location and unconfigured venue rejection.')
    except subprocess.CalledProcessError as error:
        print(error.stderr); raise
    finally:
        if started: run('pg_ctl','-D',cluster,'-m','immediate','-w','stop')
