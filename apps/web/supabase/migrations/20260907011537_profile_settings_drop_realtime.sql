-- Drop profile_settings from Realtime (soft-pull on open/resume/focus only).
do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profile_settings'
  ) then
    alter publication supabase_realtime drop table public.profile_settings;
  end if;
end $$;
