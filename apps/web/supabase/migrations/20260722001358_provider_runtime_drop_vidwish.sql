-- Vidwish is Megaplay (vidwish.live → megaplay.buzz). Drop alias host +
-- playback profile; fold watching.onl / vidwish CDN needles into Megaplay.
-- Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    jsonb_set(
      jsonb_set(
        config #- '{anime,vidwish}' #- '{anime,playbackProfiles,vidwish}',
        '{cdnRefererRules}',
        '[
          {
            "hostContains": ["mewstream", "nekostream", "kotocdn", "lostproject", "megaplay", "watching.onl", "vidwish"],
            "referer": "https://megaplay.buzz/",
            "origin": "https://megaplay.buzz",
            "acceptRefererContains": ["megaplay"]
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
      '["nekostream","kotocdn","mewstream","vivibebe","ibyteimg","byteimg.com","lostproject","watching.onl","vidwish"]'::jsonb,
      true
    ),
    '{anime,playbackProfiles,megaplay,pngStrip}',
    '"auto"'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
