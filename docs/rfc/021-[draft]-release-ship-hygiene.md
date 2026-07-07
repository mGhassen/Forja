# RFC-021: Release and ship hygiene

**Version:** v1.0 (ship gate)  
**Status:** draft  
**Area:** CI, macOS notarization, repo root, branding assets

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 9** acceptance (v1.0 release gate) |
| **Current slice** | v1.0 — notarized release + clean repo |
| **Backlog** | — |

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
- Clean repo root (no legacy PlayTorrio paths)
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

## 2. macOS release + notarization

Extend [`scripts/build_macos.sh`](../../scripts/build_macos.sh):

```bash
flutter build macos --release
# codesign + notarize (Developer ID)
# staple + create Forja-{version}-macos.dmg
```

Requirements:
- Apple Developer ID Application certificate
- `NOTARY_APPLE_ID`, app-specific password in CI secrets
- Hardened runtime entitlements in `macos/Runner/*.entitlements`

Output artifact name per [RFC-015](015-[partial]-in-app-updates.md): `Forja-{version}-macos-arm64.dmg` (and intel if built).

## 3. CI pipeline

[`.github/workflows/build.yml`](../../.github/workflows/build.yml) on tag `v*`:

| Job | Output |
|-----|--------|
| macOS | `.dmg` + `.zip` |
| Windows | `Forja-Windows-Setup.exe` via [`installer/windows/setup.iss`](../../installer/windows/setup.iss) |
| Linux | `.AppImage` |
| Android | split APKs or universal APK |

Attach all to GitHub Release; [`AppUpdaterService`](../../packages/api/lib/services/app_updater_service.dart) matches asset filenames.

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

Bundle id: `com.forja.app` (consistent across platforms).

## 6. Desktop window chrome

[`desktop_window_chrome.dart`](../../apps/forja/lib/shared/widgets/desktop_window_chrome.dart) wraps the shell on macOS/Windows/Linux:

- macOS: hidden title bar + 34px drag strip (`kMacTitleBarHeight`) for traffic lights
- Windows/Linux: custom caption via `window_manager`

**Contract:**
- `DesktopWindowChrome.wrapShell(child: MainScreen(...))` applied once in bootstrap
- `DesktopWindowChrome.topInset(context)` used by shell nav for padding under drag region
- Frameless mode configured in [`MainFlutterWindow.swift`](../../apps/forja/macos/Runner/MainFlutterWindow.swift) — keep in sync with Dart inset

Document any change to title bar height in this RFC and both Swift + Dart constants.

## 7. Release checklist (v1.0 gate)

- [ ] Git working tree clean; no root legacy folders
- [ ] `melos bootstrap` + `flutter analyze` on app + 6 packages
- [ ] `flutter build macos --release` succeeds locally
- [ ] Notarized DMG installs on clean Mac
- [ ] GitHub Release on tag with all platform assets
- [ ] In-app update finds release (RFC-015)
- [ ] Icon + splash show Forja branding
- [ ] Jellyfin login works on macOS (keychain)

## Related

RFC-011 (v1.0 MVP), RFC-015 (updates), RFC-016–018 (can ship before or after hygiene)
