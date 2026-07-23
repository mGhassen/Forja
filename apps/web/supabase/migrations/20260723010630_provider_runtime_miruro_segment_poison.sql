-- Miruro pipes: probe media segments for PNG/ad poison (vivibebe → ibyteimg).
-- masterOnly green-passed playlists whose segments are pure image ads.
-- Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    config,
    '{anime,playbackProfiles}',
    coalesce(config->'anime'->'playbackProfiles', '{}'::jsonb)
      || '{
      "miruro:bee": {
        "probe": "segmentPoisonSample",
        "pngStrip": "auto"
      },
      "miruro:zoro": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:kiwi": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:ally": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:hop": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:bonk": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:moo": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:animedunya": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:arc": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:jet": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:bun": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:kuz": { "probe": "segmentPoisonSample", "pngStrip": "never" },
      "miruro:telli": { "probe": "segmentPoisonSample", "pngStrip": "never" }
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
