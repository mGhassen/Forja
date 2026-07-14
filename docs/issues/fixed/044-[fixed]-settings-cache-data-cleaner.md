# 044 — Settings: Cache & data cleaner

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Settings, playback cache, provider scores, watch history

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **4 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I44-T01 | Settings **Cache & data** section with confirm dialogs | ✅ |
| 2 | I44-T02 | Stream cache clear (webstreaming + anime extracts + torrent + 111477) | ✅ |
| 3 | I44-T03 | Provider reliability scores clear (Rust store + Dart) | ✅ |
| 4 | I44-T04 | Continue watching + watched-episode local clears (all hubs) | ✅ |
| 5 | I44-T05 | Images / WebView cache clear + feature docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I44-A01 | Stream cache clear does not wipe watch history or settings | ✅ |
| 2 | I44-A02 | Clearing scores zeros Settings Σ and player reliability memory | ✅ |
| 3 | I44-A03 | Clearing continue watching empties Home + hub CW rows | ✅ |
| 4 | I44-A04 | Destructive actions require confirm; toasts report success/failure | ✅ |

---

## Summary

**Settings → Cache & data** replaces the single Playback **Reset playback cache** tile with five confirmed actions:

| Action | Clears |
|--------|--------|
| Stream cache | Webstreaming + anime extracts/pins + torrent temp + 111477 |
| Images & WebView | `cached_network_image` disk + Flutter image cache + WebView extract dirs |
| Provider scores | Rust `provider_score_reliability_v5` via FFI `clearAll` |
| Continue watching | Movies/TV + anime + KissKH + anime Arabic (+ legacy anime key) |
| Watched episode marks | Local `episodes_watched` only (Trakt/Simkl cloud unchanged) |

Does **not** clear tokens, My List, provider drag order, or account keys.

## Related

- [cache-data](../features/settings/cache-data.md)
- [playback-settings](../features/settings/playback-settings.md)
- [watch-history](../features/movies-tv/watch-history.md)
- [Issue 042](fixed/042-[fixed]-provider-reliability-not-global.md)
