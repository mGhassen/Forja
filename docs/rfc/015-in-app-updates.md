# RFC-015: In-app update system

**Version:** v1.0 (partial) / v1.1 (complete)  
**Status:** Partial — GitHub check + dialog shipped; platform install paths uneven

## Summary

Forja checks GitHub Releases for a newer version, shows an in-app dialog with release notes, and installs or downloads per platform. No separate update server — releases are the source of truth.

## Goals

- User discovers updates without leaving the app (or via Settings → Check for updates)
- Android: download APK + install in-app (`ota_update`)
- Windows/Linux: download installer/binary with progress
- macOS/iOS: open release page or DMG (store policy limits in-app install on iOS)
- Optional: skip version, auto-check interval, mandatory security updates

## Non-goals (v1.0)

- Custom update CDN / delta patches
- iOS App Store in-app updates (TestFlight/App Store handles this)
- Torrent or P2P distribution

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  apps/forja                                              │
│    shell/main_screen.dart     → check on startup         │
│    features/settings/         → manual check             │
│    shared/widgets/update_dialog.dart                     │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  packages/forja_api/services/app_updater_service.dart    │
│    GET GitHub Releases API → semver compare → UpdateInfo │
└───────────────────────────┬─────────────────────────────┘
                            │
                    GitHub Releases
              (tag vX.Y.Z + platform assets)
```

## Components (current)

| Piece | Path |
|-------|------|
| Update checker | `packages/forja_api/lib/services/app_updater_service.dart` |
| Update UI | `apps/forja/lib/shared/widgets/update_dialog.dart` |
| Startup check | `apps/forja/lib/shell/main_screen.dart` → `_checkForUpdates()` |
| Manual check | `apps/forja/lib/features/settings/settings_screen.dart` |
| Android OTA | `ota_update` package + `AndroidManifest` provider |

## Update manifest (GitHub Releases)

**Endpoint:** `GET https://api.github.com/repos/{owner}/{repo}/releases/latest`

Config today: `githubRepo = 'ayman708-UX/ForjaV2'` (should move to `forja/forja` or env/build flag).

**Release tag:** `v1.2.3` (leading `v` stripped for compare).

**Required assets per platform:**

| Platform | Asset naming (convention) | Install path |
|----------|---------------------------|--------------|
| Android | `*Forja*.apk` or `*.apk` | In-app OTA install |
| Windows | `*windows*.exe` | Download + launch installer |
| Linux | `*.AppImage` or `*.deb` | Download + chmod + exec |
| macOS | `*.dmg` or `*.zip` | Open releases page / mount DMG (v1.1: in-app download) |
| iOS | — | Link to releases / TestFlight only |

**Release body:** Markdown release notes shown in dialog (scrollable).

## Version comparison

Semver triple: `major.minor.patch` — numeric compare per segment.

Build number (`1.0.0+42` from pubspec) ignored for GitHub tag compare; optional future use for same-tag rebuilds.

## User flows

### Auto-check (startup)

1. App launches → `MainScreen.initState` → `AppUpdaterService.checkForUpdates()`
2. If newer version → non-dismissible-on-first-show dialog (`UpdateDialog`)
3. User: **Update Now** | **Later**

Throttle: do not re-prompt same version within 24h if user tapped Later (v1.1 — persist in `SettingsService`).

### Manual check (Settings)

Settings → About → **Check for updates** → same dialog or "You're up to date" snackbar.

### Platform install behavior

| Platform | v1.0 (today) | v1.1 (target) |
|----------|--------------|---------------|
| Android | OTA download + install intent | + SHA256 verify asset |
| Windows | Download `.exe`, run installer | + progress bar, silent optional |
| Linux | Download AppImage/deb | + AppImage exec helper |
| macOS | Open browser / releases URL | Download `.dmg`, open mount helper |
| iOS | Open releases URL | TestFlight deep link if configured |

## Settings keys (v1.1)

Add to `SettingsService` / `forja_storage`:

| Key | Type | Default |
|-----|------|---------|
| `update_last_check_at` | ISO8601 | null |
| `update_dismissed_version` | string | null |
| `update_auto_check_enabled` | bool | true |
| `update_channel` | `stable` \| `beta` | stable |

**Skip version:** `update_dismissed_version = latestVersion` suppresses dialog until a newer tag appears.

## Security

- **HTTPS only** for GitHub API and asset URLs
- **v1.1:** Verify APK/asset SHA256 against checksum in release body or `checksums.txt` asset
- **v1.1:** Optional Ed25519 signature file for desktop binaries
- Never auto-install without user confirmation (except optional "silent" Windows enterprise mode — out of scope)
- Android: `REQUEST_INSTALL_PACKAGES` permission already in manifest

## Error handling

| Failure | UX |
|---------|-----|
| Network error | Silent on startup; snackbar on manual check |
| No asset for platform | Fall back to `html_url` (releases page) |
| Rate limit (GitHub API) | Cache last successful response 1h |
| Download interrupted | Retry button in dialog |
| OTA permission denied | Snackbar + link to settings |

## CI / release integration

`.github/workflows/build.yml` uploads artifacts per platform on tag push `v*`:

```
Forja-1.2.3-android-arm64.apk
Forja-1.2.3-windows-setup.exe
Forja-1.2.3-macos-arm64.dmg
Forja-1.2.3-linux-x86_64.AppImage
```

GitHub Release created from tag with these assets attached. App updater matches by filename patterns.

## Future (v1.2+)

- Custom update endpoint (JSON manifest) for mirrors / China
- Beta channel: `GET /repos/{repo}/releases` filter `prerelease`
- Mandatory update flag in manifest for critical security fixes
- macOS Sparkle framework alternative for signed delta updates

## Acceptance

**v1.0 (partial — done):**
- [x] GitHub latest release check
- [x] Semver compare vs `package_info_plus`
- [x] Update dialog with release notes
- [x] Android in-app OTA install
- [x] macOS/iOS open download page
- [x] Manual check in Settings
- [x] Startup check in MainScreen

**v1.1 (complete):**
- [ ] `update_dismissed_version` — respect "Later"
- [ ] Auto-check throttle (max once per 24h on startup)
- [ ] Windows/Linux download with in-dialog progress (desktop path exists, polish)
- [ ] macOS: download DMG to Downloads + open
- [ ] SHA256 verification before install
- [ ] Repo slug configurable / Forja-branded GitHub org
- [ ] CI publishes correctly named assets on every `v*` tag

**v1.2 (optional):**
- [ ] Beta channel toggle
- [ ] Mandatory update support

## Related

RFC-011 (v1.0 MVP), CI in `.github/workflows/build.yml`, installer `installer/windows/setup.iss`
