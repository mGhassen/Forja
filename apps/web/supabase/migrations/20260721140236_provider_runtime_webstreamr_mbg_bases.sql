-- Sync WebStreamr source bases to WebStreamrMBG (issue 093).
-- Replaces stale hosts from 20260718232133 (vsembed.su / megakino1.to / …).
-- VSEmbed standalone stays apis.vidsrcEmbed = vsembed.su (unchanged).
-- In-scope only. Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    config,
    '{webstreamr}',
    '{
      "vidsrc": "https://vidsrcme.ru",
      "vixsrc": "https://vixsrc.to",
      "vidzee": "https://player.vidzee.wtf",
      "moviebox": "https://moviebox.ph",
      "rgshows": "https://rgshows.ru",
      "meinecloud": "https://meinecloud.click",
      "verhdlink": "https://verhdlink.cam",
      "megakino": "https://megakino2.biz",
      "homecine": "https://www3.homecine.to",
      "mostraguarda": "https://mostraguarda.stream",
      "eurostreaming": "https://eurostreaming.luxe",
      "cinehdplus": "https://cinehdplus.zone",
      "streamkiste": "https://streamkiste.taxi",
      "frenchcloud": "https://frenchcloud.cam",
      "cuevana": "https://ww1.cuevana3.is",
      "hdhub4u": "https://new1.hdhub4u.limo",
      "einschalten": "https://einschalten.in",
      "movix": "https://api.movix.cash",
      "frembed": "https://frembed.cyou",
      "kokoshka": "https://kokoshka.digital",
      "4khdhub": "https://4khdhub.link",
      "filmpalast": "https://filmpalast.to",
      "vegamovies": "https://vegamovies.market",
      "kinoger": "https://kinoger.com"
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
