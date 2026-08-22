# 196 — Desktop window size resets after closing player

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop / player / window chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **2/2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I196-T01 | Stop player leave / FS toggle from calling `unmaximize` (Windows restore-frame) | ✅ |
| 2 | I196-T02 | Persist windowed size + position across relaunch (`DesktopWindowGeometry`) | ✅ |
| 3 | I196-T03 | Wire VOD / trailer / IPTV / Live Matches to shared leave + FS helpers | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I196-A01 | Windows: resize or maximize → open any stream → close player → same size + place | ✅ |
| 2 | I196-A02 | Relaunch keeps last windowed size/place (or maximized) | ✅ |

---

## Summary

Closing any desktop player (VOD, IPTV, Live Matches, trailer) called `windowManager.unmaximize()` (and fullscreen enter unmaximized first). On Windows that stamps the restore frame to the boot size (~1600×1000), so the windowed layout snapped back after close.

**Symptom fix:** leave player chrome only exits OS fullscreen; never unmaximize. Fullscreen toggle no longer unmaximizes first.

**Root fix:** same — stop corrupting the Windows restore frame; persist bounds so relaunch matches the user's place/size.

## Related

- `apps/forja/lib/shared/widgets/desktop_window_geometry.dart`
- `apps/forja/lib/app/bootstrap.dart`
