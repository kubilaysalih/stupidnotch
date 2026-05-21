#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>   (e.g. $0 1.1)"
    exit 1
fi

VERSION="$1"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Version must look like 1.1 or 1.1.2 (got: $VERSION)"
    exit 1
fi

PLIST="Resources/Info.plist"
TAG="v$VERSION"

CURRENT=$(plutil -extract CFBundleShortVersionString raw "$PLIST")
BUILD=$(plutil -extract CFBundleVersion raw "$PLIST")
NEXT_BUILD=$((BUILD + 1))

echo "Bumping $CURRENT (build $BUILD) -> $VERSION (build $NEXT_BUILD)"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -replace CFBundleVersion -string "$NEXT_BUILD" "$PLIST"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists locally. Delete it first if you want to recreate."
    exit 1
fi

git add "$PLIST"
git commit -m "Bump version to $VERSION"
git tag "$TAG"

echo
echo "Done. Next:"
echo "  git push && git push origin $TAG"
