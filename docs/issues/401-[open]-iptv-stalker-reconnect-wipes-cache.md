# 401 — IPTV Stalker live restarts every ~20s and wipes the cache

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV player · MediaKit · Exo · Stalker

**Related:** [399](399-[open]-live-sports-xtream-continuity-proxy.md) · [388](388-[open]-iptv-reconnect-replays-archive.md) · [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I401-T01 | Continuity relay takes an upstream refresher and calls it before every reconnect after the first | ✅ |
| 2 | I401-T02 | IPTV player opens Stalker progressive live through the relay on MediaKit and Exo. The refresher mints a fresh `create_link`. MediaKit sets `reconnect=0` on the loopback | ✅ |
| 3 | I401-T03 | Relay closes the loopback when the producer gives up (3 auth failures), so the player's own recovery runs instead of a silent freeze | ✅ |
| 4 | I401-T04 | Host test: relay requests a new link on each upstream reconnect | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I401-A01 | macOS MediaKit Stalker channel plays 10+ minutes. Log shows `stalker relay` and `upstream refreshed` on panel socket closes. No `live glitch` / `goLive`, and the stats cache does not drop to zero | ⬜ |
| 2 | I401-A02 | Android TV Exo Stalker channel: same, no periodic restart | ⬜ |

---

## Summary

A Stalker channel plays ~15s, then restarts and the demuxer cache drops to zero. It repeats every 20–25s.

Stalker `create_link` URLs carry a one-shot `play_token`. RFC-113 opens them direct in mpv with lavf `reconnect_at_eof`. When the panel closes the TS socket, lavf re-requests the spent link and gets refused. mpv reports `completed`. The player waits the 6s grace, then `goLive` stops mpv (cache gone), waits the 2s slot, mints a new link, and opens again. Socket close + 6s + 2s + reopen is the 20–25s loop.

## Symptom fix

None shipped.

## Root fix

Stalker progressive live plays through the loopback continuity relay. The relay keeps mpv's connection and cache. On each upstream close it mints a fresh `create_link`, reconnects, and skips the panel overlap. HLS Stalker URLs stay direct.

## Workaround

No.
