#!/usr/bin/env bash
# Generate PNG/ICO favicons from the SVG source.
# Usage: scripts/favicons.sh
# Requires: rsvg-convert (librsvg) and magick (ImageMagick)
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=priv/static/images/favicon.svg
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for size in 16 32 48; do
  rsvg-convert -w "$size" -h "$size" "$SRC" -o "$TMP/$size.png"
done
magick "$TMP/16.png" "$TMP/32.png" "$TMP/48.png" priv/static/favicon.ico

# Apple touch icon: opaque background, iOS rounds the corners itself
rsvg-convert -w 150 -h 150 "$SRC" -o "$TMP/touch.png"
magick -size 180x180 xc:"#faf7f5" "$TMP/touch.png" -gravity center -composite \
  priv/static/images/apple-touch-icon.png

echo "Generated priv/static/favicon.ico and priv/static/images/apple-touch-icon.png"
