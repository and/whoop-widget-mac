#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="WHOOP Widget"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="WhoopWidget"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run scripts/build-release.sh first."
    exit 1
fi

echo "=== Creating DMG ==="

# Clean up previous
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy app and create Applications symlink
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "Creating disk image..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Sign DMG
echo "Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "=== DMG created ==="
echo "DMG: $DMG_PATH"
echo ""
echo "To verify: codesign --verify '$DMG_PATH'"
