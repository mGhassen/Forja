-- RFC-044: provider-identity PNG strip mode (auto|force|never).
-- Replaces host-list gating for Megaplay-family unwrap. Legacy
-- pngStripHostContains kept for older app builds. Do not push without approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    config,
    '{anime,playbackProfiles}',
    coalesce(config->'anime'->'playbackProfiles', '{}'::jsonb)
      || '{
      "megaplay": {
        "probe": "segmentPoisonSample",
        "pngStrip": "auto"
      },
      "anikoto": {
        "probe": "segmentPoisonSample",
        "pngStrip": "auto"
      },
      "vidwish": {
        "probe": "segmentPoisonSample",
        "pngStrip": "auto"
      },
      "miruro:bee": {
        "probe": "segmentPoisonSample",
        "pngStrip": "auto"
      },
      "vidnest:hianime": {
        "probe": "masterOnly",
        "pngStrip": "auto"
      },
      "vidnest:animepahe": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:kiwi": {
        "probe": "masterOnly",
        "pngStrip": "never"
      }
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
