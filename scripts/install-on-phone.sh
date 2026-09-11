#!/bin/bash
# Rebuilds Wyd and installs it on the connected iPhone.
#
# A free Apple ID signs apps for seven days. When Wyd stops opening, plug the
# phone in, unlock it, and run this. Your logged days live in the app's own
# database and survive the reinstall; only the signature is renewed.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.tanushree.watertracker"
BUILD_DIR="${TMPDIR:-/tmp}/wyd-device-build"

# A device build needs a few GB. Failing here is far clearer than the disk
# filling halfway through and xcodebuild reporting something unrelated.
FREE_GB=$(df -g . | awk 'NR==2 {print $4}')
if [ "$FREE_GB" -lt 8 ]; then
    echo "Only ${FREE_GB}GB free. A device build needs about 8GB." >&2
    echo "Free some space, then run this again." >&2
    exit 1
fi

echo "Looking for a connected iPhone..."
UDID=$(xcrun xctrace list devices 2>/dev/null \
    | grep -v Simulator \
    | grep -oE '\(([0-9]{8}-[0-9A-F]{16})\)' \
    | tr -d '()' \
    | head -1)

if [ -z "$UDID" ]; then
    echo "No iPhone found. Plug it in, unlock it, and tap Trust if asked." >&2
    exit 1
fi
echo "Found $UDID"

# The .xcodeproj is generated and gitignored, so it may not exist yet.
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen" >&2; exit 1; }
xcodegen generate >/dev/null

echo "Building..."
xcodebuild -project WaterTracker.xcodeproj \
    -scheme WaterTracker \
    -destination "id=$UDID" \
    -derivedDataPath "$BUILD_DIR" \
    -allowProvisioningUpdates \
    build > "$BUILD_DIR.log" 2>&1 \
  || { echo "Build failed. Last lines:" >&2; tail -25 "$BUILD_DIR.log" >&2; exit 1; }

echo "Installing..."
xcrun devicectl device install app --device "$UDID" \
    "$BUILD_DIR/Build/Products/Debug-iphoneos/WaterTracker.app" >/dev/null

# The build products are several GB and are of no use once installed.
rm -rf "$BUILD_DIR" "$BUILD_DIR.log"

echo
echo "Done. Wyd is on your phone, good for another seven days."
echo "If it refuses to open, trust the certificate once under"
echo "Settings > General > VPN & Device Management."
