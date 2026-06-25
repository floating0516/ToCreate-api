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
RW_DMG="$WORK/ToCreate-rw.dmg"
DMG_BACKGROUND="$WORK/dmg-background.png"
OUTPUT_DMG="$DIST/ToCreate.dmg"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development}"

trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"
if [[ -n "$DEVELOPMENT_TEAM" ]]; then
    echo "Building with Apple Development signing for team: $DEVELOPMENT_TEAM"
    xcodebuild \
        -project "$ROOT/ToCreate.xcodeproj" \
        -scheme ToCreate \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS="arm64 x86_64" \
        build
else
    echo "Building with ad-hoc signing."
    xcodebuild \
        -project "$ROOT/ToCreate.xcodeproj" \
        -scheme ToCreate \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS="arm64 x86_64" \
        build
fi

rm -rf "$DIST"
mkdir -p "$DIST"
mkdir -p "$STAGING"

ditto "$DERIVED_DATA/Build/Products/Release/ToCreate.app" "$APP"

xattr -cr "$APP"
if [[ -n "$DEVELOPMENT_TEAM" ]]; then
    echo "Keeping Xcode-managed development signature and provisioning profiles."
else
    swift "$ROOT/scripts/generate_icon.swift" "$ICONSET" "$ROOT/Resources/AppIconSource.png"
    iconutil --convert icns "$ICONSET" --output "$ICON"
    cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"
    codesign --force --sign - --entitlements "$ROOT/Resources/ToCreate.entitlements" "$APP"
fi
codesign --verify --deep --strict "$APP"

ditto "$APP" "$STAGING/ToCreate.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$STAGING/.background"
swift "$ROOT/scripts/make_dmg_background.swift" "$DMG_BACKGROUND"
cp "$DMG_BACKGROUND" "$STAGING/.background/background.png"

hdiutil create \
    -volname "ToCreate" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    "$RW_DMG"

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_POINT" ]]; then
    echo "Failed to mount DMG for Finder styling." >&2
    exit 1
fi

osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$MOUNT_POINT" as alias
tell application "Finder"
  open dmgFolder
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set bounds of container window of dmgFolder to {100, 100, 760, 500}
  set opts to the icon view options of container window of dmgFolder
    set arrangement of opts to not arranged
    set icon size of opts to 96
  set background picture of opts to file ".background:background.png" of dmgFolder
  set position of item "ToCreate.app" of dmgFolder to {170, 220}
  set position of item "Applications" of dmgFolder to {490, 220}
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
APPLESCRIPT

if [[ ! -f "$MOUNT_POINT/.DS_Store" ]]; then
    echo "Failed to persist Finder DMG layout." >&2
    exit 1
fi

hdiutil detach "$MOUNT_POINT" -quiet

hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$DMG"
hdiutil verify "$DMG"

mv "$DMG" "$OUTPUT_DMG"

echo "DMG: $OUTPUT_DMG"
