#!/bin/bash
# README / Site 用スクリーンショットを実 UI から生成する。
# 使い方:
#   bash scripts/screenshot.sh
#   bash scripts/screenshot.sh <出力先>
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
README_OUT="$PROJECT_DIR/assets/screenshot.png"
SITE_OUT="$PROJECT_DIR/Site/Assets/images/screenshot.png"

if [ "${1:-}" != "" ]; then
  OUTS=("$1")
else
  OUTS=("$README_OUT" "$SITE_OUT")
fi

cd "$PROJECT_DIR"
swift build

PRIMARY="${OUTS[0]}"
mkdir -p "$(dirname "$PRIMARY")"
"$PROJECT_DIR/.build/debug/Prismo" --screenshot "$PRIMARY" -AppleAccentColor 1

WIDTH=$(sips -g pixelWidth "$PRIMARY" | awk '/pixelWidth:/ { print $2 }')
HEIGHT=$(sips -g pixelHeight "$PRIMARY" | awk '/pixelHeight:/ { print $2 }')
BYTES=$(stat -f%z "$PRIMARY")

if [ "${WIDTH:-0}" -lt 800 ] || [ "${HEIGHT:-0}" -lt 600 ]; then
  echo "screenshot has unexpected dimensions: ${WIDTH}x${HEIGHT}" >&2
  exit 1
fi
if [ "$BYTES" -lt 20000 ]; then
  echo "screenshot looks blank: only ${BYTES} bytes" >&2
  exit 1
fi

for OUT in "${OUTS[@]:1}"; do
  mkdir -p "$(dirname "$OUT")"
  cp "$PRIMARY" "$OUT"
done

for OUT in "${OUTS[@]}"; do
  echo "wrote $OUT (${WIDTH}x${HEIGHT}, ${BYTES} bytes)"
done
