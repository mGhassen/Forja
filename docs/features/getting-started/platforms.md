# Platforms

> Forja runs on desktop and mobile — one app, your whole library everywhere.

## What it is

Forja is a cross-platform Flutter app with a Rust engine under the hood. The same features are available on all supported platforms, with small differences for mobile (PiP, immersive nav) vs desktop (window chrome, keyboard shortcuts).

## Supported platforms

| Platform | Format |
|----------|--------|
| **Android** | APK |
| **Android TV** | APK (arm64 + armeabi-v7a) |
| **iOS** | App Store / sideload |
| **Windows** | Installer |
| **Linux** | AppImage |
| **macOS** | DMG |

Download builds from [GitHub Releases](https://github.com/mGhassen/Forja/releases). Published installers ship via manual **Release Forja** workflow (Actions → Release Forja). Toggle which platforms to build (macOS, Windows, Linux, Android TV) when dispatching the workflow.

## What you can do

- Install on any supported device and use the same tabs and settings model
- Export settings on one device and import on another ([Backup & restore](../settings/backup-restore.md))
- Use external players where the platform allows (VLC, mpv, MX Player, etc.)

## Platform notes

- **Android:** Picture-in-picture, background music playback, immersive navigation
- **Android TV:** Leanback launcher entry, nav-rail shell (`ShellHost` TV profile), D-pad focus on in-scope tabs, built-in player remote keys (play/pause, seek ±10s, Back). First-run **Play sources** default to **Webstreaming** only (green hero **Play**); enable Direct torrent or Stremio under **Settings → Playback** for the **Sources** panel. WebViews on TV disable Chromium GPU at process start (`ForjaApplication`) and use software compositing in Dart — trailer and live embeds may be slower than on phone/desktop.
- **macOS:** Hidden title bar with draggable window chrome
- **Windows / Linux:** Custom window caption on desktop

## Android TV development

### Leanback AVD (launcher smoke)

1. Android Studio → **Device Manager** → **Create device** → **TV** category → e.g. **1080p Android TV (Google APIs)**.
2. System image: API 34+ with **Google APIs** (not Google Play if unavailable for TV).
3. Confirm `LEANBACK_LAUNCHER` in `apps/forja/android/app/src/main/AndroidManifest.xml`.
4. Run on the TV AVD **without** dart-define:

```bash
flutter emulators --launch <tv_avd_id>
flutter run -d <tv_avd_id>
```

Leanback launcher + full D-pad matrix: [issue 025](../../issues/025-[open]-android-tv-leanback-smoke-unverified.md) (`I25-M01`–`M08`). WebView crash workaround: [issue 031](../../issues/031-[workaround]-android-tv-webview-gles-crash.md) (`I31-A01` smoke on TV AVD).

### Phone / generic emulator (layout only)

Test TV layout on a phone or emulator (not leanback proof):

```bash
flutter run -d <android-device> --dart-define=FORJA_ANDROID_TV=true
```

Forces TV profile and TV first-run nav defaults via `PlatformChannel` + `PlatformInfo`. Does **not** replace leanback launcher smoke.

## Tips

- The Rust engine starts automatically at launch — no separate install step
- Auto-update checks run on launch; Android can install updates in-app

## Related

- [App updates](../settings/app-updates.md)
- [External players](../playback/external-players.md)
