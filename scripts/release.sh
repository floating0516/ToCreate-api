#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$ROOT/Resources/Info.plist"
PROJECT_FILE="$ROOT/ToCreate.xcodeproj/project.pbxproj"
DMG="$ROOT/dist/ToCreate.dmg"
REPO="floating0516/ToCreate-api"

usage() {
    echo "Usage: ./scripts/release.sh [--dry-run] <version> <release-notes>" >&2
    echo "Example: ./scripts/release.sh 0.1.2 \"修复更新检查问题\"" >&2
}

DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -lt 2 ]]; then
    usage
    exit 2
fi

VERSION="$1"
shift
RELEASE_NOTES="$*"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use semantic format, for example: 0.1.2" >&2
    exit 2
fi

cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "Working tree has uncommitted changes; dry run will not modify them." >&2
        git status --short >&2
    else
        echo "Git working tree is not clean. Commit or stash current changes before releasing." >&2
        git status --short >&2
        exit 1
    fi
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Tag v$VERSION already exists locally." >&2
    exit 1
fi

if git ls-remote --tags origin "v$VERSION" | grep -q "v$VERSION"; then
    echo "Tag v$VERSION already exists on origin." >&2
    exit 1
fi

CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
NEXT_BUILD="$((CURRENT_BUILD + 1))"

cat <<SUMMARY
Release summary
Current version: $CURRENT_VERSION ($CURRENT_BUILD)
New version:     $VERSION ($NEXT_BUILD)
Tag:             v$VERSION
DMG:             $DMG
Release notes:   $RELEASE_NOTES
SUMMARY

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run only. No files were changed."
    exit 0
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" "$INFO_PLIST"
perl -0pi -e "s/MARKETING_VERSION = [0-9]+\\.[0-9]+\\.[0-9]+;/MARKETING_VERSION = $VERSION;/g; s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/g" "$PROJECT_FILE"

swift test
./scripts/package_app.sh

if [[ ! -f "$DMG" ]]; then
    echo "Expected DMG was not created: $DMG" >&2
    exit 1
fi

git add "$INFO_PLIST" "$PROJECT_FILE"
git commit -m "release v$VERSION"
git tag "v$VERSION"
git push
git push origin "v$VERSION"

gh release create "v$VERSION" "$DMG" \
    --repo "$REPO" \
    --title "ToCreate v$VERSION" \
    --notes "$RELEASE_NOTES"

echo "Released ToCreate v$VERSION"
