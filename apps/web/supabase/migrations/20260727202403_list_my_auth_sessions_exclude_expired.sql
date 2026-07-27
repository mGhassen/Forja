-- Account → Connections should list only usable sessions.
-- GoTrue keeps expired rows in auth.sessions for ~24–72h (not_after / cleanup),
-- so the previous list RPC surfaced them with Revoke even though Auth treats them
-- as expired.

create or replace function public.list_my_auth_sessions()
returns table (
  id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  refreshed_at timestamptz,
  user_agent text,
  ip text,
  aal text
)
language sql
security definer
set search_path = ''
stable
as $$
  select
    s.id,
    s.created_at,
    s.updated_at,
    s.refreshed_at,
    s.user_agent,
    s.ip::text,
    s.aal::text
  from auth.sessions s
  where s.user_id = auth.uid()
    -- Hard-expired (timebox / explicit not_after). GoTrue deletes these later.
    and (s.not_after is null or s.not_after > now())
    -- Must still have a refresh token that can mint a new access token.
    and exists (
      select 1
      from auth.refresh_tokens rt
      where rt.session_id = s.id
        and coalesce(rt.revoked, false) = false
    )
  order by coalesce(s.refreshed_at, s.updated_at, s.created_at) desc;
$$;

revoke all on function public.list_my_auth_sessions() from public;
grant execute on function public.list_my_auth_sessions() to authenticated;
