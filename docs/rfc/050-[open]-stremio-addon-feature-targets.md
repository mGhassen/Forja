# RFC-050: Stremio addon feature targets + Live Matches sports

**Status:** open  
**Depends on:** —  
**Area:** settings / Live Matches / Stremio

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **5 / 7** acceptance |
| **Current slice** | Per-addon Sources vs Live Matches targets + sport HLS; ATV Highfly reconnect fix landed (smoke R50-A07) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R50-C01 | Persist `features` (`vod` / `live`) on installed Stremio addons + Settings chips | ✅ |
| 2 | R50-C02 | Live Matches `Stremio` server — sport catalog + direct HLS via IPTV player | ✅ |
| 3 | R50-C03 | Feature docs + changelog + cloud lean sync of `features` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R50-A01 | Install sports addon → defaults to Live Matches; movie/series → Sources | ✅ |
| 2 | R50-A02 | Settings chips toggle Sources / Live Matches per addon (at least one on) | ✅ |
| 3 | R50-A03 | Home / Search / Details only use addons targeting Sources (`vod`) | ✅ |
| 4 | R50-A04 | Live Matches Servers lists Stremio; loads live-targeted sport catalogs | ✅ |
| 5 | R50-A05 | Playable `.m3u8` streams open native IPTV player; premium bait URLs skipped | ✅ |
| 6 | R50-A06 | Manual smoke: install Highfly → Live Matches → play one live HLS | ⬜ |
| 7 | R50-A07 | Android TV Exo: Highfly `recaps.dev` /leaf HLS plays (no forever Reconnecting…) — [issue 143](../issues/143-[open]-android-tv-stremio-live-reconnect.md) | ⬜ |

---

## Summary

Stremio addons are no longer assumed to be VOD-only. Each installed addon stores a `features` list (`vod`, `live`). Manifest types drive the default (sport → live; movie/series/… → vod). Settings → Sources shows chips so the user can assign an addon to **Sources**, **Live Matches**, or both.

Live Matches gains a **Stremio** server that aggregates catalogs from live-targeted addons (prefer `sports_live` / `sports_today`), resolves `/stream/sport/{id}.json`, and plays direct HTTP(S) HLS in `IptvPtPlayerScreen`. Not merged into **All** (overlap with Streamed).

### Goals

- Install [Highfly Sports Streams](https://sportsfree-us2.highfly.dev/configure) (or any sport Stremio addon) for Live Matches
- Keep torrentio / Cinemeta on Home · Search · Details only
- Reuse existing Stremio HTTP stack + Live Matches server picker UX

### Non-goals (this slice)

- Configurable addon URL builder UI (use Stremio configure page, paste URL)
- Merging Stremio sports into All / PPV–Streamed dedupe
- Embed/WebView playback for Stremio sports (HLS-only)
