#!/bin/sh
# Copies the phone APK into a desktop build, where the desktop app looks for
# it to install HK Cloner on phones plugged in over USB:
#   macOS: <app>.app/Contents/Resources/data/hk-cloner.apk
#   Linux: <bundle>/data/hk-cloner.apk
#
# Usage: tool/bundle_apk.sh macos|linux [path/to/app-release.apk]
# Build first: flutter build apk --release, then flutter build macos|linux --release.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLATFORM=${1:?usage: tool/bundle_apk.sh macos|linux [apk]}
APK=${2:-$ROOT/app/build/app/outputs/flutter-apk/app-release.apk}

[ -f "$APK" ] || { echo "No APK at $APK. Run 'flutter build apk --release' in app/ first." >&2; exit 1; }

case "$PLATFORM" in
  macos)
    APP=$(ls -d "$ROOT"/app/build/macos/Build/Products/Release/*.app 2>/dev/null | head -n 1)
    [ -n "$APP" ] || { echo "No macOS app. Run 'flutter build macos --release' in app/ first." >&2; exit 1; }
    DEST="$APP/Contents/Resources/data"
    ;;
  linux)
    BUNDLE=$(ls -d "$ROOT"/app/build/linux/*/release/bundle 2>/dev/null | head -n 1)
    [ -n "$BUNDLE" ] || { echo "No Linux bundle. Run 'flutter build linux --release' in app/ first." >&2; exit 1; }
    DEST="$BUNDLE/data"
    ;;
  *) echo "Unknown platform '$PLATFORM' (macos or linux; use tool/bundle_apk.ps1 on Windows)" >&2; exit 1 ;;
esac

mkdir -p "$DEST"
cp "$APK" "$DEST/hk-cloner.apk"
echo "Bundled $(du -h "$DEST/hk-cloner.apk" | cut -f1) APK -> $DEST/hk-cloner.apk"

if [ "$PLATFORM" = macos ]; then
  # Adding a file breaks the signature. Ad-hoc builds are signed again here;
  # a Developer ID build must be signed (and notarized) after this step.
  if codesign -dv "$APP" 2>&1 | grep -q 'Signature=adhoc'; then
    codesign --force --deep -s - "$APP"
    echo "Re-signed $APP (ad hoc)"
  else
    echo "Sign $APP again before distributing it: adding the APK changed its contents." >&2
  fi
fi
