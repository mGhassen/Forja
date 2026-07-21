-- Megaplay CDN rotated nekostream → kotocdn (same megaplay.buzz Referer).
-- Append kotocdn to CDN Referer rule + Megaplay/AniKoto PNG-strip host lists.
-- In-scope only. Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    jsonb_set(
      jsonb_set(
        config,
        '{cdnRefererRules}',
        '[
          {
            "hostContains": ["mewstream", "nekostream", "kotocdn", "lostproject", "megaplay"],
            "referer": "https://megaplay.buzz/",
            "origin": "https://megaplay.buzz",
            "acceptRefererContains": ["megaplay"]
          },
          {
            "hostContains": ["watching.onl", "vidwish"],
            "referer": "https://vidwish.live/",
            "origin": "https://vidwish.live",
            "acceptRefererContains": ["vidwish"]
          },
          {
            "hostContains": ["fast4speed"],
            "referer": "https://allmanga.to/",
            "origin": "https://allmanga.to",
            "acceptRefererContains": ["allmanga"]
          }
        ]'::jsonb,
        true
      ),
      '{anime,playbackProfiles,megaplay,pngStripHostContains}',
      '["nekostream","kotocdn","mewstream","vivibebe","ibyteimg","byteimg.com","lostproject","watching.onl"]'::jsonb,
      true
    ),
    '{anime,playbackProfiles,anikoto,pngStripHostContains}',
    '["nekostream","kotocdn","mewstream","vivibebe","ibyteimg","byteimg.com","lostproject","vidtube"]'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
