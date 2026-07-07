# 012 — Mobile magnet → HTTP stream E2E (P2-14)

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed (2026-07-06)  
**Area:** `crates/torrent`, `crates/ffi`, iOS/Android CI  
**Reported:** 2026-07-06  
**Tracked:** P2-14 ([Phase 2 task](../migration/fixed/02-[fixed]-rust-engine-complete.md))

## Summary

Mobile magnet playback via librqbit + localhost proxy is verified on Android emulator in CI and via device script. Desktop optional E2E unchanged (`engine_smoke_test.dart` + `TORRENT_E2E=1`).

## Fix (shipped — 2026-07-06)

1. **`apps/forja/test/mobile_magnet_e2e_test.dart`** — mobile-only tests: engine load, playback profile, torrent engine start, invalid magnet, `TorrentStreamService` lifecycle; optional full magnet flow with `TORRENT_E2E=1`.
2. **`apps/forja/test/helpers/torrent_e2e.dart`** — shared magnet → localhost HTTP probe (desktop + mobile).
3. **`scripts/run_mobile_magnet_e2e.sh`** — build mobile FFI + `flutter test` on connected device/emulator.
4. **CI** — `.github/workflows/rust.yml` job `android-magnet-e2e` runs smoke on Android emulator (API 34).
5. **`melos run rust:mobile-integration`** — local device sign-off.

**Verify locally:**

```bash
./scripts/build_rust_mobile.sh android
./scripts/run_mobile_magnet_e2e.sh

# Full magnet → HTTP (slow, needs network):
TORRENT_E2E=1 ./scripts/run_mobile_magnet_e2e.sh
```

**Note:** E2E verifies magnet → librqbit → `http://127.0.0.1:…` → HTTP bytes (same as desktop). `media_kit` playback is host-layer — manual spot-check on device after E2E passes.

## Acceptance

- [x] Device or emulator test: magnet → librqbit → localhost URL → HTTP bytes
- [x] P2-14 marked ✅ in migration doc
- [x] T6 row ✅ in playback engine exit checklist
