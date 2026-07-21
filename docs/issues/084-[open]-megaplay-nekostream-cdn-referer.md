# 084 — Megaplay CDN `nekostream` Referer + AniList `/stream/ani/` embeds

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/utils.dart`, `apps/forja/lib/features/anime/catalog/anime_service.dart`, `crates/anime/src/extractors/vidnest.rs`, `crates/anime/src/resolve/direct_embed.rs`

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** fix · **0 / 5** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I84-A01 | Manual: anime ep via Megaplay — master + segments open (no `failed reachability` on nekostream) | ⬜ |
| 2 | I84-A02 | Probe with missing headers still forces megaplay Referer (unit covered; app smoke) | ⬜ |
| 3 | I84-A03 | Manual: Anikoto miss still plays Megaplay via `/stream/ani/` | ⬜ |
| 4 | I84-A04 | Manual: Anikoto miss — race has no Vidwish `/stream/ani/` candidate; Megaplay still plays | ⬜ |
| 5 | I84-A05 | Manual: if native player exhausts Megaplay/nekostream, Web player embed opens and plays | ⬜ |

---

## Summary

Megaplay extract still works ([API](https://megaplay.buzz/api)). CDN host rotated to `*.nekostream.site`. Without `Referer: https://megaplay.buzz/` the master returns **403**. Forja only rewrote `mewstream.buzz` / `lostproject` / `*megaplay*` hosts, so dropped headers derived a self-Referer → probe/play fail. `enma.lol` (scrape Referer) is also rejected by nekostream — must not count as a valid Megaplay-family playback Referer.

Also: code assumed `/stream/ani/` always 404s and skipped Megaplay without Anikoto. That path is live again for **Megaplay** — emit it when no `episode_embed_id`, keep `/stream/s-2/` when Anikoto matches. **Vidwish** `/stream/ani/` stays a soft-404 / transport waste — only emit Vidwish when Anikoto provides an `s-2` id (I84-T08).

**Playback (I84-T09–T11):** Nekostream segments are PNG-wrapped MPEG-TS (browser player strips them). Forja unwraps via `/hls-proxy?strip=png` and must not treat that loopback URL as unplayable. If native still fails, open the site’s own WebView player (Megaplay `/stream/ani/…`, VidNest `/anime/…` / `/animepahe/…`) so their JS decrypt/unwrap runs.

## Related

- [080](080-[open]-miruro-cf-pipe-webview-unlock.md) — Miruro CF pipe (separate)
- [anime hub](../features/hubs/anime.md)
