#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lihe-api-package.XXXXXX")"
APP="$WORK/Lihe API.app"
STAGING="$WORK/dmg"
ICONSET="$WORK/AppIcon.iconset"
ICON="$WORK/AppIcon.icns"
DMG="$WORK/Lihe-API.dmg"
OUTPUT_DMG="$DIST/Lihe-API.dmg"

trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$DIST"
mkdir -p "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGING"

cp "$BIN_DIR/LiheAPI" "$APP/Contents/MacOS/LiheAPI"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

swift "$ROOT/scripts/generate_icon.swift" "$ICONSET" "$ROOT/Resources/AppIconSource.png"
iconutil --convert icns "$ICONSET" --output "$ICON"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname "Lihe API" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"
hdiutil verify "$DMG"

mv "$DMG" "$OUTPUT_DMG"

echo "DMG: $OUTPUT_DMG"
