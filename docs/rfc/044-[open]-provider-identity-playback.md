# RFC-044: Provider-identity playback (end CDN host chase)

**Status:** open  
**Depends on:** [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md), [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)  
**Area:** playback / anime sources — Referer stamp, PNG strip, stream identity

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** components · **9 / 12** acceptance (unit) · **0 / 3** manual |
| **Current slice** | AllManga + KissKh identity shipped — Megaplay manual smoke still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-C01 | `StreamSource.providerId` + `catalogUrl`; anime cache persists identity | ✅ |
| 2 | R44-C02 | Rust extract stamps Referer from embed/runtime host (no CDN host `if` lists) | ✅ |
| 3 | R44-C03 | Dart `resolvePlaybackHttpHeaders(providerId:)` — policy by sourceKey; ban self-Referer | ✅ |
| 4 | R44-C04 | `AnimePlaybackProfile.pngStrip` = `auto` \| `force` \| `never` (content sample for auto) | ✅ |
| 5 | R44-C05 | Runtime config + Supabase migration for `pngStrip`; Rust overlay read for hosts | ✅ |
| 6 | R44-C06 | Anime opens with `providerId` ignore CDN host chase; legacy rules only when id unknown | ✅ |
| 7 | R44-C07 | Drop Vidwish as separate provider identity (alias → Megaplay) | ✅ |
| 8 | R44-C08 | `playbackPolicyFor(allanime:*)` → AllManga Referer; ban CDN self-Referer | ✅ |
| 9 | R44-C09 | KissKh `StreamSource.providerId` + `playbackPolicyFor(kisskh*)` before CDN sniff | ✅ |

---

## Acceptance (identity slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A01 | Extract: arbitrary CDN host + megaplay embed → `megaplay.buzz` Referer (unit) | ✅ |
| 2 | R44-A02 | Open: missing headers + `providerId=megaplay` forces megaplay Referer without host match (unit) | ✅ |
| 3 | R44-A03 | Open: never derives self-Referer from CDN URL when `providerId` set (unit) | ✅ |
| 4 | R44-A04 | Cache round-trip keeps `providerId` + headers + catalogUrl (unit) | ✅ |
| 5 | R44-A05 | `pngStrip: auto` triggers strip gate on HLS without CDN host needle (unit) | ✅ |
| 6 | R44-A06 | Manual: Megaplay ep plays; log shows `hls-proxy?strip=png` | ⬜ |
| 7 | R44-A07 | Manual: builtins with empty CDN host lists still play Megaplay | ⬜ |
| 8 | R44-A08 | Movie KissKh / Vidsrc `/pl/` / MovieBox hakunaymatata branches unchanged (unit) | ✅ |
| 9 | R44-A09 | Unit: legacy `vidwish` embed origin / CDN needles stamp megaplay Referer | ✅ |

---

## Acceptance (AllManga + KissKh slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A10 | Unit: `providerId=allanime:*` forces allmanga Referer on unknown CDN | ✅ |
| 2 | R44-A11 | Unit: `providerId=kisskh*` rewrites streamingcdn self-Referer to kisskh mirror | ✅ |
| 3 | R44-A12 | Manual: AllAnime / KissKh play after CDN host rename without config chase | ⬜ |

---

## Summary

CDN hostnames under MegaPlay rotate often. Gating Referer rewrite and PNG-strip on `hostContains` / `pngStripHostContains` forces endless allowlist updates and breaks when remote config overwrites builtins.

**Contract:** stamp and recover playback headers from **provider identity** (`sourceKey` / embed origin). Decide PNG unwrap from **content** (`pngStrip: auto`) or explicit force/never. Provider domain moves stay in `anime.megaplay.host` (RFC-039).

Legacy `cdnRefererRules` remain for opens with **no** `providerId` only.

### Related

- [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md)
- [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)
- [anime hub](../features/hubs/anime.md)
