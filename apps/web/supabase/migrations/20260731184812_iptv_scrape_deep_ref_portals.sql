-- Link portals extracted from each deep ref; track already-in-pool vs new.

create table if not exists public.iptv_scrape_deep_ref_portals (
  id uuid primary key default gen_random_uuid(),
  deep_ref_id uuid not null
    references public.iptv_scrape_deep_refs (id) on delete cascade,
  url text not null,
  username text not null,
  was_existing boolean not null default false,
  portal_id uuid references public.iptv_portals (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (deep_ref_id, url, username)
);

create index if not exists iptv_scrape_deep_ref_portals_ref_idx
  on public.iptv_scrape_deep_ref_portals (deep_ref_id);

create index if not exists iptv_scrape_deep_ref_portals_portal_idx
  on public.iptv_scrape_deep_ref_portals (portal_id)
  where portal_id is not null;

alter table public.iptv_scrape_deep_ref_portals enable row level security;

drop policy if exists iptv_scrape_deep_ref_portals_admin_all
  on public.iptv_scrape_deep_ref_portals;

create policy iptv_scrape_deep_ref_portals_admin_all
  on public.iptv_scrape_deep_ref_portals for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_scrape_deep_ref_portals
  to authenticated, service_role;

-- Lookup before upsert (url+user case-insensitive).
create or replace function public.find_iptv_portal_id(
  p_url text,
  p_username text
)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.iptv_portals
  where lower(trim(url)) = lower(trim(p_url))
    and lower(trim(username)) = lower(trim(p_username))
  limit 1;
$$;

grant execute on function public.find_iptv_portal_id(text, text)
  to authenticated, service_role;
