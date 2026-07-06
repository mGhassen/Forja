# 012 — Mobile magnet → HTTP stream E2E not verified (P2-14)

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `crates/torrent`, `crates/ffi`, iOS/Android CI  
**Reported:** 2026-07-06  
**Tracked:** P2-14 ([Phase 2 task](../migration/02-rust-engine-complete.md))

## Summary

Wave 1 exit checklist row **T6** is still ⬜. Desktop magnet E2E exists (`engine_smoke_test.dart` with `TORRENT_E2E=1`). iOS/Android device playback via librqbit + localhost proxy is **not** proven in CI or documented manual sign-off.

## Risk

- Mobile-specific FFI/dylib loading failures undetected until user plays torrent
- Architecture assumptions in [003](003-stremio-platform-playback-model.md) untested on real devices

## Acceptance

- [ ] Device or emulator test: magnet → librqbit → localhost URL → media_kit plays
- [ ] P2-14 marked ✅ in migration doc
- [ ] T6 row ✅ in playback engine exit checklist
