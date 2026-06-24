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
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
        build
else
    echo "Building with ad-hoc signing. WidgetKit may not list the desktop widget until the app is development-signed."
    xcodebuild \
        -project "$ROOT/ToCreate.xcodeproj" \
        -scheme ToCreate \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
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
    codesign --force --sign - --entitlements "$ROOT/ToCreateWidget/ToCreateWidget.entitlements" "$APP/Contents/PlugIns/ToCreateWidget.appex"
    codesign --force --sign - --entitlements "$ROOT/Resources/ToCreate.entitlements" "$APP"
fi
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
