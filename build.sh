#!/bin/bash
# Builds "MD Preview.app" into ./build. Pass "install" to also copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MD Preview"
APP="build/$APP_NAME.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MDPreview" "$APP/Contents/MacOS/MDPreview"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/web "$APP/Contents/Resources/web"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Quick Look extension, embedded in the app. SwiftPM can't build an .appex, so swiftc it directly.
APPEX="$APP/Contents/PlugIns/MDPreviewQuickLook.appex"
mkdir -p "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
swiftc -O -target arm64-apple-macos14.0 -parse-as-library -application-extension \
  -module-name MDPreviewQuickLook QuickLook/*.swift \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/MDPreviewQuickLook"
cp QuickLook/Info.plist "$APPEX/Contents/Info.plist"
cp -R Resources/web "$APPEX/Contents/Resources/web"
codesign --force --sign - --entitlements QuickLook/QuickLook.entitlements "$APPEX"

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "install" ]]; then
  DEST="/Applications/$APP_NAME.app"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  "$LSREGISTER" -f "$DEST"
  echo "Installed $DEST"
fi
