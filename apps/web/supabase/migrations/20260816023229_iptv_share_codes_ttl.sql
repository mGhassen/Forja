-- Share codes expire after 7 days: hide on read. Delete is Inngest
-- `iptv-share-codes-purge` (daily), not pg_cron.

create index iptv_share_codes_created_at_idx
  on public.iptv_share_codes (created_at);

drop policy iptv_share_codes_select_any on public.iptv_share_codes;

create policy iptv_share_codes_select_fresh
  on public.iptv_share_codes
  for select
  to anon, authenticated
  using (created_at >= now() - interval '7 days');
