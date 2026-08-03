# 143 — Android TV Live Matches Stremio stuck on Reconnecting

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · Stremio · ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I143-T01 | Exo `mimeForAdaptiveUrl`: treat `recaps.dev` / `/leaf/` as HLS (not Progressive) | ✅ |
| 2 | I143-T02 | Live Matches Stremio open: pass `proxyHeaders` + streamed.pk Referer/UA for Highfly leaf CDNs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I143-A01 | Android TV: Live Matches → Stremio → Highfly live event plays video (no forever Reconnecting…) | ⬜ |

---

## Summary

On **Android TV**, Live Matches **Stremio** (Highfly) opens sport HLS in `IptvPtPlayerScreen` (Exo default). The player stuck on **Reconnecting…** while the same stream played on desktop MediaKit.

**Root cause (two layers):**

1. Highfly Streamed-backed URLs hit `cdn.recaps.dev/leaf/…` **without** a `.m3u8` path. Exo’s `DefaultMediaSourceFactory` chose **Progressive** → `UnrecognizedInputFormatException` → IPTV watchdog reconnect loop (same class as [117](117-[open]-android-live-embedindia-handoff-stuck.md) for `/hls-proxy` / `strmd.st`).
2. Stremio live open ignored `behaviorHints.proxyHeaders` and sent only the IPTV VLC UA — leaf CDNs expect a browser UA + streamed.pk Referer (same as Streamed handoff).

**Root fix:** force `APPLICATION_M3U8` for `recaps.dev` / `/leaf/`; forward addon proxy headers and fill streamed catalog Referer/UA when missing.

## Related

- [RFC-050](../rfc/050-[open]-stremio-addon-feature-targets.md)
- [117](117-[open]-android-live-embedindia-handoff-stuck.md) — Exo HLS mime + Streamed CDN
- [124](124-[open]-android-tv-iptv-reconnect-banner-stuck.md) — reconnect banner after recover
- [Live Matches](../features/live/live-matches.md)
