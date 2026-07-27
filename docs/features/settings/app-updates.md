# App updates

> Check for new releases manually or on launch.

## What it is

Forja checks for newer builds from the release CDN on Cloudflare R2 (`latest/manifest.json` — **per-platform** version and installer filenames). A release that only ships macOS updates the macOS entry and leaves Windows/Linux/Android TV alone. Installer files download from the versioned path (`v{version}/{filename}`). The update dialog loads release notes from the same CDN (`changelog/index.json` + `changelog/{version}.md` for every version since yours, up to 16), with a left version list and a link to the full web changelog. Those note files stay on the CDN permanently (unlike installers, which keep only the newest few versions, plus any version still serving as a platform’s latest). Android can install the APK in-app; Windows, Linux, and macOS download the installer (`.exe` / AppImage / `.dmg`) with progress and open it when ready.

## How to open it

**Settings → About** — manual check. Auto-check runs on launch **before** desktop sign-in (and before the splash), so an update prompt is not delayed until after authentication or Home.

## What you can do

- Tap **Check for updates** in Settings — if a newer build exists, the update
  dialog opens; if you are already on the latest, you get a success toast; if
  the check fails (no network, bad manifest, missing CDN config), you get an
  **error** toast (Forja does not claim you are up to date when the check failed)
- Toggle **Crash reporting** under **Privacy** (off by default) to send anonymized crash reports via Sentry when this build includes a DSN — stream URLs, magnets, and tokens are stripped
- Toggle **Product analytics** under **Privacy** (off by default) to send anonymous usage events via PostHog with masked session replay. Screen names follow real tabs (`home`, `anime`, …) and routes (`media_details`, `player`) — not Flutter’s `/` root.
- The **web portal** also sends anonymous PostHog pageviews (and masked session replay) when the deploy has a PostHog key — it does not use the in-app About toggle
- On **macOS**, toggle **Store secrets in Keychain** under **Privacy** (off by default — local app file). Turning it on shows an explain dialog first; macOS may then ask for your password once.
- Accept update prompt when a newer version exists
- Browse **What’s new** per version (left list, newest first, max 16 since your build)
- Open **See full changelog on the web** for the complete history on the portal
- Install updates on Android through the update dialog when supported
- On macOS, download the `.dmg`, then choose **Install and close Forja** to open it and quit the app, or **Skip for now** to keep using Forja; if Downloads is unavailable, the app falls back to its own updates folder
- On Windows, download the `.exe`, then choose **Install and close Forja** to launch it and quit the app, or **Skip for now**
- On Linux, download the installer with progress from the same dialog
- During a desktop download, choose **Continue in background** to return to Forja; a sticky progress toast stays visible (you can close it) and an **Install** toast appears when it finishes. Progress is hidden while a video player is open.
- Checking for the same update again reuses a completed installer already on disk instead of downloading it again
- If a Windows or macOS download fails, use **Open download URL** in the error message to retry in your browser
- **Settings → Data & backup → Downloaded updates** removes saved installer files from in-app update
- See the app version at the bottom of About

## Tips

- Crash reporting and product analytics stay off until you enable them; local builds without `SENTRY_DSN` / `POSTHOG_API_KEY` keep the toggles but send nothing
- Enable **Record user sessions** in PostHog project settings for session replay
- Web portal analytics needs its own `VITE_POSTHOG_KEY` (separate PostHog project from the app); empty key means the site never loads PostHog
- Published releases (CI): `./scripts/release_ci.sh` or `melos run release` — searchable tag list locally (needs `gh` CLI)
- After a **New version** release on forjahq Actions: `./scripts/release_local.sh sync-from` pulls the `chore: release` commit + tag back to origin (mGhassen)
- Local release (macOS DMG → GitHub + R2; Windows via Parallels when `FORJA_PRL_VM` is set): `./scripts/release_local.sh` or `melos run release:local`
- First-time Windows VM toolchain (inside the guest, elevated PowerShell): `.\scripts\setup_windows_vm.ps1` — or from Mac: `./scripts/release_local.sh setup-windows`
- Or in GitHub: Actions → **Release Forja** → **New version** or **Existing tag**; each arch is its own checkbox (macOS arm64, macOS Intel, Android TV arm64, Android TV v7a)
- Tag backfill: Actions → **Backfill version tags** (requires repo secret `BACKFILL_GITHUB_TOKEN` — fine-grained PAT with Contents + Workflows write on this repo)
- Android TV releases publish two APKs: `Forja-{version}-android-tv-arm64.apk` and `Forja-{version}-android-tv-armeabi-v7a.apk`; the in-app updater picks the matching ABI. On the [web download page](https://forjahq.xyz/download), each APK has its own download button.
- macOS releases publish `Forja-{version}-macos-arm64.dmg` and `Forja-{version}-macos-x86_64.dmg`; the updater picks the host arch
- Optional smoke build: Actions → **Build Forja** (workflow artifacts only, no release)
- Download latest builds from the [web download page](https://forjahq.xyz/download) if in-app update fails or no platform asset is attached
- See [Platforms](../getting-started/platforms.md) for per-OS install formats

## Related

- [Platforms](../getting-started/platforms.md)
- [Cloud sync](cloud-sync.md)
