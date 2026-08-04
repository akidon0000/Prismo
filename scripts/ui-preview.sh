#!/bin/bash
# ui-preview 📸 ラベル用に全画面 PNG を書き出す。
# 使い方: bash scripts/ui-preview.sh [出力先ディレクトリ]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$PROJECT_DIR/.build/ui-preview}"

cd "$PROJECT_DIR"
swift build
"$PROJECT_DIR/.build/debug/Prismo" --ui-preview "$OUT_DIR" -AppleAccentColor 1

shopt -s nullglob
files=("$OUT_DIR"/*.png)
if [ ${#files[@]} -eq 0 ]; then
  echo "no PNGs were written to $OUT_DIR" >&2
  exit 1
fi

for f in "${files[@]}"; do
  WIDTH=$(sips -g pixelWidth "$f" | awk '/pixelWidth:/ { print $2 }')
  HEIGHT=$(sips -g pixelHeight "$f" | awk '/pixelHeight:/ { print $2 }')
  BYTES=$(stat -f%z "$f")

  if [ "${WIDTH:-0}" -lt 200 ] || [ "${HEIGHT:-0}" -lt 200 ]; then
    echo "$f has unexpected dimensions: ${WIDTH}x${HEIGHT}" >&2
    exit 1
  fi
  if [ "$BYTES" -lt 5000 ]; then
    echo "$f looks blank: only ${BYTES} bytes" >&2
    exit 1
  fi
  echo "wrote $f (${WIDTH}x${HEIGHT}, ${BYTES} bytes)"
done
