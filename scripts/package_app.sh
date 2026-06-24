#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tocreate-package.XXXXXX")"
DERIVED_DATA="$WORK/DerivedData"
APP="$WORK/ToCreate.app"
STAGING="$WORK/dmg"
ICONSET="$WORK/AppIcon.iconset"
ICON="$WORK/AppIcon.icns"
DMG="$WORK/ToCreate.dmg"
OUTPUT_DMG="$DIST/ToCreate.dmg"

trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"
xcodebuild \
    -project "$ROOT/ToCreate.xcodeproj" \
    -scheme ToCreate \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build

rm -rf "$DIST"
mkdir -p "$DIST"
mkdir -p "$STAGING"

ditto "$DERIVED_DATA/Build/Products/Release/ToCreate.app" "$APP"

swift "$ROOT/scripts/generate_icon.swift" "$ICONSET" "$ROOT/Resources/AppIconSource.png"
iconutil --convert icns "$ICONSET" --output "$ICON"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
codesign --force --sign - --entitlements "$ROOT/ToCreateWidget/ToCreateWidget.entitlements" "$APP/Contents/PlugIns/ToCreateWidget.appex"
codesign --force --sign - --entitlements "$ROOT/Resources/ToCreate.entitlements" "$APP"
codesign --verify --deep --strict "$APP"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
    -volname "ToCreate" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG"
hdiutil verify "$DMG"

mv "$DMG" "$OUTPUT_DMG"

echo "DMG: $OUTPUT_DMG"
