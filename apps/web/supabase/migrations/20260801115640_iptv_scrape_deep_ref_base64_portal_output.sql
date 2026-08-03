-- Deep refs = one row per find: base64 + paste_url.
-- Portal hits: platform (xtream|m3u|stalker) + get.php type/output query params.

-- Regenerable scrape artifacts — wipe old shape (CASCADE clears child portals).
truncate table public.iptv_scrape_deep_refs cascade;

alter table public.iptv_scrape_deep_refs
  drop constraint if exists iptv_scrape_deep_refs_ref_type_check;

alter table public.iptv_scrape_deep_refs
  drop constraint if exists iptv_scrape_deep_refs_post_id_ref_type_payload_hash_ref_host_key;

alter table public.iptv_scrape_deep_refs
  add column if not exists base64 text not null default '',
  add column if not exists paste_url text not null default '',
  add column if not exists paste_body text;

alter table public.iptv_scrape_deep_refs
  drop column if exists ref_type;

alter table public.iptv_scrape_deep_refs
  drop column if exists raw_ref;

alter table public.iptv_scrape_deep_refs
  drop column if exists payload_text;

alter table public.iptv_scrape_deep_refs
  drop constraint if exists iptv_scrape_deep_refs_post_hash_key;

alter table public.iptv_scrape_deep_refs
  add constraint iptv_scrape_deep_refs_post_hash_key unique (post_id, payload_hash);

alter table public.iptv_scrape_deep_ref_portals
  add column if not exists platform text not null default 'xtream',
  add column if not exists type text not null default '',
  add column if not exists output text not null default '',
  add column if not exists password text not null default '';

alter table public.iptv_scrape_deep_ref_portals
  drop constraint if exists iptv_scrape_deep_ref_portals_platform_check;

alter table public.iptv_scrape_deep_ref_portals
  add constraint iptv_scrape_deep_ref_portals_platform_check
  check (platform in ('xtream', 'm3u', 'stalker'));

comment on column public.iptv_scrape_deep_ref_portals.platform is
  'xtream | m3u | stalker';
comment on column public.iptv_scrape_deep_ref_portals.type is
  'get.php ?type= value (e.g. m3u_plus); empty for plain xtream';
comment on column public.iptv_scrape_deep_ref_portals.output is
  'get.php ?output= value (e.g. m3u8); empty for plain xtream';
