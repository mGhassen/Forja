---
name: forja-run
description: >-
  Launch Forja locally for manual testing: build the Rust engine, pick a target
  (macOS desktop, Android phone emulator, Android TV emulator, Chrome for the
  web portal), start it with the right dart-defines, and read the boot log.
  Use when the user says run the app, launch, start the emulator, test it,
  flutter run, or asks how to use Forja locally.
argument-hint: "[macos | phone | tv | web] [--release]"
allowed-tools: Bash, Read, Grep, Glob
---

# /forja-run $ARGUMENTS

Environment right now:

!`for t in flutter dart cargo adb emulator xcodebuild; do printf '%s=%s ' "$t" "$(command -v $t >/dev/null 2>&1 && echo yes || echo MISSING)"; done; echo; [ -f .env ] && echo ".env present" || echo ".env MISSING (cp .env.example .env)"; ls crates/target/release/libffi.dylib apps/forja/android/app/src/main/jniLibs/arm64-v8a/libffi.so 2>/dev/null || echo "no prebuilt libffi yet"`

Devices Flutter sees:

!`command -v flutter >/dev/null 2>&1 && flutter devices 2>/dev/null | tail -n +1 | head -12 || echo "flutter not on PATH"`

## Toolchain paths (Homebrew install, 2026-10-20)

```bash
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"   # bash 5 + cargo first: Gradle's buildRustAndroid task needs both
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/26.3.11579264
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

Gotchas learned on this machine: `scripts/build_rust_mobile.sh` breaks on macOS bash 3.2 (`MOBILE_FLAGS[@]: unbound variable`) — run it with Homebrew bash 5. `aws-lc-sys` needs `cmake` (brew). `apps/forja/android/gradle.properties` has `buildRust=true`, so every Gradle build re-runs the Rust script (fast when nothing changed) and fails with exit 127 if `cargo`/`bash` are not on the PATH Flutter was started with. Flutter 3.47 wants `platforms;android-36` + `build-tools;36.0.0`. Xcode.app is not installed (CLT only): the macOS target cannot build until the user installs Xcode and runs `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch`.

## Targets

| Target | Needs | Commands |
|--------|-------|----------|
| **macos** (desktop, primary dev target) | full Xcode.app (not just CLT), CocoaPods | `./scripts/build_rust.sh` once (also after `.env` changes), then `cd apps/forja && flutter pub get && flutter run -d macos --dart-define-from-file=../../.env` |
| **phone** (Android emulator `forja_phone`) | Android SDK + NDK, emulator running | `emulator -avd forja_phone -netdelay none -netspeed full &` · wait for `adb wait-for-device` · `cd apps/forja && BUILD_RUST_ANDROID=1 flutter run -d emulator-5554 --dart-define-from-file=../../.env` |
| **tv** (Android TV emulator `forja_tv`) | same | `emulator -avd forja_tv &` · `cd apps/forja && BUILD_RUST_ANDROID=1 flutter run -d <id from flutter devices> --dart-define-from-file=../../.env` · D-pad = keyboard arrows + Enter, Back = Esc |
| **web** (account portal, not the player) | pnpm | `cd apps/web && pnpm install && pnpm dev` → http://127.0.0.1:3000 |

Emulator performance and input (fixed in `~/.android/avd/*/config.ini` on 2026-10-20): `hw.keyboard=yes` so the Mac keyboard reaches the guest (arrows = D-pad, Enter = OK, Esc = Back on `forja_tv`), `hw.dPad=yes`, `hw.gpu.enabled=yes` + `hw.gpu.mode=host` (software GPU is unusably slow), `hw.ramSize=3072`. Launch with `-gpu host`. Run one emulator at a time on a 32 GB Mac, kill Gradle daemons between builds (`pkill -f GradleDaemon`), and test UI speed with `flutter run --profile`: a debug build is JIT and several times slower than what users get.

`BUILD_RUST_ANDROID=1` makes Gradle run `scripts/build_rust_mobile.sh android` (first time ~10–20 min: librqbit, aws-lc). After that, drop the flag unless `crates/` changed. Two emulators at once: the first is `emulator-5554`, the second `emulator-5556`.

## Boot log checks

- `[Engine] Rust engine v3.1.x` → engine loaded. `Rust engine NOT loaded` → rebuild Rust or set `RUST_LIB`; `RUST_STRICT=1` fails fast.
- `[Supabase] Not configured` is expected without `SUPABASE_URL`; accounts/sync are off, everything else works.
- TMDB works without a key: `crates/tmdb` defaults to the `tmdb.forjahq.xyz` gateway.

## Hot reload / tools

`r` reload, `R` restart, `q` quit in the `flutter run` terminal. With the `dart` MCP server connected, the running app's widget tree and screenshots are available through the Dart tooling daemon.

## Install packs on an emulator without typing (deep link)

`adb shell input text` mangles long URLs; the app registers `forja://install`, so send one batch link instead (quote it for the device shell: `&` must not reach `sh`):

```bash
LINK="$(python3 -I -c '
import json, urllib.parse
B="https://raw.githubusercontent.com/mGhassen/forja-packs/main"
packs=[("hubs/home","Home"),("providers","Providers"),("hubs/anime","Anime"),("hubs/asian_drama","Asian Drama"),("hubs/live_sports","Live Sports hub"),("livesports","Live Sports"),("hubs/iptv","IPTV"),("torrent","Torrent"),("hubs/my_list","My List")]
print("forja://install?batch=1&packs="+urllib.parse.quote(json.dumps([{"m":f"{B}/{p}/manifest.json","n":n} for p,n in packs],separators=(",",":")),safe=""))')"
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d "'$LINK'" com.forjahq.app.dev
```

The app opens Settings → Forja Packs → "Install packs"; tap **Select all** then **Install 9 packs**. Single pack: `forja://install?manifest=<url-encoded manifest.json URL>`. Verified 2026-10-20 on both AVDs: Home hub renders TMDB rows through the forjahq gateway with no API key.

## First-use inside the app

Forja ships as an empty shell: content comes from packs. Settings → Sources → Forja: paste pack manifest URLs from https://github.com/mGhassen/forja-packs (hubs: home, anime, asian_drama, iptv, live_sports; providers; torrent; debrid), or clone that repo next to this one and set `FORJA_PACKS_ROOT` in `.env` for debug builds. IPTV needs your own M3U/Xtream/Stalker source; torrents need Real-Debrid/TorBox or direct playback.
