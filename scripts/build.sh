#!/bin/bash
set -euo pipefail

APP_NAME="Prismo"
BUNDLE_NAME="Prismo"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="/Applications/${APP_NAME}.app"
source "$PROJECT_DIR/scripts/package-app.sh"

# 既定は release。--debug は開発者向け。
CONFIG="release"
if [[ "${1:-}" == "--debug" ]]; then
  CONFIG="debug"
fi
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"

echo "Building $APP_NAME ($CONFIG)..."
cd "$PROJECT_DIR"
swift build -c "$CONFIG" 2>&1

echo "Packaging .app bundle..."
rm -rf "$APP_DIR"
package_prismo_app "$BUILD_DIR" "$APP_DIR" "$PROJECT_DIR"

codesign --force --sign - "$APP_DIR" 2>/dev/null || true

echo "Installed to $APP_DIR"
echo ""

if pgrep -x "$BUNDLE_NAME" > /dev/null 2>&1; then
  echo "Restarting..."
  pkill -x "$BUNDLE_NAME" 2>/dev/null || true
  sleep 1
fi

echo "Launching..."
open "$APP_DIR"
echo "Done."
