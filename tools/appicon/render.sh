#!/bin/sh
# Renders tools/appicon/AppIcon.svg to a 1024x1024 PNG without alpha channel:
# qlmanage (macOS, no install) renders the SVG, a small Swift script flattens
# it onto the brand green so no transparent edge can remain.
# Usage: tools/appicon/render.sh [output.png]  (default: Sourdough/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$DIR/../.." && pwd)
OUT=${1:-$ROOT/Sourdough/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/appicon.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cp "$DIR/AppIcon.svg" "$WORK/AppIcon.svg"
qlmanage -t -s 1024 -o "$WORK" "$WORK/AppIcon.svg" >/dev/null 2>&1
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer} xcrun swift "$DIR/flatten.swift" "$WORK/AppIcon.svg.png" "$OUT"
echo "$OUT"
