# 084 — Megaplay CDN `nekostream` Referer + AniList `/stream/ani/` embeds

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/utils.dart`, `apps/forja/lib/features/anime/catalog/anime_service.dart`, `crates/anime/src/extractors/vidnest.rs`, `crates/anime/src/resolve/direct_embed.rs`

## Status at a glance

| | |
|--|--|
| **Progress** | **19 / 19** fix · **0 / 10** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I84-T01 | Dart `resolvePlaybackHttpHeaders`: treat `nekostream` as Megaplay CDN; rewrite self/enma → `megaplay.buzz` | ✅ |
| 2 | I84-T02 | Rust `vidnest::playback_headers`: same `nekostream` / `lostproject` hosts | ✅ |
| 3 | I84-T03 | Unit tests (Dart headers + Rust nekostream) | ✅ |
| 4 | I84-T04 | Emit Megaplay/Vidwish via `/stream/ani/{anilist}/{ep}/{lang}` when no Anikoto embed id | ✅ |
| 5 | I84-T05 | `savedSourceNeedsAnikoto('megaplay')` → false (AniList path) | ✅ |
| 6 | I84-T06 | Rust `direct_embed`: nekostream/mewstream file → megaplay playback Referer | ✅ |
| 7 | I84-T07 | Anime `probeStreamUrl` + reload/bridge hits apply `resolvePlaybackHttpHeaders` before CDN check / open | ✅ |
| 8 | I84-T08 | Skip Vidwish embeds without Anikoto `s-2` id (`/stream/ani/` dead on vidwish.live); `direct_embed` transport miss → `Ok(None)` | ✅ |
| 9 | I84-T09 | PNG-wrapped MPEG-TS: probe accepts wrap; `/hls-proxy?strip=png`; loopback URLs playable | ✅ |
| 10 | I84-T10 | Anime open uses stripped proxy URL as `streamUrl` + `streamsPrevalidated` | ✅ |
| 11 | I84-T11 | Browser embed fallback (Megaplay/VidNest WebView) when native exhausts or race fails | ✅ |
| 12 | I84-T12 | Do not PNG-strip AnimePahe/`owocdn` (normal HLS); stop proxy poison false-reject | ✅ |
| 13 | I84-T13 | Miruro Bee (AniKoto): unwrap Megaplay/Vidwish iframe embeds via `direct_embed` | ✅ |
| 14 | I84-T14 | Anikoto.cz watch-page Web fallback (`loadInMainFrame` — site blocks iframes) + slug | ✅ |
| 15 | I84-T15 | `direct_embed`: call `getSources` from `/stream/s-2/{id}` path (skip 410 HTML scrape) | ✅ |
| 16 | I84-T16 | Always resolve Anikoto for Megaplay/VidNest; Web fallback prefers anikoto.cz; skip `/stream/ani/` WebView | ✅ |
| 17 | I84-T17 | VidNest uses Anikoto `ani_id` when Forja AniList id is a duplicate | ✅ |
| 18 | I84-T18 | Native AniKoto site Ajax (Vidstream/VidPlay/…) → MegaPlay/VidTube getSources race | ✅ |
| 19 | I84-T19 | VidNest web-player first on fallback; manual VidNest CDN/API miss opens vidnest.fun immediately | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I84-A01 | Manual: anime ep via Megaplay — master + segments open (no `failed reachability` on nekostream) | ⬜ |
| 2 | I84-A02 | Probe with missing headers still forces megaplay Referer (unit covered; app smoke) | ⬜ |
| 3 | I84-A03 | Manual: Anikoto miss still plays Megaplay via `/stream/ani/` | ⬜ |
| 4 | I84-A04 | Manual: Anikoto miss — race has no Vidwish `/stream/ani/` candidate; Megaplay still plays | ⬜ |
| 5 | I84-A05 | Manual: if native player exhausts Megaplay/nekostream, Web player embed opens and plays | ⬜ |
| 6 | I84-A06 | Manual: AniKoto (bee) — native unwrap or anikoto.cz watch Web player plays (same as browser) | ⬜ |
| 7 | I84-A07 | Manual: Dan Da Dan ep1 — Megaplay native via s-2 getSources OR anikoto.cz Web (not Megaplay 410 page) | ⬜ |
| 8 | I84-A08 | Manual: Dan Da Dan — VidNest HiAnime resolves with Anikoto-mapped AniList id | ⬜ |
| 9 | I84-A09 | Manual: AniKoto provider race — native HLS from site Vidstream/VidPlay (no WebView required) | ⬜ |
| 10 | I84-A10 | Manual: VidNest HiAnime/AnimePahe — CDN or API miss opens vidnest.fun web player and plays | ⬜ |

---

## Summary

Megaplay extract still works ([API](https://megaplay.buzz/api)). CDN host rotated to `*.nekostream.site`. Without `Referer: https://megaplay.buzz/` the master returns **403**. Forja only rewrote `mewstream.buzz` / `lostproject` / `*megaplay*` hosts, so dropped headers derived a self-Referer → probe/play fail. `enma.lol` (scrape Referer) is also rejected by nekostream — must not count as a valid Megaplay-family playback Referer.

Also: code assumed `/stream/ani/` always 404s and skipped Megaplay without Anikoto. That path is live again for **Megaplay** — emit it when no `episode_embed_id`, keep `/stream/s-2/` when Anikoto matches. **Vidwish** `/stream/ani/` stays a soft-404 / transport waste — only emit Vidwish when Anikoto provides an `s-2` id (I84-T08).

**Playback (I84-T09–T19):** Nekostream segments are PNG-wrapped MPEG-TS (browser player strips them). Forja unwraps via `/hls-proxy?strip=png` and must not treat that loopback URL as unplayable. Miruro Bee (UI **AniKoto**) often returns Megaplay/Vidwish iframe URLs — unwrap those with `direct_embed` instead of dropping. Megaplay embed **HTML** may 410 while `getSources?id={s-2 catalog id}` still returns HLS — extract from the path id, always resolve Anikoto for Megaplay. Web fallback order prefers **vidnest.fun** public pages first (site JS still plays when API/CDN native dies), then Megaplay `/stream/s-2/…`, then **anikoto.cz** watch (I84-T19). Native **AniKoto** provider scrapes anikototv.to Ajax (Vidstream / VidPlay / …) → MegaPlay / VidTube getSources (I84-T18). VidNest should use Anikoto’s mapped `ani_id` when Forja’s AniList id is a duplicate entry.

## Related

- [080](080-[open]-miruro-cf-pipe-webview-unlock.md) — Miruro CF pipe (separate)
- [anime hub](../features/hubs/anime.md)
