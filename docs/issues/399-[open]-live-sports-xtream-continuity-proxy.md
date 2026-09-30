# 399 — Live Sports Xtream continuity proxy was removed with IPTV

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · MediaKit · Exo

**Related:** [321](fixed/321-[fixed]-live-sports-stremio-rfc113-cushion-stutter.md) · [272](fixed/272-[fixed]-iptv-hls-m3u-continuity-proxy-death-spiral.md) · [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I399-T01 | Live Sports logs use `[Live Sports …]`, not `[IPTV …]` | ✅ |
| 2 | I399-T02 | Xtream MPEG-TS on the Live Sports player opens through `LiveSportsContinuityProxy` (MediaKit + Exo). IPTV player stays CDN-direct | ✅ |
| 3 | I399-T03 | HLS, Stremio, Stalker, and engine rows stay direct | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I399-A01 | macOS Live Sports Xtream `.ts`: log `continuity proxy`, playback survives a portal socket close. A Stremio `.m3u8` still logs `direct open` | ⬜ |

---

## Summary

RFC-113 deleted the continuity proxy for IPTV. The Live Sports player was copied from that path and kept the IPTV log tags, so Xtream channels on Live Sports also opened the CDN directly.

HLS playlists are not proxied. A short `.m3u8` through the TS relay EOF-loops.

## Symptom fix

Log prefixes only renamed the labels. That does not restore playback.

## Root fix

`live_sports_continuity_proxy.dart` is back on the Live Sports open path for `iptvXtream` when the URL is not HLS. IPTV `pt_player_*` is unchanged.

## Workaround

No.
