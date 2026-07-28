# 123 — Android TV IPTV catalog focus after player

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV catalog · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I123-T01 | Exact row focus API (no silent fallback to tile 0) for catalog restore | ✅ |
| 2 | I123-T02 | After player pop: scroll channel into view, then focus that tile (retry for lazy grid) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I123-A01 | Android TV: Back from IPTV player lands D-pad on the channel that was playing, scrolled into view (incl. after guide channel change) | ⬜ |

---

## Summary

On **Android TV**, leaving the IPTV player should restore catalog focus to the channel that was playing (and scroll it into view). Restore already selected the group and tried to focus the tile, but `focusRowItem` fell back to **index 0** when the lazy grid had not built the target yet — so focus often landed on the first channel instead of the one you watched.

**Root fix:** exact-index focus (no fallback) plus scroll-then-retry until the tile node exists; keep Favorites / Already watched when the channel is still in that list.

## Related

- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad
- [IPTV Xtream](../features/live/iptv-xtream.md)
