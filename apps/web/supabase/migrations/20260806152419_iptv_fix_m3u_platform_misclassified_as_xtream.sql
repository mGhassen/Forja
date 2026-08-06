-- Scrape wrongly set platform=m3u when get.php type/output contained "m3u"
-- (m3u_plus / m3u8). Those are export query params; host+user+pass is Xtream.
-- Real M3U product rows use username '__m3u__' (playlist URL, no login).

update public.iptv_scrape_deep_ref_portals
set platform = 'xtream'
where platform = 'm3u'
  and username is distinct from '__m3u__'
  and coalesce(password, '') <> '';

update public.iptv_portals
set platform = 'xtream'
where platform = 'm3u'
  and username is distinct from '__m3u__'
  and coalesce(password, '') <> '';
