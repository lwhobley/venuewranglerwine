create or replace function public.actor_can_grant(
  p_org uuid,
  p_venue uuid,
  p_role text,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_roles target_role
    where target_role.key = p_role
  )
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.memberships m
      join public.app_roles actor_role on actor_role.key = m.role_key
      join public.app_roles target_role on target_role.key = p_role
      where m.organization_id = p_org
        and m.user_id = (select auth.uid())
        and m.status = 'active'
        and m.deleted_at is null
        and (
          (p_venue is null and m.venue_id is null)
          or (p_venue is not null and (m.venue_id is null or m.venue_id = p_venue))
        )
        and actor_role.rank <= target_role.rank
        and public.membership_allows(m.id, m.role_key, p_permission)
    )
  );
$$;
