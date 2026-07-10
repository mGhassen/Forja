# 025 — Android TV leanback smoke unverified

**Priority:** P1  
**Severity:** High  
**Status:** open  
**Area:** `apps/forja/lib/shell/adapters/`, Android TV leanback launcher, D-pad UX  
**Reported:** 2026-07-10  
**RFC:** [RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 11** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Automated gates

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I25-T01 | `platform_defaults_test.dart` + `settings_service_platform_defaults_test.dart` | ✅ |
| 2 | I25-T02 | `shell_adapters_test.dart` — TV profile uses nav rail via `ShellHost` | ✅ |
| 3 | I25-T03 | `main_screen_shell_test.dart` + `platform_channel_test.dart` | ✅ |

---

## Manual matrix (leanback device / TV AVD)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I25-M01 | App launches from Android TV leanback launcher | ⬜ |
| 2 | I25-M02 | D-pad navigates nav rail across in-scope tabs | ⬜ |
| 3 | I25-M03 | Home → details → play with remote only | ⬜ |
| 4 | I25-M04 | Anime + Asian drama browse + play | ⬜ |
| 5 | I25-M05 | IPTV portal + live play + channel guide D-pad | ⬜ |
| 6 | I25-M06 | Search → result → play | ⬜ |
| 7 | I25-M07 | My List + Settings usable with remote | ⬜ |
| 8 | I25-M08 | Player: play/pause, seek ±10s, Back exit, subtitles reachable | ⬜ |

---

## Summary

[RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md) adaptive shell ships native leanback detection (`MainActivity` MethodChannel), platform defaults seeding, `ShellHost` TV profile, `TvPlayerScreen` D-pad keys, and leanback manifest banner. **Leanback launcher and full D-pad flows are not verified** on this machine (no Android TV AVD / `adb`).

## Dev workaround (not leanback proof)

On a phone or emulator without TV system features:

```bash
flutter run -d <android-device> --dart-define=FORJA_ANDROID_TV=true
```

Forces TV profile + TV first-run defaults. Does **not** replace leanback launcher smoke.

## Related

- [platforms.md](../features/getting-started/platforms.md)
- [forja-tv-scope.mdc](../../.cursor/rules/forja-tv-scope.mdc)
