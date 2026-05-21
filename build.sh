#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="StupidNotch"
BUNDLE="$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RES"
cp Resources/Info.plist "$CONTENTS/Info.plist"
if [ -f Resources/StupidNotch.icns ]; then
    cp Resources/StupidNotch.icns "$RES/StupidNotch.icns"
fi

# Build a universal binary so it runs on both Apple Silicon and Intel Macs.
ARM_BIN="$(mktemp -t stupidnotch-arm)"
X86_BIN="$(mktemp -t stupidnotch-x86)"

swiftc -O \
    -target arm64-apple-macos14.0 \
    -framework Cocoa -framework SwiftUI -framework Combine -framework ServiceManagement \
    -o "$ARM_BIN" \
    Sources/*.swift

if swiftc -O \
    -target x86_64-apple-macos14.0 \
    -framework Cocoa -framework SwiftUI -framework Combine -framework ServiceManagement \
    -o "$X86_BIN" \
    Sources/*.swift 2>/dev/null; then
    lipo -create "$ARM_BIN" "$X86_BIN" -output "$MACOS/$APP_NAME"
else
    echo "x86_64 toolchain unavailable, building arm64-only."
    cp "$ARM_BIN" "$MACOS/$APP_NAME"
fi

rm -f "$ARM_BIN" "$X86_BIN"
chmod +x "$MACOS/$APP_NAME"

# Ad-hoc sign so Gatekeeper lets it open without "damaged" complaints.
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "Built: $(pwd)/$BUNDLE"
echo "Run with:  open '$(pwd)/$BUNDLE'"
echo "Install:   mv '$(pwd)/$BUNDLE' /Applications/"
