-- Connections still listed many sessions after the not_after filter because almost
-- none are hard-expired: GoTrue keeps rows with live refresh tokens for the full
-- inactivity window (720h). Two extra problems:
--   1) Mint edge functions leave unlabeled Deno/SupabaseEdgeRuntime sessions when
--      labeling fails — UI shows them as "Browser on device".
--   2) Repeated Flutter / browser sign-ins pile up duplicate fingerprints.
-- Hide mint orphans, enforce inactivity, and collapse same-device duplicates.

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
  with usable as (
    select
      s.id,
      s.user_id,
      s.created_at,
      s.updated_at,
      s.refreshed_at,
      s.user_agent,
      s.ip,
      s.aal,
      coalesce(s.refreshed_at, s.updated_at, s.created_at) as last_active
    from auth.sessions s
    where s.user_id = auth.uid()
      and (s.not_after is null or s.not_after > now())
      -- Match hosted Auth inactivity timeout (config.toml / Dashboard = 720h).
      and coalesce(s.refreshed_at, s.updated_at, s.created_at) > now() - interval '720 hours'
      -- Mint leftovers (verifyOtp from Edge before label, or failed label).
      and coalesce(s.user_agent, '') !~* 'supabaseedgeruntime'
      and coalesce(s.user_agent, '') !~* '^deno/'
      and exists (
        select 1
        from auth.refresh_tokens rt
        where rt.session_id = s.id
          and coalesce(rt.revoked, false) = false
      )
  )
  select
    u.id,
    u.created_at,
    u.updated_at,
    u.refreshed_at,
    u.user_agent,
    u.ip::text,
    u.aal::text
  from usable u
  where not exists (
    -- Collapse identical device fingerprints to the most recently active row.
    select 1
    from usable newer
    where newer.id <> u.id
      and coalesce(newer.ip::text, '') = coalesce(u.ip::text, '')
      and coalesce(newer.user_agent, '') = coalesce(u.user_agent, '')
      and newer.last_active > u.last_active
  )
  order by u.last_active desc;
$$;

revoke all on function public.list_my_auth_sessions() from public;
grant execute on function public.list_my_auth_sessions() to authenticated;

-- After minting a labeled desktop/TV session, drop prior sessions of the same
-- label plus any unlabeled Edge mint orphans for that user.
create or replace function public.service_revoke_other_labeled_sessions(
  p_user_id uuid,
  p_keep_session_id uuid,
  p_user_agent text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted int := 0;
begin
  if p_user_id is null or p_keep_session_id is null then
    raise exception 'user id and keep session id required';
  end if;

  delete from auth.refresh_tokens rt
  using auth.sessions s
  where rt.session_id = s.id
    and s.user_id = p_user_id
    and s.id <> p_keep_session_id
    and (
      s.user_agent = nullif(trim(p_user_agent), '')
      or coalesce(s.user_agent, '') ~* 'supabaseedgeruntime'
      or coalesce(s.user_agent, '') ~* '^deno/'
    );

  delete from auth.sessions s
  where s.user_id = p_user_id
    and s.id <> p_keep_session_id
    and (
      s.user_agent = nullif(trim(p_user_agent), '')
      or coalesce(s.user_agent, '') ~* 'supabaseedgeruntime'
      or coalesce(s.user_agent, '') ~* '^deno/'
    );

  get diagnostics deleted = row_count;
  return deleted;
end;
$$;

revoke all on function public.service_revoke_other_labeled_sessions(uuid, uuid, text) from public;
grant execute on function public.service_revoke_other_labeled_sessions(uuid, uuid, text) to service_role;

-- One-shot: remove unlabeled Edge mint orphans that already exist.
delete from auth.refresh_tokens rt
using auth.sessions s
where rt.session_id = s.id
  and (
    coalesce(s.user_agent, '') ~* 'supabaseedgeruntime'
    or coalesce(s.user_agent, '') ~* '^deno/'
  );

delete from auth.sessions s
where coalesce(s.user_agent, '') ~* 'supabaseedgeruntime'
   or coalesce(s.user_agent, '') ~* '^deno/';
