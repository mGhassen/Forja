# RFC-039: Remote provider runtime config

**Status:** open  
**Depends on:** [RFC-004](004-[partial]-provider-registry.md), [RFC-006](006-[partial]-supabase-sync.md)  
**Area:** playback / sources — hosts, path templates, CDN Referer rules (not extract logic)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** components · **5 / 5** acceptance · **1** deferred (web admin) |
| **Current slice** | Anime Megaplay/Vidwish paths + Miruro origins + CDN Referer rules via Supabase JSON |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R39-C01 | Supabase `provider_runtime_config` (public read, single-row JSON) | ✅ |
| 2 | R39-C02 | Host `ProviderRuntimeConfig`: fetch, disk cache, merge over builtins | ✅ |
| 3 | R39-C03 | Wire anime Megaplay/Vidwish embeds + Miruro origins + CDN Referer rewrite | ✅ |
| 4 | R39-C04 | Web admin editor for the JSON row | ⏭️ |

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

## Summary

Ops can retarget **hosts, path templates, mirrors, CDN Referer rules** without shipping an app build. **Extract logic** (decrypt, CF pipe, sniff) stays in Rust/Dart plugins.

### Contract (schema 1)

```json
{
  "schema": 1,
  "anime": {
    "megaplay": {
      "host": "megaplay.buzz",
      "pathCatalog": "/stream/s-2/{embedId}/{lang}",
      "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
      "scrapeReferer": "https://www.enma.lol/"
    },
    "vidwish": { "...": "same shape" },
    "miruroOrigins": ["https://www.miruro.tv", "..."]
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

### Non-goals (this slice)

- Shipping extract JS from the DB
- Movie/TV template plugin defs (later overlay on RFC-004)
- Signed / E2E encrypted payloads

## Goals

- Fix CDN host / embed path churn in minutes via Supabase
- Never brick playback when remote is down

## Related

- [RFC-004](004-[partial]-provider-registry.md)
- [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)
- [anime hub](../features/hubs/anime.md)
