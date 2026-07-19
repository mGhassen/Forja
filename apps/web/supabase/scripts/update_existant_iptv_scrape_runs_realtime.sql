-- Studio one-shot if migration not applied via CLI.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'iptv_scrape_runs'
  ) then
    alter publication supabase_realtime add table public.iptv_scrape_runs;
  end if;
end $$;
