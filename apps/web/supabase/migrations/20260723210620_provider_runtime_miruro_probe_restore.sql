-- Restore Miruro probe split after blanket segmentPoisonSample.
-- AnimePahe / AllManga / AnimeDao / other plain-HLS pipes: masterOnly
--   (segment sampling false-killed them — see 1.2.366).
-- HiAnime (zoro) + AniKoto bee: keep segmentPoisonSample (vivibebe / Megaplay-family).
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
      "miruro:zoro": {
        "probe": "segmentPoisonSample",
        "pngStrip": "never"
      },
      "miruro:kiwi": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:ally": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:bonk": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:hop": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:moo": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:animedunya": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:arc": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:jet": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:bun": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:kuz": {
        "probe": "masterOnly",
        "pngStrip": "never"
      },
      "miruro:telli": {
        "probe": "masterOnly",
        "pngStrip": "never"
      }
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
