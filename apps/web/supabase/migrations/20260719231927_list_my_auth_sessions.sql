-- Self-service auth session audit for Account → Connections.
-- Reads/writes auth.sessions for the caller only (security definer).

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
  order by coalesce(s.refreshed_at, s.updated_at, s.created_at) desc;
$$;

revoke all on function public.list_my_auth_sessions() from public;
grant execute on function public.list_my_auth_sessions() to authenticated;

create or replace function public.revoke_my_auth_session(p_session_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_session_id is null then
    raise exception 'session id required';
  end if;

  -- Refresh tokens cascade / orphan-clean with the session row.
  delete from auth.sessions s
  where s.id = p_session_id
    and s.user_id = auth.uid();

  get diagnostics deleted = row_count;

  if deleted > 0 then
    delete from auth.refresh_tokens rt
    where rt.session_id = p_session_id;
  end if;

  return deleted > 0;
end;
$$;

revoke all on function public.revoke_my_auth_session(uuid) from public;
grant execute on function public.revoke_my_auth_session(uuid) to authenticated;

-- Called by mint-desktop-session (service role) to label the app session.
create or replace function public.service_label_auth_session(
  p_session_id uuid,
  p_user_agent text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_session_id is null then
    raise exception 'session id required';
  end if;

  update auth.sessions
  set user_agent = nullif(trim(p_user_agent), '')
  where id = p_session_id;
end;
$$;

revoke all on function public.service_label_auth_session(uuid, text) from public;
grant execute on function public.service_label_auth_session(uuid, text) to service_role;
