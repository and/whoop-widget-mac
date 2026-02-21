#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="WHOOP Widget"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"

echo "=== Building WHOOP Widget ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build universal binary (arm64 + x86_64)
echo "Building for arm64..."
swift build -c release --arch arm64 --package-path "$PROJECT_DIR"

echo "Building for x86_64..."
swift build -c release --arch x86_64 --package-path "$PROJECT_DIR"

echo "Creating universal binary..."
ARM64_BIN="$PROJECT_DIR/.build/arm64-apple-macosx/release/WhoopWidget"
X86_BIN="$PROJECT_DIR/.build/x86_64-apple-macosx/release/WhoopWidget"
UNIVERSAL_BIN="$BUILD_DIR/WhoopWidget"

lipo -create "$ARM64_BIN" "$X86_BIN" -output "$UNIVERSAL_BIN"

# Create .app bundle structure
echo "Creating app bundle..."
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$UNIVERSAL_BIN" "$MACOS_DIR/WhoopWidget"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy icon if it exists
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found. Run scripts/create-icon.sh first."
fi

# Clean up standalone universal binary
rm -f "$UNIVERSAL_BIN"

# Codesign with hardened runtime
echo "Signing app bundle..."
codesign --force --deep --options runtime \
    --entitlements "$PROJECT_DIR/WhoopWidget.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --verbose=2 "$APP_BUNDLE"

echo ""
echo "=== Build complete ==="
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To verify: codesign --verify '$APP_BUNDLE'"
echo "To assess: spctl --assess --type execute '$APP_BUNDLE'"
