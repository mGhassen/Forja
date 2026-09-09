# 123 — Android TV IPTV catalog focus after player

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV catalog · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I123-T01 | Exact row focus API (no silent fallback to tile 0) for catalog restore | ✅ |
| 2 | I123-T02 | After player pop: scroll channel into view, then focus that tile (retry for lazy grid) | ✅ |
| 3 | I123-T03 | Arm pending stream focus on controller before open; remount after `PlayerSurfaceChromeStub` restores that tile (await path was disposed) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I123-A01 | Android TV: Back from IPTV player lands D-pad on the channel that was playing, scrolled into view (incl. after guide channel change) | ⬜ |

---

## Summary

On **Android TV**, leaving the IPTV player should restore catalog focus to the channel that was playing (and scroll it into view).

**Earlier gap (T01–T02):** restore selected the group and tried to focus the tile, but `focusRowItem` fell back to **index 0** when the lazy grid had not built the target yet.

**Root cause after player-memory stub (T03):** `PlayerSurfaceChromeStub` unmounts the IPTV catalog while the player is up. `_onStreamTap`’s `await` continues on a **disposed** `_BrowserViewState`, so `if (!mounted) return` skipped `_restoreFocusAfterPlayback`. Remount then landed focus on the **category** rail (`preferCategoryFocus: true`).

**Fix:** arm `pendingPostPlayerStreamFocusId` on the controller before open (and on guide channel change). On catalog remount, `_syncInitialFocus` consumes it and runs channel restore (scroll + exact focus retry).

## Related

- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad
- [120](120-[open]-android-tv-player-memory-purge.md) — catalog stub under player
- [IPTV Xtream](../features/live/iptv-xtream.md)
