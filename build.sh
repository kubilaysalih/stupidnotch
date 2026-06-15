#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="StupidNotch"
BUNDLE="$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RES" "$FRAMEWORKS"
cp Resources/Info.plist "$CONTENTS/Info.plist"
if [ -f Resources/StupidNotch.icns ]; then
    cp Resources/StupidNotch.icns "$RES/StupidNotch.icns"
fi

# Build the MediaRemote adapter framework if it isn't built yet. The framework
# is dlopen'd by /usr/bin/perl (which inherits the com.apple.* entitlement
# MediaRemote requires); our Swift code spawns perl as a subprocess and reads
# now-playing JSON from its stdout. See vendor/mediaremote-adapter/README.md.
ADAPTER_SRC="vendor/mediaremote-adapter"
ADAPTER_BUILD="$ADAPTER_SRC/build"
ADAPTER_FW="$ADAPTER_BUILD/MediaRemoteAdapter.framework"
ADAPTER_PL="$ADAPTER_SRC/bin/mediaremote-adapter.pl"
if [ ! -d "$ADAPTER_FW" ]; then
    echo "Building MediaRemoteAdapter framework…"
    (cd "$ADAPTER_SRC" && mkdir -p build && cd build && \
        cmake -DCMAKE_BUILD_TYPE=Release .. >/dev/null && \
        cmake --build . --config Release >/dev/null)
fi
cp -R "$ADAPTER_FW" "$FRAMEWORKS/"
cp "$ADAPTER_PL" "$RES/mediaremote-adapter.pl"
chmod +x "$RES/mediaremote-adapter.pl"

# Bundle third-party license text. BSD-3-Clause requires the copyright notice to
# ship with binary distributions of MediaRemoteAdapter.
mkdir -p "$RES/Licenses"
cp "$ADAPTER_SRC/LICENSE" "$RES/Licenses/MediaRemoteAdapter-LICENSE.txt"

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
