# RFC-015: In-app update system

**Version:** v1.0 (partial) / v1.1 (complete)  
**Status:** partial — GitHub check + dialog shipped; platform install paths uneven  
**Area:** `apps/forja/lib/shared/services/app_updater_service.dart`, `apps/forja/lib/shared/widgets/update_dialog.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** acceptance (v1.0) · **11 / 13** acceptance (v1.1 slice) · **3 / 3** acceptance (Supabase release mirror, historical) · **2 / 2** acceptance (GitHub-only) · **5 / 5** acceptance (Supabase Storage downloads, historical) · **5 / 6** acceptance (Cloudflare R2 downloads) · **1 / 1** acceptance (startup order) · **3 / 3** acceptance (R2 discovery + dialog changelogs, historical) · **2 / 3** acceptance (R2 changelog archive) · **4 / 4** acceptance (per-platform latest) · **4 / 4** acceptance (per-arch latest) · **1 / 1** acceptance (ATV focus trap) · **2 / 2** acceptance (ATV two-column changelog, historical) · **1 / 1** acceptance (ATV stacked changelog) |
| **Current slice** | Per-arch `arches` map shipped; hosted smoke A37 / A45 still open |

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
| 1 | R15-A08 | `update_dismissed_version` — respect Later / Skip (no auto re-prompt until a newer version) | ✅ |
| 2 | R15-A09 | In-session auto-check in `MainScreen` (periodic + resume, ≥1h throttle); deferred while a player is open | ✅ |
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

## Acceptance (Supabase Storage downloads)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A28 | Public Storage bucket `releases` (1 GiB object limit) via migration | ✅ |
| 2 | R15-A29 | Release CI uploads flattened installers to `releases/v{version}/` with service role | ✅ |
| 3 | R15-A30 | Web `/download` + landing CTAs use Supabase public object URLs | ✅ |
| 4 | R15-A31 | `AppUpdaterService` downloads installers from Supabase Storage (GitHub API for version/notes; GitHub asset URL fallback if `SUPABASE_URL` unset) | ✅ |
| 5 | R15-A32 | After upload, prune Storage to newest 3 version folders (`RELEASE_STORAGE_KEEP`) | ✅ |

---

## Acceptance (Cloudflare R2 downloads)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A33 | Release CI uploads flattened installers to R2 `forja-releases` at `v{version}/` and mirrors `latest/` (S3 API) | ✅ |
| 2 | R15-A34 | Web `/download` + landing CTAs use `{RELEASE_CDN_URL}/latest/…` | ✅ |
| 3 | R15-A35 | `AppUpdaterService` prefers `{RELEASE_CDN_URL}/latest/…` (versioned path fallback; GitHub asset if CDN unset) | ✅ |
| 4 | R15-A36 | After upload, prune R2 to newest 3 version prefixes (`RELEASE_STORAGE_KEEP`); refresh `latest/` | ✅ |
| 5 | R15-A37 | Hosted release smoke: DMG/EXE/AppImage/APK download from CDN succeeds | ⬜ |
| 6 | R15-A38 | macOS update dialog treats CDN (and any direct `.dmg`/installer URL) as in-app download — not GitHub `/releases/download/` only | ✅ |

---

## Acceptance (startup order)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A39 | Startup update check runs in `DesktopStartupGate` before desktop auth and before splash (not after MainScreen splash dismiss) | ✅ |

---

## Acceptance (R2-only discovery)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A40 | Release CI writes `latest/manifest.json` (+ `v{version}/manifest.json`) with version + asset filenames only (changelog stays on GitHub Releases) | ✅ |
| 2 | R15-A41 | `AppUpdaterService` discovers updates via `{RELEASE_CDN_URL}/latest/manifest.json` and downloads `{RELEASE_CDN_URL}/v{version}/{filename}` | ✅ |
| 3 | R15-A42 | Update dialog loads GitHub Release notes for versions since installed (max 16), left version rail, “See full changelog” → `{FORJA_WEB_URL}/changelog` | ✅ |

---

## Acceptance (R2 changelog archive)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A43 | Release CI mirrors `docs/changelog/done/*-[released].md` → R2 `changelog/{version}.md` + `changelog/index.json` | ✅ |
| 2 | R15-A44 | R2 prune / stale `latest/` cleanup never deletes `changelog/` (permanent notes archive) | ✅ |
| 3 | R15-A45 | Update dialog loads notes from R2 `changelog/` for versions since installed (max 16); GitHub Releases fallback if CDN empty | ⬜ |

---

## Acceptance (per-platform latest)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A46 | R2 upload merges `latest/` by platform — partial release replaces only that platform’s installers; never wipes others | ✅ |
| 2 | R15-A47 | `latest/manifest.json` carries `platforms.{id}.{version,assets}`; prune keeps any version still referenced as a platform latest | ✅ |
| 3 | R15-A48 | Web `/download` shows each platform’s own latest version + that version’s changelog notes | ✅ |
| 4 | R15-A49 | `AppUpdaterService` compares against this device’s platform entry in `platforms` (not a single global max version) | ✅ |

---

## Acceptance (Android TV focus)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A50 | Update gate wraps `TvOverlayScope` and claims Install / Continue focus so ATV D-pad cannot drive the shell underneath | ✅ |

---

## Acceptance (ATV two-column changelog)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A51 | ATV update gate is two columns: offer + Install left, version rail + notes right; headline on one line | ✅ |
| 2 | R15-A52 | ATV: Install initial; ↑/→ changelog pane; OK enter; ↑↓ scroll notes; ←→ versions; OK/Back exit; ↓/← Install | ✅ |

---

## Acceptance (ATV stacked changelog)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A53 | ATV update gate stacked like desktop: header top-center, version rail + notes, Install pinned; no pane border; ↑↓ versions then → notes | ✅ |

---

## Acceptance (per-arch latest)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R15-A54 | R2 upload writes `platforms.*.arches.{arch}.{version,filename,published_at}`; platform `version` stays max across arches | ✅ |
| 2 | R15-A55 | Partial arch upload keeps sibling arch entries (version + published_at) | ✅ |
| 3 | R15-A56 | `AppUpdaterService` compares/downloads using host-arch entry only (no cross-arch fallback; no platform-max offer) | ✅ |
| 4 | R15-A57 | Web `/download` asset versions come from `arches` (filename fallback) | ✅ |

---

## Summary

Forja checks Cloudflare R2 for a newer version (`latest/manifest.json` — **per-platform** and **per-arch** latest installers), then downloads the matching arch installer from `latest/{filename}` (versioned `v{version}/` as fallback). A macOS-only or single-arch publish updates only that arch entry and leaves sibling arches and other platforms in place. Changelog bodies for the dialog come from the permanent R2 `changelog/` archive (`index.json` + `{version}.md`), with GitHub Releases as fallback; the UI lists up to 16 versions since the installed build and links to the portal `/changelog`. The download page shows each platform’s own version and notes (per download button / arch).

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
│    app/desktop_startup_gate.dart → check on cold start   │
│    shell/main_screen.dart     → (historical; R15-A07)    │
│    features/settings/         → manual check             │
│    shared/widgets/update_dialog.dart                     │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  apps/forja/lib/shared/services/app_updater_service.dart │
│    R2 manifest → semver → notes from changelog/ → UpdateInfo │
└───────────────┬─────────────────────────┬───────────────┘
                │                         │
        Cloudflare R2                 GitHub Releases
  latest/manifest.json              (per-platform latest; notes via changelog/)
  vX.Y.Z/{installer}
  changelog/{version}.md  (kept forever)
  changelog/index.json
```

### Per-platform `latest/manifest.json`

```json
{
  "published_at": "2026-08-12T00:20:29Z",
  "platforms": {
    "macos": {
      "version": "1.3.267",
      "published_at": "2026-08-12T00:20:29Z",
      "assets": [
        "Forja-1.3.267-macos-arm64.dmg",
        "Forja-1.3.247-macos-x86_64.dmg"
      ],
      "arches": {
        "arm64": {
          "version": "1.3.267",
          "filename": "Forja-1.3.267-macos-arm64.dmg",
          "published_at": "2026-08-12T00:20:29Z"
        },
        "x86_64": {
          "version": "1.3.247",
          "filename": "Forja-1.3.247-macos-x86_64.dmg",
          "published_at": "2026-08-10T19:00:14Z"
        }
      }
    },
    "windows": {
      "version": "1.3.247",
      "published_at": "2026-08-10T19:00:14Z",
      "assets": ["Forja-1.3.247-windows-setup.exe"],
      "arches": {
        "default": {
          "version": "1.3.247",
          "filename": "Forja-1.3.247-windows-setup.exe",
          "published_at": "2026-08-10T19:00:14Z"
        }
      }
    }
  }
}
```

`platforms` is the source of truth on `latest/manifest.json`. Platform `version` is the **max** across arches (glance / old clients). Update offers use `arches.{arch}` only. Web + updater read those entries; upload CI merges partial releases by arch into this map.

## Update manifest (GitHub Releases)

**Endpoint:** `GET https://api.github.com/repos/{owner}/{repo}/releases?per_page=100`

Config: `githubRepo = 'mGhassen/Forja'` in `apps/forja/lib/shared/services/app_updater_service.dart`.

**Release tag:** `v1.2.3` (leading `v` stripped for compare).

Latest install target = newest non-draft, non-prerelease release. Asset **names** come from that GitHub release; download URLs are rewritten to the release CDN:

`{RELEASE_CDN_URL}/latest/{filename}`

(Versioned `{RELEASE_CDN_URL}/v{version}/{filename}` remains available as a fallback.)

**Required assets per platform:**

| Platform | Asset naming (convention) | Install path |
|----------|---------------------------|--------------|
| Android | `*Forja*.apk` or `*.apk` | In-app OTA install |
| Windows | `*windows*.exe` | Download + launch installer |
| Linux | `*.AppImage` or `*.deb` | Download + chmod + exec |
| macOS | `Forja-*-macos-arm64.dmg` / `Forja-*-macos-x86_64.dmg` (prefer host arch) | Download to Downloads + `open` DMG |
| iOS | — | Link to releases / TestFlight only |

**Release body:** Markdown from every stable release newer than the installed version is aggregated (newest first) into the dialog. Empty bodies and GitHub auto `Full Changelog:` stubs are skipped. When more than one version contributes notes, each block is headed with `# X.Y.Z`.

## Version comparison

Semver triple: `major.minor.patch` — numeric compare per segment.

Build number (`1.0.0+42` from pubspec) ignored for GitHub tag compare; optional future use for same-tag rebuilds.

## User flows

### Auto-check (startup)

1. App launches → `DesktopStartupGate` → `AppUpdaterService.checkForUpdates()` (before account entry and before splash)
2. If newer version → non-dismissible-on-first-show dialog (`UpdateDialog`); user dismisses before auth/splash continues
3. User: **Update Now** | **Later**
4. Historical: v1.0 also checked from `MainScreen` after splash dismiss (R15-A07) — superseded by R15-A39 for cold start

### Auto-check (in-session — R15-A08 / R15-A09)

1. After the shell opens, `AppUpdateAutoCheck` runs in the background (first tick after paint, then every 1h, and on app resume)
2. Network checks are throttled (`update_last_check_at`); silent on failure
3. If a player is open, the prompt waits until playback chrome clears
4. **Later** / closing the dialog sets `update_dismissed_version` — that version is not auto-prompted again until a newer release ships
5. Manual **Settings → About → Check for updates** still always shows when an update exists

Throttle: do not re-prompt the same dismissed version (v1.1 — persist in `SettingsService`).

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

`.github/workflows/build.yml` is manual only (optional smoke builds, artifacts only). `.github/workflows/release.yml` (**Release Forja**) — new version or existing tag; publish GitHub Release **and** upload the same flattened installers to Cloudflare R2 via `scripts/upload_release_to_r2.py`:

```
Forja-1.2.3-android-tv-arm64.apk
Forja-1.2.3-android-tv-armeabi-v7a.apk
Forja-1.2.3-windows-setup.exe
Forja-1.2.3-macos-arm64.dmg
Forja-1.2.3-macos-x86_64.dmg
Forja-1.2.3-linux-x86_64.AppImage
```

R2 path: `v{version}/{filename}` in bucket `releases`. Requires repo secrets `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and public `RELEASE_CDN_URL`. After each upload, CI keeps only the newest 3 version prefixes and deletes older installer objects.

Release workflow supports per-platform toggles (macOS, Windows, Linux, Android TV). Untagged commits: `.github/workflows/backfill-tags.yml`. Android TV requires signing secrets (`FORJA_KEYSTORE_*`).

GitHub Release keeps tags/notes (+ optional backup assets). App updater matches by filename patterns and downloads from the release CDN.

## Future (v1.2+)

- Custom update endpoint (JSON manifest) for mirrors / China
- Beta channel: `GET /repos/{repo}/releases` filter `prerelease`
- Mandatory update flag in manifest for critical security fixes
- macOS Sparkle framework alternative for signed delta updates


## Related

RFC-011 (v1.0 MVP), CI in `.github/workflows/build.yml`, installer `installer/windows/setup.iss`
