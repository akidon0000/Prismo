#!/bin/bash
# dist/ にある署名済み DMG を公証し、staple する（CI 専用）。
# 使い方: bash scripts/notarize.sh <バージョン>
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"

VERSION="${1:?version argument is required}"
VERSION="${VERSION#v}"
DMG_PATH="$DIST_DIR/Prismo-${VERSION}.dmg"

: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required}"
: "${APP_STORE_CONNECT_KEY_PATH:?APP_STORE_CONNECT_KEY_PATH is required}"

echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --key "$APP_STORE_CONNECT_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket..."
xcrun stapler staple "$DMG_PATH"

echo "Notarized and stapled:"
shasum -a 256 "$DMG_PATH"
