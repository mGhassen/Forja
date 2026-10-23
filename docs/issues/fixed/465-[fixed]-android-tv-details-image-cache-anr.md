# 465 — Android TV details image-cache ANR

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · media details · image disk cache  
**Reported:** 2026-10-23 (leanback emulator — open TMDB details, D-pad → Input ANR → Force finish)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Open a title’s details on Android TV, then D-pad around Play / episodes. After ~10s the app dies (`Lost connection to device`). No Dart exception.

Logcat: `Input dispatching timed out … Waited 10091ms for KeyEvent` → `Force finishing MainActivity` → `signal 9 (Killed)`. Same window: `Long db operation: …/libCachedImageData.db`.

## Root cause

Details mounted cast / trailers / rec covers via `ForjaNetworkImage` → `ForjaImageCacheManager` → `ForjaCacheIndex.insert`. Each insert awaited the exclusive SQLite `_onDisk` queue. Opening details piled dozens of inserts (plus home rails sharing the same DB) and starved KeyEvent delivery.

`forja_image_cache.dart` already batched touch-updates; inserts were still one-at-a-time.

Left from Play → `nav-home` is intentional hero-edge policy — not part of this bug.

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I465-T01 | Batch `ForjaCacheIndex.insert` into one SQLite transaction (memory map first; coalesce same-frame inserts) | ✅ |
| 2 | I465-T02 | Foundation test for insert coalescing / batch flush | ✅ |
| 3 | I465-T03 | Defer cast / trailers / pack-rail mount ~600ms after details paint so hero+episodes own the first KeyEvents | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I465-A01 | Open series details on Android TV; D-pad Play ↔ episodes ↔ seasons for 30s without ANR kill | ⬜ |
| 2 | I465-A02 | Cast / trailer / rec posters still load when the below-fold sections appear | ⬜ |

---

## Links

- Related stutter: [139](../139-[open]-android-tv-shell-focus-chrome-stutter.md), [157](../157-[open]-android-tv-ken-burns-hero-stutter.md)
- Feature: [tmdb-details](../../features/movies-tv/tmdb-details.md)
