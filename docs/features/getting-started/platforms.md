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
| **macOS** | DMG (Apple Silicon arm64 + Intel x86_64) |

Download builds from the [web download page](https://forjahq.xyz/download). The site reads `latest/manifest.json` on the Cloudflare R2 CDN (per-platform latest — a macOS-only release keeps Windows/Linux/Android TV installers) and serves installer links under `cdn.forjahq.xyz/latest/…`. Each platform row shows that platform’s version and its release notes, with a platform icon. The page detects your OS **and** CPU architecture (Apple Silicon vs Intel on Mac, ARM vs x86 when the filename encodes it) and puts the matching installer first — the nav **Download** button uses that build. Download buttons still name the architecture when the installer filename includes one (e.g. macOS **Apple Silicon** / **Intel**, Android TV **ARM64** / **ARMv7**); when a platform ships more than one build, the detail panel shows a button per architecture. On **Android TV**, when the release includes AFTVnews [Downloader](https://www.aftvnews.com/downloader/) short codes in the R2 manifest, the detail panel shows the numeric code next to each APK so you can enter it in Downloader on the TV instead of typing the URL. On Windows and macOS detail panes, a **Stuck opening Forja?** card links to that platform’s photo guide (SmartScreen or Gatekeeper). Published installers ship via **Release Forja** in Actions or `scripts/release_local.sh` (R2 upload for binaries + notes under `changelog/`; local Android TV publish prompts for Downloader codes).

## What you can do

- Install on any supported device and use the same tabs and settings model
- Export settings on one device and import on another ([Backup & restore](../settings/backup-restore.md))
- Use external players where the platform allows (VLC, mpv, MX Player, etc.) — not offered from the in-player **Player** menu on **Android TV** (ExoPlayer / MediaKit only)

## Platform notes

- **Android:** Picture-in-picture, background music playback, immersive navigation. **Android 7.0:** the app embeds Let's Encrypt (ISRG) root certificates so TMDB posters load on Home and Asian Drama (KissKH covers that use the TMDB media CDN) — older system trust stores no longer trust those hosts after the 2024 cross-sign expiry.
- **Android TV:** Leanback launcher entry (home-row banner and square Apps icon both use the green Forja wordmark — not the F monogram), nav-rail shell (`ShellHost` TV profile), D-pad focus on in-scope tabs, built-in player remote keys (play/pause, OK-to-scrub progress, Back). The shell keeps fewer tabs mounted than desktop (max three) and, when any fullscreen player opens, unloads other shell tabs and clears poster/image memory so live IPTV and movies get max decode resources (the screen under the player stays mounted). Opening details, search overlays, and players is an **instant cut** (no slide) so weak Android 7 sets do not stutter while the new screen loads. Catalog cards and the nav rail **snap** focus chrome (no 200ms scale/color tweens) so D-pad browsing stays responsive. Left to the nav rail then right restores the last focused control on the page; Back pops overlays/routes, then focuses the nav — on the nav rail, Back twice (within ~2s) exits to the launcher and clears app memory for a cold next open. Remote **Exit** (not Back) also needs two presses to quit from anywhere. **Play sources** are **Webstreaming** only — Direct torrent, Stremio, and Nuvio stay hidden for every account (including admins), and Settings also hides the **Sources** and **Debrid** categories; cloud sync may still store those prefs for other devices without enabling them on TV. **Stream play** uses Rust providers (WebStreamr, VSEmbed, 111477) — headless WebView sniffers, including VidSrc, are disabled on TV. **MediaKit** movie/series playback disables Flutter Impeller on TV (Skia) so video is not black-with-audio — do not force Impeller on in the AndroidManifest. YouTube trailers (hero + fullscreen player) keep WebView hardware acceleration so video is not a white surface. Embedded WebViews on **emulators** still need Chromium software GPU — use [`scripts/atv-run.sh`](../../scripts/atv-run.sh). **Account:** link with a code or QR via the portal `/connect` ([Link Android TV](../accounts/tv-connect.md)), or continue as guest.
- **macOS:** Requires **macOS 10.15 Catalina or newer** (Apple Silicon and Intel). The app does **not** require Ventura 13.5 — native passkeys (when enabled) need 13.5+, but older Macs still run Forja with password / web login. Hidden title bar with draggable window chrome; in-app updates download the DMG and open it. The DMG (**Install Forja**) is a drag-to-Applications window with a light matrix-grid background and large icons — drag **Forja** onto **Applications**. Local `flutter run -d macos` (Debug/Release) codesigns embedded media_kit frameworks in the Xcode build so dyld can load them; packaged DMGs still use `scripts/codesign_macos_adhoc.sh` after `scripts/build_macos.sh`. Account secrets (login, Trakt, Simkl, debrid, IPTV passwords, …) use a **local app file by default** — no Keychain password prompt at launch. Optional: **Settings → About → Privacy → Store secrets in Keychain** (Forja explains first; macOS may then ask once and may mention `flutter_secure_storage_service`).
- **Windows / Linux:** Custom window caption (min / max / close) on the main shell and on pre-shell screens (sign-in, Who’s watching, update gate); in-app updates download the installer with progress
- **Windows:** The installer ships the MSVC runtime DLLs (`msvcp140`, `vcruntime140`, …) next to `forja.exe`, so clean PCs without the Visual C++ Redistributable still launch

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

Leanback launcher + full D-pad matrix: [issue 025](../../issues/025-[open]-android-tv-leanback-smoke-unverified.md) (`I25-M01`–`M08`). WebView GLES workaround: [issue 031](../../issues/031-[workaround]-android-tv-webview-gles-crash.md). Prefer **`scripts/atv-run.sh`** on emulator (sets `--disable-gpu` for embedded WebViews):

```bash
./scripts/atv-run.sh emulator-5554
```

Stream play on TV uses WebStreamr/VSEmbed — configure at least one in Settings → Stream providers.

### Phone / generic emulator (layout only)

Test TV layout on a phone or emulator (not leanback proof):

```bash
flutter run -d <android-device> --dart-define=FORJA_ANDROID_TV=true
```

Forces TV profile and TV first-run nav defaults via `PlatformChannel` + `PlatformInfo`. Does **not** replace leanback launcher smoke.

## Tips

- The Rust engine starts automatically at launch — no separate install step
- Auto-update checks run on launch and again while the app stays open; Android can install updates in-app

## Related

- [App updates](../settings/app-updates.md)
- [External players](../playback/external-players.md)
