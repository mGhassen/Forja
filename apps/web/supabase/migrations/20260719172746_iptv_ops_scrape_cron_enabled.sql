-- Admin-toggleable daily IPTV catalog scrape (Inngest cron still registered;
-- function no-ops when scrape_cron_enabled is false).

create table public.iptv_ops_settings (
  id smallint primary key default 1 check (id = 1),
  scrape_cron_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.iptv_ops_settings (id, scrape_cron_enabled)
values (1, true);

create trigger iptv_ops_settings_set_updated_at
  before update on public.iptv_ops_settings
  for each row
  execute function public.set_updated_at();

alter table public.iptv_ops_settings enable row level security;

create policy iptv_ops_settings_admin_all
  on public.iptv_ops_settings for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, update on table public.iptv_ops_settings
  to authenticated, service_role;
