# App updates

> Check for new releases manually or on launch.

## What it is

Forja can check GitHub Releases for newer builds when the app starts and lets you check manually from Settings. On Android, in-app update install may be offered when a new APK is available.

## How to open it

**Settings → About** — manual check. Auto-check runs after the splash screen finishes on launch.

## What you can do

- Tap **Check for updates** in Settings
- Accept update prompt when a newer version exists
- Install updates on Android through the update dialog when supported
- See the app version at the bottom of About

## Tips

- Published releases: `./scripts/release_ci.sh` or `melos run release` — searchable tag list locally (needs `gh` CLI)
- Or in GitHub: Actions → **Release Forja** → **New version** or **Existing tag**; pick platforms
- Tag backfill: Actions → **Backfill version tags** (requires repo secret `BACKFILL_GITHUB_TOKEN` — fine-grained PAT with Contents + Workflows write on this repo)
- Android TV releases publish two APKs: `Forja-{version}-android-tv-arm64.apk` and `Forja-{version}-android-tv-armeabi-v7a.apk`; the in-app updater picks the matching ABI
- Optional smoke build: Actions → **Build Forja** (workflow artifacts only, no release)
- Download latest builds from [GitHub Releases](https://github.com/mGhassen/Forja/releases) if in-app update fails
- See [Platforms](../getting-started/platforms.md) for per-OS install formats

## Related

- [Platforms](../getting-started/platforms.md)
