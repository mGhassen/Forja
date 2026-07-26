#!/usr/bin/env bash
# Reclaim disk on GitHub-hosted Ubuntu runners before large Android/Rust builds.
# ubuntu-latest only guarantees ~14 GB free; Flutter + NDK + Gradle often exceed that.
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ci_free_disk_linux.sh: skipping (not Linux)"
  exit 0
fi

echo "==> Disk before cleanup"
df -h /

# Large preinstalled toolchains unused by Forja Android/Rust CI.
sudo rm -rf /usr/share/dotnet || true
sudo rm -rf /usr/local/lib/android/sdk/ndk || true
sudo rm -rf /usr/local/lib/android/sdk/ndk-bundle || true
sudo rm -rf /opt/hostedtoolcache/CodeQL || true
sudo rm -rf /usr/local/.ghcup || true
sudo rm -rf /opt/ghc || true
sudo rm -rf /usr/local/share/boost || true
sudo rm -rf /usr/share/swift || true
sudo rm -rf /usr/local/share/powershell || true

# Docker images on the image are unused for our Android APK job.
if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes || true
fi

sudo apt-get clean || true
sudo rm -rf /var/lib/apt/lists/* || true

echo "==> Disk after cleanup"
df -h /
