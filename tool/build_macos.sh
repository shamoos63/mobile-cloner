#!/bin/sh
# Builds the macOS app with the Flutter this project is pinned to (3.32.x:
# 3.35+ dropped Android 6) and bundles the phone APK into it.
#
# Usage: tool/build_macos.sh [path/to/app-release.apk]
# Flutter: $HK_FLUTTER, else ~/flutter-3.32.8/bin/flutter, else $FLUTTER_ROOT,
# else the flutter on PATH. Anything but 3.32.x is refused.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FLUTTER=${HK_FLUTTER:-}
[ -z "$FLUTTER" ] && [ -x "$HOME/flutter-3.32.8/bin/flutter" ] && FLUTTER="$HOME/flutter-3.32.8/bin/flutter"
[ -z "$FLUTTER" ] && [ -n "${FLUTTER_ROOT:-}" ] && FLUTTER="$FLUTTER_ROOT/bin/flutter"
[ -z "$FLUTTER" ] && FLUTTER=$(command -v flutter || true)
[ -n "$FLUTTER" ] || { echo "Flutter not found. Install Flutter 3.32.8 or set HK_FLUTTER." >&2; exit 1; }

VERSION=$("$FLUTTER" --version 2>/dev/null | head -n 1 | sed -E 's/^Flutter ([0-9.]+).*/\1/')
case "$VERSION" in
  3.32.*) ;;
  *)
    echo "Flutter $VERSION at $FLUTTER is the wrong version: this project needs 3.32.x." >&2
    echo "Flutter 3.35+ dropped Android 6 and rewrites project files. Set HK_FLUTTER to a 3.32 install." >&2
    exit 1
    ;;
esac
echo "Using Flutter $VERSION ($FLUTTER)"

cd "$ROOT/app"
# Xcode's module cache breaks when another Flutter version built here before
# ("has been modified since the module file was built"): start clean then.
STAMP=build/macos/.flutter-version
if [ -d build/macos ] && [ "$(cat "$STAMP" 2>/dev/null)" != "$VERSION" ]; then
  echo "build/macos was built by another Flutter; cleaning it"
  rm -rf build/macos
fi
"$FLUTTER" pub get
"$FLUTTER" build macos --release
echo "$VERSION" > "$STAMP"

APK=${1:-$ROOT/app/build/app/outputs/flutter-apk/app-release.apk}
if [ -f "$APK" ]; then
  "$ROOT/tool/bundle_apk.sh" macos "$APK"
else
  echo "No phone APK at $APK: the app is built without one (it will offer \"Choose APK...\")." >&2
fi
ls -d "$ROOT"/app/build/macos/Build/Products/Release/*.app
