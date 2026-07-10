# Platforms

> Forja runs on desktop and mobile — one app, your whole library everywhere.

## What it is

Forja is a cross-platform Flutter app with a Rust engine under the hood. The same features are available on all supported platforms, with small differences for mobile (PiP, immersive nav) vs desktop (window chrome, keyboard shortcuts).

## Supported platforms

| Platform | Format |
|----------|--------|
| **Android** | APK |
| **iOS** | App Store / sideload |
| **Windows** | Installer |
| **Linux** | AppImage |
| **macOS** | DMG |

Download builds from [GitHub Releases](https://github.com/mGhassen/Forja/releases). Published installers ship via manual **Release Forja** workflow (Actions → Release Forja).

## What you can do

- Install on any supported device and use the same tabs and settings model
- Export settings on one device and import on another ([Backup & restore](../settings/backup-restore.md))
- Use external players where the platform allows (VLC, mpv, MX Player, etc.)

## Platform notes

- **Android:** Picture-in-picture, background music playback, immersive navigation
- **Android TV:** Leanback launcher entry, nav-rail shell (`ShellHost` TV profile), D-pad focus on in-scope tabs, built-in player remote keys (play/pause, seek ±10s, Back)
- **macOS:** Hidden title bar with draggable window chrome
- **Windows / Linux:** Custom window caption on desktop

## Android TV development

Test TV layout on a phone or emulator (not leanback proof):

```bash
flutter run -d <android-device> --dart-define=FORJA_ANDROID_TV=true
```

Forces TV profile and TV first-run nav defaults. Real leanback launcher smoke is tracked in [issue 025](../../issues/025-[open]-android-tv-leanback-smoke-unverified.md).

## Tips

- The Rust engine starts automatically at launch — no separate install step
- Auto-update checks run on launch; Android can install updates in-app

## Related

- [App updates](../settings/app-updates.md)
- [External players](../playback/external-players.md)
