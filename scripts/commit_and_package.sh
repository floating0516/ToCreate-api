#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="$ROOT/dist/ToCreate.dmg"

usage() {
    echo "Usage: ./scripts/commit_and_package.sh <commit-message>" >&2
    echo "Example: ./scripts/commit_and_package.sh \"polish status menu\"" >&2
}

if [[ $# -lt 1 ]]; then
    usage
    exit 2
fi

COMMIT_MESSAGE="$*"

cd "$ROOT"

if [[ -z "$(git status --porcelain)" ]]; then
    echo "No changes to commit." >&2
    exit 1
fi

git diff --check
swift test
./scripts/package_app.sh

if [[ ! -f "$DMG" ]]; then
    echo "Expected DMG was not created: $DMG" >&2
    exit 1
fi

git add -A

if git diff --cached --quiet; then
    echo "No staged changes to commit after packaging." >&2
    exit 1
fi

git commit -m "$COMMIT_MESSAGE"

echo "Created local commit:"
git log --oneline -1
echo
echo "DMG: $DMG"
echo
git status --short
