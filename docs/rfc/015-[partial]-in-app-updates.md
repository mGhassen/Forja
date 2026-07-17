# RFC-015: In-app update system

**Version:** v1.0 (partial) / v1.1 (complete)  
**Status:** partial — GitHub check + dialog shipped; platform install paths uneven  
**Area:** `apps/forja/lib/shared/services/app_updater_service.dart`, `apps/forja/lib/shared/widgets/update_dialog.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** acceptance (v1.0) · **9 / 13** acceptance (v1.1 slice) · **3 / 3** acceptance (Supabase release mirror, historical) · **2 / 2** acceptance (GitHub-only) |
| **Current slice** | Multi-version changelog — dialog shows all GitHub release notes since the installed version |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-C01 | Update checker (`app_updater_service.dart`) | ✅ |
| 2 | R15-C02 | Update UI (`update_dialog.dart`) | ✅ |
| 3 | R15-C03 | Startup check in MainScreen | ✅ |
| 4 | R15-C04 | Manual check in Settings | ✅ |
| 5 | R15-C05 | Android OTA (`ota_update`) | ✅ |
| 6 | R15-C06 | macOS/iOS open download page | ✅ |
| 7 | R15-C07 | Semver compare + GitHub API | ✅ |

---

## Acceptance (v1.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A01 | GitHub latest release check | ✅ |
| 2 | R15-A02 | Semver compare vs `package_info_plus` | ✅ |
| 3 | R15-A03 | Update dialog with release notes | ✅ |
| 4 | R15-A04 | Android in-app OTA install | ✅ |
| 5 | R15-A05 | macOS/iOS open download page | ✅ |
| 6 | R15-A06 | Manual check in Settings | ✅ |
| 7 | R15-A07 | Startup check in MainScreen | ✅ |

---

## Acceptance (v1.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A08 | `update_dismissed_version` — respect Later | ⬜ |
| 2 | R15-A09 | Auto-check throttle (max once per 24h) | ⬜ |
| 3 | R15-A10 | Windows/Linux download with in-dialog progress | ✅ |
| 4 | R15-A11 | macOS: download DMG to Downloads + open | ✅ |
| 5 | R15-A12 | SHA256 verification before install | ⬜ |
| 6 | R15-A13 | Repo slug configurable / Forja-branded GitHub org | ✅ |
| 7 | R15-A14 | CI publishes correctly named assets on every `v*` tag | 🔄 |
| 8 | R15-A17 | Windows/macOS download errors offer a clickable direct asset URL | ✅ |
| 9 | R15-A18 | macOS opens the downloaded DMG only after Install confirmation, then closes Forja | ✅ |
| 10 | R15-A19 | Desktop update can continue in the background and posts an Install toast when ready | ✅ |
| 11 | R15-A20 | Update check detects an already-downloaded installer and goes directly to install confirmation | ✅ |
| 12 | R15-A21 | Windows launches the downloaded installer only after confirmation, then closes Forja | ✅ |
| 13 | R15-A22 | Background download shows a sticky progress toast (dismissible; hidden over video players) | ✅ |

---

## Acceptance (v1.2 optional)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A15 | Beta channel toggle | ⏭️ |
| 2 | R15-A16 | Mandatory update support | ⏭️ |

---

## Acceptance (Supabase release mirror)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A23 | Edge Function mirrors GitHub Releases into `releases` / `release_assets` | ✅ |
| 2 | R15-A24 | `AppUpdaterService` prefers Supabase latest release for platform asset | ✅ |
| 3 | R15-A25 | Fallback to GitHub Releases API when Supabase empty or errors | ✅ |

---

## Acceptance (GitHub-only — RFC-036)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A26 | `AppUpdaterService` checks GitHub Releases only (no Supabase `releases` / `release_assets`) | ✅ |
| 2 | R15-A27 | Update dialog aggregates release notes for every stable GitHub release newer than the installed version (newest first; skips empty / auto-only bodies) | ✅ |

---

## Summary

Forja checks GitHub Releases for a newer version, shows an in-app dialog with release notes, and installs or downloads per platform. GitHub is the publish source of truth and the only in-app check path after RFC-036 dropped the Supabase `releases` mirror.

## Goals

- User discovers updates without leaving the app (or via Settings → Check for updates)
- Android: download APK + install in-app (`ota_update`)
- Windows/Linux: download installer/binary with progress
- macOS: download `.dmg` to Downloads and open the disk image; iOS: open release page (store policy limits in-app install)
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
│  apps/forja/lib/shared/services/app_updater_service.dart │
│    GET GitHub Releases API → semver compare → UpdateInfo │
└───────────────────────────┬─────────────────────────────┘
                            │
                    GitHub Releases
              (tag vX.Y.Z + platform assets)
```


## Update manifest (GitHub Releases)

**Endpoint:** `GET https://api.github.com/repos/{owner}/{repo}/releases?per_page=100`

Config: `githubRepo = 'mGhassen/Forja'` in `apps/forja/lib/shared/services/app_updater_service.dart`.

**Release tag:** `v1.2.3` (leading `v` stripped for compare).

Latest install target = newest non-draft, non-prerelease release. Download assets come from that release only.

**Required assets per platform:**

| Platform | Asset naming (convention) | Install path |
|----------|---------------------------|--------------|
| Android | `*Forja*.apk` or `*.apk` | In-app OTA install |
| Windows | `*windows*.exe` | Download + launch installer |
| Linux | `*.AppImage` or `*.deb` | Download + chmod + exec |
| macOS | `Forja-*-macos-arm64.dmg` (prefer host arch) | Download to Downloads + `open` DMG |
| iOS | — | Link to releases / TestFlight only |

**Release body:** Markdown from every stable release newer than the installed version is aggregated (newest first) into the dialog. Empty bodies and GitHub auto `Full Changelog:` stubs are skipped. When more than one version contributes notes, each block is headed with `# X.Y.Z`.

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

| Platform | Shipped | Remaining |
|----------|---------|-----------|
| Android | OTA download + install intent | + SHA256 verify asset |
| Windows | Download `.exe` with in-dialog progress | silent optional |
| Linux | Download AppImage/deb with progress | AppImage exec helper |
| macOS | Download `.dmg` to Downloads + `open` | SHA256 verify |
| iOS | Open releases URL | TestFlight deep link if configured |

## Settings keys (v1.1)

Add to `SettingsService` / `storage`:

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

`.github/workflows/build.yml` is manual only (optional smoke builds, artifacts only). `.github/workflows/release.yml` (**Release Forja**) — new version or existing tag; publish GitHub Release with:

```
Forja-1.2.3-android-tv-arm64.apk
Forja-1.2.3-android-tv-armeabi-v7a.apk
Forja-1.2.3-windows-setup.exe
Forja-1.2.3-macos-arm64.dmg
Forja-1.2.3-linux-x86_64.AppImage
```

Release workflow supports per-platform toggles (macOS, Windows, Linux, Android TV). Untagged commits: `.github/workflows/backfill-tags.yml`. Android TV requires signing secrets (`FORJA_KEYSTORE_*`).

GitHub Release created from tag with these assets attached. App updater matches by filename patterns.

## Future (v1.2+)

- Custom update endpoint (JSON manifest) for mirrors / China
- Beta channel: `GET /repos/{repo}/releases` filter `prerelease`
- Mandatory update flag in manifest for critical security fixes
- macOS Sparkle framework alternative for signed delta updates


## Related

RFC-011 (v1.0 MVP), CI in `.github/workflows/build.yml`, installer `installer/windows/setup.iss`
