-- Run on EXISTING DB if migration 20260719232752 is not applied via CLI.
-- Idempotent.

alter table public.iptv_ops_settings
  add column if not exists scrape_cron text not null default '0 6 * * *';

comment on column public.iptv_ops_settings.scrape_cron is
  'UTC 5-field cron (min hour dom month dow). Inngest tick is every minute.';
