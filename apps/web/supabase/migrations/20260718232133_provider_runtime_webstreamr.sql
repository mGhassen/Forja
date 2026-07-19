-- Add WebStreamr source bases (+ RGShows API) to provider_runtime_config.
-- In-scope only (Home/Search/Anime/Asian Drama playback). No Arabic/Amri.

update public.provider_runtime_config
set
  config = jsonb_set(
    config || '{
      "webstreamr": {
        "vidsrc": "https://vsembed.su",
        "vixsrc": "https://vixsrc.to",
        "rgshows": "https://rgshows.ru",
        "meinecloud": "https://meinecloud.click",
        "verhdlink": "https://verhdlink.cam",
        "megakino": "https://megakino1.to",
        "homecine": "https://www3.homecine.to",
        "mostraguarda": "https://mostraguarda.stream",
        "eurostreaming": "https://eurostreaming.luxe",
        "cinehdplus": "https://cinehdplus.gratis",
        "streamkiste": "https://streamkiste.taxi",
        "frenchcloud": "https://frenchcloud.cam",
        "cuevana": "https://ww1.cuevana3.is",
        "hdhub4u": "https://new5.hdhub4u.fo",
        "einschalten": "https://einschalten.in",
        "movix": "https://api.movix.site",
        "frembed": "https://frembed.work",
        "kokoshka": "https://kokoshka.digital",
        "4khdhub": "https://4khdhub.dad",
        "vegamovies": "https://vegamovies.market",
        "kinoger": "https://kinoger.com"
      }
    }'::jsonb,
    '{apis,rgshowsApi}',
    '"https://api.rgshows.ru"'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
