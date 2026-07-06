#!/bin/sh
# Cross-compile libffi for iOS before embedding (release/profile only).
set -e

if [ "${BUILD_RUST_IOS:-1}" = "0" ]; then
  exit 0
fi

case "${CONFIGURATION:-Debug}" in
  Release|Profile) ;;
  *)
    exit 0
    ;;
esac

REPO="$(cd "${SRCROOT}/../../.." && pwd)"
bash "${REPO}/scripts/build_rust_mobile.sh" ios
