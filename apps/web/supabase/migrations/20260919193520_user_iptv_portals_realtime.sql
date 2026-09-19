-- Web account IPTV portal list — postgres_changes (app ↔ web).
-- REPLICA IDENTITY FULL so DELETE events keep profile_id for filters.
alter table public.user_iptv_portals replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_iptv_portals'
  ) then
    alter publication supabase_realtime add table public.user_iptv_portals;
  end if;
end $$;
