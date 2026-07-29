# RFC-021: Release and ship hygiene

**Version:** v1.0 (ship gate)  
**Status:** draft  
**Area:** CI, macOS notarization, repo root, branding assets

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 8** acceptance · **2** 🔄 · **1** ⏭️ notarize |
| **Current slice** | CI ships ad-hoc DMG; Rust/Flutter caches + build heartbeats in release/build workflows |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.0 release gate)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R21-A01 | Git working tree clean; no root legacy folders | ⬜ |
| 2 | R21-A02 | `melos bootstrap` + `flutter analyze` on app + packages | ⬜ |
| 3 | R21-A03 | `flutter build macos --release` succeeds locally | ⬜ |
| 4 | R21-A04 | Notarized DMG installs on clean Mac | ⏭️ |
| 5 | R21-A05 | GitHub Release on tag with all platform assets | 🔄 |
| 6 | R21-A06 | In-app update finds release (RFC-015) | 🔄 |
| 7 | R21-A07 | Icon + splash show Forja branding | ⬜ |
| 8 | R21-A08 | Jellyfin login works on macOS (keychain) | ⬜ |
| 9 | R21-A09 | Release/build CI caches Rust `crates/target` + Flutter pub; long builds emit heartbeats | ✅ |

---


## Summary

Clean git history, automated release builds, macOS notarization, platform entitlements, and branding assets — so v1.0 is shippable, not just debug-runnable.

## Problem

- Migration deletions (root `lib/`, UI packages, duplicate assets) may remain uncommitted
- macOS: debug build works; release + notarization not documented in CI
- Jellyfin on macOS: keychain errors (`-34018`) without entitlement
- Branding assets exist (`logo-light/dark.svg`, splash images) but not fully wired to runners
- Updates (RFC-015) need CI to publish consistently named release assets

## Goals

- Reproducible `v*` tag → GitHub Release with platform artifacts
- Notarized macOS `.dmg` users can open without Gatekeeper fights
- Clean repo root (no legacy paths)
- Consistent Forja branding on icon + splash + window chrome

---

## 1. Git and repo layout

**Target repo root:**

```
Forja/
  apps/forja/          # sole Flutter app
  packages/            # 6 engine packages
  docs/rfc/
  scripts/
  melos.yaml
  pubspec.yaml         # workspace only
```

**Remove from root (if still tracked):** `lib/`, `android/`, `ios/`, `windows/`, duplicate `assets/`, deleted UI packages under `packages/forja_ui` etc.

Single commit message theme: `chore: remove legacy root app and UI packages`

## 2. macOS release (unsigned DMG today · notarization deferred)

**Shipped path (no paid Apple Developer ID):**

- CI: build with `FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO`, then [`scripts/codesign_macos_adhoc.sh`](../../scripts/codesign_macos_adhoc.sh) (`codesign --deep --sign -`, **no entitlements**)
- `macos/Runner/Release.entitlements`: **App Sandbox off** (if Xcode ever embeds entitlements locally)
- Package via [`scripts/package_macos_dmg.sh`](../../scripts/package_macos_dmg.sh) → `Forja-{version}-macos-{arm64|x86_64}.dmg`

**Do not** ship Release with App Sandbox on under ad-hoc (Launch Services `kLSNoExecutableErr`). **Do not** ship with unsigned frameworks (`CODE_SIGNING_ALLOWED=NO` alone — dyld rejects them).

**Deferred (R21-A04):** Developer ID + `notarytool` + staple — only if/when a paid Apple team is available.

```bash
flutter build macos --release
# optional later: codesign + notarize (Developer ID) + staple
# create Forja-{version}-macos-arm64.dmg (and macos-x86_64 on CI Intel runner)
```

## 3. CI pipeline

[`.github/workflows/build.yml`](../../.github/workflows/build.yml) manual dispatch only (optional smoke builds, artifacts only).

[`.github/workflows/release.yml`](../../.github/workflows/release.yml) manual dispatch — **New version** (patch/minor/major + tag) or **Existing tag**. [`.github/workflows/backfill-tags.yml`](../../.github/workflows/backfill-tags.yml) tags untagged commits (dry-run optional). Toggle platforms per run:

