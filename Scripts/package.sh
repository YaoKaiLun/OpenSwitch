#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenSwitch"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
TMP_DIR=$(mktemp -d)

echo "📦 Packaging $APP_NAME into DMG..."

cd "$PROJECT_ROOT"

# First build the app
"$PROJECT_ROOT/Scripts/build.sh"

# Prepare DMG contents
mkdir -p "$TMP_DIR"
cp -R "$APP_NAME.app" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo "✅ DMG created: $PROJECT_ROOT/$DMG_NAME"
