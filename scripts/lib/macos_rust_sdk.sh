#!/usr/bin/env bash
# Select a macOS SDK that can link native Rust deps (aws-lc-sys / ring / cc-rs).
#
# Apple CLT MacOSX27.0.sdk ships TBD targets `arm64e.x1-*` that the bundled
# `ld` rejects ("unknown architecture"). Prefer 26.5 (or any SDK whose
# libSystem.B.tbd does not mention arm64e.x1) until the linker catches up.
#
# No-op on non-Darwin. Honors an already-set SDKROOT.

forja_macos_rust_sdk() {
  [[ "$(uname -s)" == Darwin ]] || return 0
  [[ -n "${SDKROOT:-}" && -d "${SDKROOT}" ]] && return 0

  local sdk tbd candidates=(
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
    /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  )

  for sdk in "${candidates[@]}"; do
    [[ -d "$sdk" ]] || continue
    tbd="$sdk/usr/lib/libSystem.B.tbd"
    if [[ -f "$tbd" ]] && grep -q 'arm64e\.x1' "$tbd" 2>/dev/null; then
      continue
    fi
    export SDKROOT="$sdk"
    return 0
  done

  # Last resort: default CLT SDK even if broken — surface the real linker error.
  if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
  fi
}

forja_macos_rust_sdk
