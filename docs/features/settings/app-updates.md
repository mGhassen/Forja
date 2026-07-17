# App updates

> Check for new releases manually or on launch.

## What it is

Forja can check for newer builds when the app starts and lets you check manually from Settings. Updates come from GitHub Releases. Android can install the APK in-app; Windows, Linux, and macOS download the installer (`.exe` / AppImage / `.dmg`) with progress and open it when ready.

## How to open it

**Settings → About** — manual check. Auto-check runs after the splash screen finishes on launch.

## What you can do

- Tap **Check for updates** in Settings
- Accept update prompt when a newer version exists
- Read **What’s new** for every release since your installed version (not only the latest tag) — empty or auto-generated GitHub stubs are skipped
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

- Published releases: `./scripts/release_ci.sh` or `melos run release` — searchable tag list locally (needs `gh` CLI)
- Or in GitHub: Actions → **Release Forja** → **New version** or **Existing tag**; pick platforms
- Tag backfill: Actions → **Backfill version tags** (requires repo secret `BACKFILL_GITHUB_TOKEN` — fine-grained PAT with Contents + Workflows write on this repo)
- Android TV releases publish two APKs: `Forja-{version}-android-tv-arm64.apk` and `Forja-{version}-android-tv-armeabi-v7a.apk`; the in-app updater picks the matching ABI
- macOS releases publish `Forja-{version}-macos-arm64.dmg`; the updater prefers the host arch and falls back to any macOS `.dmg`
- Optional smoke build: Actions → **Build Forja** (workflow artifacts only, no release)
- Download latest builds from [GitHub Releases](https://github.com/mGhassen/Forja/releases) if in-app update fails or no platform asset is attached
- See [Platforms](../getting-started/platforms.md) for per-OS install formats

## Related

- [Platforms](../getting-started/platforms.md)
- [Cloud sync](cloud-sync.md)
