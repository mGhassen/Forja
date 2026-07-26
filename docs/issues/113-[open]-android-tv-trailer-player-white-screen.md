# 113 — Android TV trailer player white screen

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · YouTube WebView  
**Reported:** 2026-07-26 (released APK)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I113-T01 | Stop forcing TV `hardwareAcceleration: false` (`LAYER_TYPE_NONE` blanks YouTube) | ✅ |
| 2 | I113-T02 | Trailer + details-hero embeds use `transparentBackground: true` over black shell | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I113-A01 | Android TV release: open a details trailer — video plays (not white full-screen WebView) | ⬜ |
| 2 | I113-A02 | Android TV: details hero trailer crossfade still plays after backdrop beat | ⬜ |

---

## Summary

On released Android TV builds, opening the fullscreen trailer player left a **white** surface (Flutter chrome may still draw on top). Details-hero YouTube embeds share the same WebView settings path.

**Root cause:** [Issue 031](031-[workaround]-android-tv-webview-gles-crash.md) patched every TV `InAppWebView` with `hardwareAcceleration: false` → plugin `setLayerType(LAYER_TYPE_NONE)`. HTML5 / YouTube iframe video needs View hardware acceleration; without it the platform view stays the default white surface. That patch never stopped Chromium’s `gl_version_info.cc` fatal on broken emulators anyway.

**Fix:** Keep View HA enabled on TV. Emulator GLES still uses `scripts/atv-run.sh` (`--disable-gpu`) + headless extractor block from 031. Trailer / hero WebViews paint with a transparent background so the black scaffold shows while the embed loads.

## Related

- [031](031-[workaround]-android-tv-webview-gles-crash.md) — GLES workaround (HA=false reverted as harmful)
- [053](053-[workaround]-windows-live-embed-webview2-transparent.md) — Windows transparent embed parallel
