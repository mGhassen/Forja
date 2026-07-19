-- Editable IPTV scrape schedule (5-field cron, UTC).
-- Inngest ticks every minute; function runs only when expression matches.

alter table public.iptv_ops_settings
  add column if not exists scrape_cron text not null default '0 6 * * *';

comment on column public.iptv_ops_settings.scrape_cron is
  'UTC 5-field cron (min hour dom month dow). Inngest tick is every minute.';
