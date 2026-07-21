#!/usr/bin/env bash
set -euo pipefail

# Copy MSVC CRT DLLs (msvcp140, vcruntime140, …) next to forja.exe so clean
# Windows installs do not fail with "MSVCP140.dll was not found".
# Per-user Inno (PrivilegesRequired=lowest) cannot reliably install the system
# VC++ redistributable without elevation — app-local CRT is the supported path.
#
# Usage: bundle_windows_msvc_crt.sh
# Requires: Visual Studio / Build Tools with VC++ redist on the machine (CI).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="$ROOT/apps/forja/build/windows/x64/runner/Release"
PS1="$ROOT/scripts/bundle_windows_msvc_crt.ps1"

if [[ ! -d "$RELEASE" ]]; then
  echo "error: missing Windows release dir: $RELEASE" >&2
  echo "run flutter build windows --release first" >&2
  exit 1
fi

if command -v cygpath >/dev/null 2>&1; then
  RELEASE_WIN="$(cygpath -w "$RELEASE")"
  PS1_WIN="$(cygpath -w "$PS1")"
else
  RELEASE_WIN="$RELEASE"
  PS1_WIN="$PS1"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1_WIN" -ReleaseDir "$RELEASE_WIN"
echo "MSVC CRT bundled into $RELEASE"
