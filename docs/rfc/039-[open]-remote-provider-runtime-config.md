# RFC-039: Remote provider runtime config

**Status:** open  
**Depends on:** [RFC-004](004-[partial]-provider-registry.md), [RFC-006](006-[partial]-supabase-sync.md)  
**Area:** playback / sources — hosts, path templates, CDN Referer rules (not extract logic)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 5** components · **8 / 8** acceptance (registry slice) · **1** deferred (web admin) |
| **Current slice** | Full movie/TV templates + anime/API bases + CDN rules via Supabase → Dart + Rust overlay |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R39-C01 | Supabase `provider_runtime_config` (public read, single-row JSON) | ✅ |
| 2 | R39-C02 | Host `ProviderRuntimeConfig`: fetch, disk cache, merge over builtins | ✅ |
| 3 | R39-C03 | Wire anime Megaplay/Vidwish embeds + Miruro origins + CDN Referer rewrite | ✅ |
| 4 | R39-C04 | Web admin editor for the JSON row | ⏭️ |
| 5 | R39-C05 | Full registry: `templates.*` + `apis.*` + KissKh mirrors; push overlay to Rust FFI | ✅ |

---

## Acceptance (v1 slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R39-A01 | Offline / fetch fail → built-in defaults still resolve Megaplay | ✅ |
| 2 | R39-A02 | Remote CDN `hostContains` + referer applied by `resolvePlaybackHttpHeaders` | ✅ |
| 3 | R39-A03 | Remote Megaplay `pathAnilist` / host used when Anikoto miss | ✅ |
| 4 | R39-A04 | Remote Miruro origin list used by `MiruroPipeSession` | ✅ |
| 5 | R39-A05 | Unit tests: parse/merge + embed URL from config | ✅ |

---

## Acceptance (full registry slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R39-A06 | Remote `templates.{provider}.movie/tv` used by `stream::build_*_url` | ✅ |
| 2 | R39-A07 | Remote `apis.*` used by VidNest/Anikoto/AllAnime/VidSrc/Videasy/111477 | ✅ |
| 3 | R39-A08 | Dart pushes merged JSON to Rust after boot / refresh | ✅ |

---

## Summary

Ops can retarget **hosts, path templates, mirrors, CDN Referer rules** without shipping an app build. **Extract logic** (decrypt, CF pipe, sniff) stays in Rust/Dart plugins.

### Contract (schema 1)

```json
{
  "schema": 1,
  "templates": {
    "vidlink": {
      "movie": "https://vidlink.pro/movie/{tmdb}",
      "tv": "https://vidlink.pro/tv/{tmdb}/{season}/{episode}"
    }
  },
  "apis": {
    "vidnestApi": "https://new.vidnest.fun",
    "vidsrcEmbed": "https://vsembed.su"
  },
  "anime": {
    "megaplay": {
      "host": "megaplay.buzz",
      "pathCatalog": "/stream/s-2/{embedId}/{lang}",
      "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
      "scrapeReferer": "https://www.enma.lol/"
    },
    "vidwish": { "...": "same shape" },
    "miruroOrigins": ["https://www.miruro.tv", "..."],
    "kisskhMirrors": ["https://kisskh.co", "..."]
  },
  "cdnRefererRules": [
    {
      "hostContains": ["nekostream", "mewstream"],
      "referer": "https://megaplay.buzz/",
      "origin": "https://megaplay.buzz"
    }
  ]
}
```

Unknown schema → ignore remote, keep builtins. Partial remote objects deep-merge over builtins.

### Non-goals

- Shipping extract JS from the DB
- Signed / E2E encrypted payloads

## Goals

- Fix CDN host / embed path churn in minutes via Supabase
- Never brick playback when remote is down

## Related

- [RFC-004](004-[partial]-provider-registry.md)
- [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)
- [anime hub](../features/hubs/anime.md)
- [stream providers](../features/sources/stream-providers.md)
