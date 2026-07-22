# RFC-044: Provider-identity playback (end CDN host chase)

**Status:** open  
**Depends on:** [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md), [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)  
**Area:** playback / anime sources — Referer stamp, PNG strip, stream identity

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** components · **21 / 21** unit · **0 / 3** manual |
| **Current slice** | Open mind-tree middleware — branch on content + open outcome |

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
| 10 | R44-C10 | `playbackPolicyFor` derives embed origin from templates/WebStreamr/API for all host providers | ✅ |
| 11 | R44-C11 | `StreamOpenMindTree` — fact/branch open middleware (not flat try-list) | ✅ |

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

## Acceptance (plain HLS vs PNG-proxy)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A13 | Unit: `pngStrip: auto` + plain segment keeps catalog `.m3u8` (host needles do not force proxy) | ✅ |
| 2 | R44-A14 | Unit: `pngStrip: auto` + PNG-wrapped segment → `/hls-proxy?strip=png` | ✅ |

---

## Acceptance (host providers — Videasy)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A15 | Unit: `providerId=videasy` forces `player.videasy.to` Referer (ban CDN self) | ✅ |
| 2 | R44-A16 | Videasy first mirror hit returns after ≤3s grace (no collect-all on hung Neon) | ✅ |

---

## Acceptance (generic template identity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A17 | Unit: any builtin template `providerId` (e.g. vidfast) forces embed-host Referer on unknown CDN | ✅ |
| 2 | R44-A18 | Unit: remote template overlay retargets identity Referer without code change | ✅ |
| 3 | R44-A19 | Host encode stamps `providerId` on Vidnest / VidSrc.sbs / Nuvio / 111477 sources | ✅ |

---

## Acceptance (open mind-tree)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R44-A20 | Unit: `pngShell` → `playPngStrip`; open fail → `playDirect` | ✅ |
| 2 | R44-A21 | Unit: plain HLS → `playDirect`; fail → `playPngStrip` | ✅ |
| 3 | R44-A22 | Unit: progressive / `never` → direct only | ✅ |
| 4 | R44-A23 | Desktop+mobile player walks mind-tree per source (not one-shot strip guess) | ✅ |
| 5 | R44-A24 | Panel keeps catalog row while play URL is `/hls-proxy` — no ghost proxy row / wipe on probe refresh (unit) | ✅ |

---

## Summary

CDN hostnames under MegaPlay rotate often. Gating Referer rewrite and PNG-strip on `hostContains` / `pngStripHostContains` forces endless allowlist updates and breaks when remote config overwrites builtins.

**Contract:** stamp and recover playback headers from **provider identity** (`sourceKey` / embed origin). Open path uses **`StreamOpenMindTree`**: classify URL + sniff segment facts → one action → on open/decode fail **re-branch** (PNG→strip, plain HLS→direct then strip). Not a flat try-list. Not per-CDN host cases. Provider domain moves stay in `anime.megaplay.host` (RFC-039).

**Generic host path (R44-C10):** for every template / WebStreamr / known-API provider, `playbackPolicyFor(id)` derives Referer from that provider’s **embed host** in runtime config. CDN rotations do not need a new code branch — only provider domain moves need Admin JSON / migration. Exceptions stay explicit (MegaPlay family, Videasy player origin, AllManga, KissKh mirrors, Miruro origins).

Legacy `cdnRefererRules` remain for opens with **no** `providerId` only.

### Related

- [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md)
- [issue 084](../issues/084-[open]-megaplay-nekostream-cdn-referer.md)
- [anime hub](../features/hubs/anime.md)
- [stream providers](../features/sources/stream-providers.md)
