#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo "  WHOOP Widget — Full Release Pipeline"
echo "========================================="
echo ""

# Step 1: Generate icon
echo "--- Step 1: Generate App Icon ---"
bash "$SCRIPT_DIR/create-icon.sh"
echo ""

# Step 2: Build release
echo "--- Step 2: Build Release ---"
bash "$SCRIPT_DIR/build-release.sh"
echo ""

# Step 3: Notarize
echo "--- Step 3: Notarize ---"
bash "$SCRIPT_DIR/notarize.sh"
echo ""

# Step 4: Create DMG
echo "--- Step 4: Create DMG ---"
bash "$SCRIPT_DIR/create-dmg.sh"
echo ""

echo "========================================="
echo "  Release complete!"
echo "  DMG: build/WhoopWidget.dmg"
echo "========================================="
