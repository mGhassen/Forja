-- Web Profile soft-pull via postgres_changes (app ↔ web Features / Addons).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profile_settings'
  ) then
    alter publication supabase_realtime add table public.profile_settings;
  end if;
end $$;
