#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="WHOOP Widget"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Notarization credentials — set these environment variables or pass as arguments
APPLE_ID="${APPLE_ID:?Set APPLE_ID environment variable (your Apple ID email)}"
TEAM_ID="${TEAM_ID:?Set TEAM_ID environment variable (your Apple Developer Team ID)}"
APP_PASSWORD="${APP_PASSWORD:?Set APP_PASSWORD environment variable (app-specific password)}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run scripts/build-release.sh first."
    exit 1
fi

# Create a ZIP for notarization submission
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
echo "Creating ZIP for notarization..."
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# Submit for notarization
echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

# Staple the notarization ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

# Clean up ZIP
rm -f "$ZIP_PATH"

echo ""
echo "=== Notarization complete ==="
echo "App is notarized and stapled: $APP_BUNDLE"
