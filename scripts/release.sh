#!/bin/bash
# 配布用 Prismo.app を dist/ に作り、drag-to-Applications DMG を出力する。
# 使い方: bash scripts/release.sh [バージョン]
set -euo pipefail

APP_NAME="Prismo"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
source "$PROJECT_DIR/scripts/package-app.sh"

default_version() {
  if [ -f "$PROJECT_DIR/versions/macos" ]; then
    tr -d '[:space:]' <"$PROJECT_DIR/versions/macos"
  else
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist"
  fi
}

VERSION="${1:-$(default_version)}"
VERSION="${VERSION#v}"

echo "Building $APP_NAME $VERSION (universal)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"

echo "Packaging .app bundle..."
rm -rf "$DIST_DIR"
package_prismo_app "$BUILD_DIR" "$APP_DIR" "$PROJECT_DIR"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"

SIGN_FLAGS=(--force --sign "${CODESIGN_IDENTITY:--}")
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Signing with Developer ID identity: $CODESIGN_IDENTITY"
  SIGN_FLAGS+=(--deep --options runtime --timestamp)
else
  echo "CODESIGN_IDENTITY not set — using ad-hoc signing"
fi
codesign "${SIGN_FLAGS[@]}" "$APP_DIR"

echo "Building DMG..."
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
TMP_DMG="$DIST_DIR/${APP_NAME}-tmp.dmg"

rm -rf "$STAGING_DIR" "$DMG_PATH" "$TMP_DMG"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$TMP_DMG"

MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach "$TMP_DMG" -noautoopen
sleep 2

osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 940, 460}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "$APP_NAME.app" of container window to {140, 180}
    set position of item "Applications" of container window to {400, 180}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR"

hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH"
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

echo ""
echo "Done:"
lipo -info "$APP_DIR/Contents/MacOS/$APP_NAME"
shasum -a 256 "$DMG_PATH"
