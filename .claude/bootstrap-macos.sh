#!/usr/bin/env bash
# Forja dev bootstrap for macOS (Apple Silicon). Installs Flutter, Rust, Android
# command-line tools + emulator + NDK, JDK 21, CocoaPods. Idempotent. Logs to stdout.
set -uo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
step() { printf '\n==== %s  (%s)\n' "$1" "$(date +%H:%M:%S)"; }

step "brew formulae/casks"
brew list --cask flutter >/dev/null 2>&1 || brew install --cask flutter
brew list rustup >/dev/null 2>&1 || brew install rustup
brew list cmake >/dev/null 2>&1 || brew install cmake; brew list bash >/dev/null 2>&1 || brew install bash
brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools
brew list cocoapods >/dev/null 2>&1 || brew install cocoapods
brew list mas >/dev/null 2>&1 || brew install mas

step "rust toolchain"
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
if ! rustup show active-toolchain >/dev/null 2>&1; then
  rustup-init -y --no-modify-path --default-toolchain stable || rustup default stable
fi
rustup default stable
rustup target add aarch64-linux-android armv7-linux-androideabi
rustup component add rustfmt clippy
cargo --version; rustc --version

step "android sdk"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses >/dev/null 2>&1 || true
"$SDKM" --install \
  "platform-tools" \
  "platforms;android-35" "platforms;android-36" "build-tools;36.0.0" \
  "build-tools;35.0.0" \
  "emulator" \
  "ndk;26.3.11579264" \
  "cmake;3.22.1" \
  "system-images;android-35;google_apis;arm64-v8a" \
  "system-images;android-34;android-tv;arm64-v8a"
yes | "$SDKM" --licenses >/dev/null 2>&1 || true

step "avds"
AVDM="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
"$AVDM" list avd | grep -q 'Name: forja_phone' || echo no | "$AVDM" create avd -n forja_phone -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7
"$AVDM" list avd | grep -q 'Name: forja_tv'    || echo no | "$AVDM" create avd -n forja_tv    -k "system-images;android-34;android-tv;arm64-v8a" -d tv_1080p
for a in forja_phone forja_tv; do
  # avdmanager defaults: host keyboard off (no arrow keys / D-pad from the Mac keyboard), software GPU (slow), 2 GB RAM.
  sed -i '' -e 's/^hw\.keyboard=no/hw.keyboard=yes/' -e 's/^hw\.dPad=no/hw.dPad=yes/' \
    -e 's/^hw\.gpu\.enabled=no/hw.gpu.enabled=yes/' -e 's/^hw\.gpu\.mode=auto/hw.gpu.mode=host/' \
    -e 's/^hw\.ramSize=.*/hw.ramSize=3072/' "$HOME/.android/avd/$a.avd/config.ini"
done
"$AVDM" list avd | grep -E 'Name:|Path:'

step "flutter config"
export PATH="/opt/homebrew/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter config --android-sdk "$ANDROID_HOME"
flutter config --jdk-dir "$JAVA_HOME"
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
flutter doctor -v

step "done"
