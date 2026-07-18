# 084 — Megaplay CDN `nekostream` Referer + AniList `/stream/ani/` embeds

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/utils.dart`, `apps/forja/lib/features/anime/catalog/anime_service.dart`, `crates/anime/src/extractors/vidnest.rs`, `crates/anime/src/resolve/direct_embed.rs`

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 3** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I84-A01 | Manual: anime ep via Megaplay — master + segments open (no `failed reachability` on nekostream) | ⬜ |
| 2 | I84-A02 | Probe with missing headers still forces megaplay Referer (unit covered; app smoke) | ⬜ |
| 3 | I84-A03 | Manual: Anikoto miss still plays Megaplay via `/stream/ani/` | ⬜ |

---

## Summary

Megaplay extract still works ([API](https://megaplay.buzz/api)). CDN host rotated to `*.nekostream.site`. Without `Referer: https://megaplay.buzz/` the master returns **403**. Forja only rewrote `mewstream.buzz` / `lostproject` / `*megaplay*` hosts, so dropped headers derived a self-Referer → probe/play fail. `enma.lol` (scrape Referer) is also rejected by nekostream — must not count as a valid Megaplay-family playback Referer.

Also: code assumed `/stream/ani/` always 404s and skipped Megaplay without Anikoto. That path is live again — emit it when no `episode_embed_id`, keep `/stream/s-2/` when Anikoto matches.

## Related

- [080](080-[open]-miruro-cf-pipe-webview-unlock.md) — Miruro CF pipe (separate)
- [anime hub](../features/hubs/anime.md)
