#!/bin/sh
# Sign every embedded framework/dylib so dyld accepts them under `flutter run`.
# media_kit XCFrameworks (Ass, Mpv, …) ship unsigned; CocoaPods only signs them
# when CODE_SIGNING_ALLOWED != NO. CI / build_macos.sh often disables signing,
# and a signed main binary + unsigned Ass.framework aborts at launch (SIGABRT/dyld).
set -e

DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
APP="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"

if [ ! -d "$DEST" ]; then
  echo "note: no Frameworks folder at $DEST — skip"
  exit 0
fi

# Prefer the active Xcode identity so nested code matches the app signature.
# Fall back to ad-hoc when signing is disabled or identity is unset.
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] || [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
  IDENTITY="-"
fi

echo "Signing embedded frameworks with identity: ${IDENTITY}"

sign_macho() {
  _path="$1"
  if [ ! -f "$_path" ] && [ ! -d "$_path" ]; then
    return 0
  fi
  if [ -f "$_path" ]; then
    case "$(file -b "$_path" 2>/dev/null || true)" in
      *Mach-O*) ;;
      *) return 0 ;;
    esac
  fi
  codesign --force --sign "$IDENTITY" --timestamp=none "$_path" || true
}

# Sign versioned framework executables (…/Ass.framework/Versions/A/Ass).
find "$DEST" -type f ! -name "*.plist" ! -name "*.json" ! -name "*.txt" \
  ! -name "*.md" ! -name "*.h" ! -name "*.modulemap" \
  -path "*.framework/Versions/*/*" | while IFS= read -r bin; do
  case "$bin" in
    */Resources/*) continue ;;
  esac
  sign_macho "$bin"
done

# Sign framework bundles (seals the bundle).
find "$DEST" -maxdepth 1 -name "*.framework" -type d | while IFS= read -r fw; do
  sign_macho "$fw"
done

# Loose dylibs (libffi, Swift concurrency, …).
find "$DEST" -maxdepth 1 \( -name "*.dylib" -o -name "*.so" \) -type f | while IFS= read -r lib; do
  sign_macho "$lib"
done

# When Xcode will not sign the app (CI / FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO),
# deep ad-hoc sign so `flutter run` / local Release can still launch.
if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ] && [ -d "$APP" ]; then
  xattr -cr "$APP" 2>/dev/null || true
  codesign --force --deep --sign - --timestamp=none "$APP" || true
  echo "Ad-hoc deep-signed app (CODE_SIGNING_ALLOWED=NO): $APP"
fi

echo "Signed embedded frameworks in $DEST"
