-- Per-anime-sourceKey playback/probe profiles (RFC-039 follow-on).
-- probe: masterOnly | segmentPoisonSample | headOrRange | skip
-- All in-scope Miruro pipes use masterOnly (no Megaplay poison sampler).
-- Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    config,
    '{anime,playbackProfiles}',
    '{
      "megaplay": {
        "probe": "segmentPoisonSample",
        "pngStripHostContains": [
          "nekostream",
          "mewstream",
          "vivibebe",
          "ibyteimg",
          "byteimg.com",
          "lostproject",
          "watching.onl"
        ]
      },
      "anikoto": {
        "probe": "segmentPoisonSample",
        "pngStripHostContains": [
          "nekostream",
          "mewstream",
          "vivibebe",
          "ibyteimg",
          "byteimg.com",
          "lostproject",
          "vidtube"
        ]
      },
      "vidwish": {
        "probe": "segmentPoisonSample",
        "pngStripHostContains": ["watching.onl", "vidwish"]
      },
      "vidnest:hianime": {
        "probe": "masterOnly",
        "pngStripHostContains": []
      },
      "vidnest:animepahe": {
        "probe": "masterOnly",
        "pngStripHostContains": []
      },
      "allanime:Default": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      },
      "allanime:Yt-mp4": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      },
      "allanime:S-mp4": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      },
      "allanime:Luf-Mp4": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      },
      "miruro:bee": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:zoro": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:kiwi": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:ally": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:hop": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:bonk": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:moo": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:animedunya": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:arc": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:jet": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:bun": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:kuz": { "probe": "masterOnly", "pngStripHostContains": [] },
      "miruro:telli": { "probe": "masterOnly", "pngStripHostContains": [] },
      "watchhentai": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      },
      "hentaini": {
        "probe": "headOrRange",
        "pngStripHostContains": []
      }
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
