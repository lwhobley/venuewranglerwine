do $$
begin
  if (select count(*) from public.app_roles) < 12 then
    raise exception 'role catalog missing';
  end if;
  if (select count(*) from public.permissions) < 46 then
    raise exception 'permission catalog missing';
  end if;
end $$;
