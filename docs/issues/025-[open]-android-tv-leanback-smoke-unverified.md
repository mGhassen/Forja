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
| **Progress** | **6 / 14** verification |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Automated gates

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I25-T01 | `platform_defaults_test.dart` + `settings_service_platform_defaults_test.dart` | ✅ |
| 2 | I25-T02 | `shell_adapters_test.dart` — TV profile uses nav rail via `ShellHost` | ✅ |
| 3 | I25-T03 | `main_screen_shell_test.dart` + `platform_channel_test.dart` | ✅ |
| 4 | I25-T04 | `check_tv_shell_boundary.sh` + `player_tv_remote_test.dart` + `shell_profile_behavior_test` TV boot | ✅ |
| 5 | I25-T05 | `shell_tv_coordinator_test` — nav trap, row column memory, Select activate | ✅ |
| 6 | I25-T06 | `tv_focus_graph_test.dart` — recipe register lifecycle, chip→results, grid, overlay | ✅ |

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

[RFC-028](../rfc/028-[draft]-adaptive-shell-profiles.md) adaptive shell ships native leanback detection (`MainActivity` MethodChannel), platform defaults seeding, `ShellHost` TV profile, `TvPlayerScreen` D-pad keys, focusable player chrome, and leanback manifest banner.

**Code (2026-07-20):** In-scope tab D-pad wiring landed for Home, Search, Anime, Asian Drama, My List, Settings, IPTV, Live Matches, plus shared player/seek/volume and shell restore. That does **not** flip `I25-M01`–`M08` — those still need leanback device / TV AVD smoke.

**Code (2026-07-28):** [RFC-048](../rfc/fixed/048-[fixed]-tv-focus-graph.md) ships `TvFocusGraph` recipes across those same in-scope surfaces (`I25-T06`). Still does **not** flip the manual matrix — leanback launcher + remote-only flows remain unverified.

**Leanback launcher and full D-pad flows are not verified** on device (manual matrix below still ⬜).

## Blocker (manual matrix)

Run `I25-M01`–`M08` on a leanback TV AVD or device per [platforms.md](../features/getting-started/platforms.md#android-tv-development). `FORJA_ANDROID_TV` dart-define does not satisfy these rows.

## Dev workaround (not leanback proof)

On a phone or emulator without TV system features:

```bash
flutter run -d <android-device> --dart-define=FORJA_ANDROID_TV=true
```

Forces TV profile + TV first-run defaults. Does **not** replace leanback launcher smoke.

## Related

- [RFC-048](../rfc/fixed/048-[fixed]-tv-focus-graph.md) — TV focus graph + screen recipes
- [platforms.md](../features/getting-started/platforms.md)
- [forja-tv-scope.mdc](../../.cursor/rules/forja-tv-scope.mdc)
