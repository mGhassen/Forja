# App updates

> Check for new releases manually or on launch.

## What it is

Forja can check GitHub Releases for newer builds when the app starts and lets you check manually from Settings. On Android, in-app update install may be offered when a new APK is available.

## How to open it

**Settings → App Updates** — manual check. Auto-check runs on launch from the main shell.

## What you can do

- Tap **Check for updates** in Settings
- Accept update prompt when a newer version exists
- Install updates on Android through the update dialog when supported

## Tips

- Published releases: `./scripts/release_ci.sh` or `melos run release` — lists tags, backfills locally, triggers **Release Forja** on GitHub (needs `gh` CLI)
- Or in GitHub: Actions → **Release Forja** → choose **bump_new**, **latest_tag**, or **specific_tag**; pick platforms
- Tag backfill: `./scripts/release_ci.sh backfill` (local) or Actions → **Backfill version tags**
- Android TV releases publish two APKs: `Forja-{version}-android-tv-arm64.apk` and `Forja-{version}-android-tv-armeabi-v7a.apk`; the in-app updater picks the matching ABI
- Optional smoke build: Actions → **Build Forja** (workflow artifacts only, no release)
- Download latest builds from [GitHub Releases](https://github.com/mGhassen/Forja/releases) if in-app update fails
- See [Platforms](../getting-started/platforms.md) for per-OS install formats

## Related

- [Platforms](../getting-started/platforms.md)