| Job | Output |
|-----|--------|
| macOS | `Forja-{version}-macos-arm64.dmg` + `Forja-{version}-macos-x86_64.dmg` |
| Windows | `Forja-{version}-windows-setup.exe` via [`installer/windows/setup.iss`](../../installer/windows/setup.iss); CI bundles MSVC CRT via [`scripts/bundle_windows_msvc_crt.sh`](../../scripts/bundle_windows_msvc_crt.sh) before Inno |
| Linux | `Forja-{version}-linux-x86_64.AppImage` |
| Android TV | `Forja-{version}-android-tv-arm64.apk` + `Forja-{version}-android-tv-armeabi-v7a.apk` |

Attach selected assets to GitHub Release; [`AppUpdaterService`](../../apps/forja/lib/shared/services/app_updater_service.dart) matches asset filenames (Android TV by ABI).

**Build speed (R21-A09):** shared [`.github/actions/setup-forja-build`](../../.github/actions/setup-forja-build/action.yml) enables `Swatinem/rust-cache` (`crates -> target`) and Flutter pub cache. Long Rust/Flutter steps wrap [`scripts/ci_with_heartbeat.sh`](../../scripts/ci_with_heartbeat.sh) so logs keep moving during silent MSVC/Xcode compiles. Existing-tag jobs sync those helpers from the workflow SHA via [`scripts/ci_sync_helpers_from_workflow.sh`](../../scripts/ci_sync_helpers_from_workflow.sh). Cold Flutter/Xcode/MSVC app compile remains the bulk of wall time — caches mainly cut Rust + pub download.

## 4. Platform entitlements and fixes

| Platform | Item |
|----------|------|
| macOS | Keychain access for Jellyfin (`keychain-access-groups` in entitlements) |
| macOS | Network client/server for IPTV, torrent, local proxy |
| iOS | Background audio (`UIBackgroundModes`) — verify |
| Android | `REQUEST_INSTALL_PACKAGES` for OTA (already in manifest) |
| Android TV | Leanback launcher intent (already in manifest); TV shell UX future |

## 5. Branding assets

Wire existing files:

| Asset | Use |
|-------|-----|
| [`assets/icon/logo-light.svg`](../../apps/forja/assets/icon/logo-light.svg) | Light mode about/settings |
| [`assets/icon/logo-dark.svg`](../../apps/forja/assets/icon/logo-dark.svg) | Dark mode |
| [`assets/icon/logo-dark.png`](../../apps/forja/assets/icon/logo-dark.png) | macOS/iOS icon source |
| [`assets/images/splash-1.jpg`](../../apps/forja/assets/images/splash-1.jpg) | Native splash rotation |
| [`assets/images/splash-2.png`](../../apps/forja/assets/images/splash-2.png) | Native splash |

Update:
- `macos/Runner/Assets.xcassets`
- `android/app/src/main/res/` mipmaps
- [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) splash config
- [`pubspec.yaml`](../../apps/forja/pubspec.yaml) `flutter.assets` entries

Bundle id: `com.forjahq.app` (consistent across platforms).

## 6. Desktop window chrome

[`desktop_window_chrome.dart`](../../apps/forja/lib/shared/widgets/desktop_window_chrome.dart) wraps the shell on macOS/Windows/Linux:

- macOS: hidden title bar + 34px drag strip (`kMacTitleBarHeight`) for traffic lights
- Windows/Linux: custom caption via `window_manager`

**Contract:**
- `DesktopWindowChrome.wrapShell(child: MainScreen(...))` applied once in bootstrap
- `DesktopWindowChrome.topInset(context)` used by shell nav for padding under drag region
- Frameless mode configured in [`MainFlutterWindow.swift`](../../apps/forja/macos/Runner/MainFlutterWindow.swift) — keep in sync with Dart inset

Document any change to title bar height in this RFC and both Swift + Dart constants.


## Related

RFC-011 (v1.0 MVP), RFC-015 (updates), RFC-016–018 (can ship before or after hygiene)
