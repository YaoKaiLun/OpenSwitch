#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OpenSwitch"
BUNDLE_ID="com.openswitch.app"
VERSION="1.0.0"
BUILD_NUMBER=$(date +%s)

echo "📦 Building $APP_NAME..."

cd "$PROJECT_ROOT"

# Clean previous builds
rm -rf .build
rm -rf "$APP_NAME.app"

# Build release version
swift build -c release

# Create .app bundle structure
APP_PATH="$PROJECT_ROOT/$APP_NAME.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_PATH/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "$APP_PATH/Contents/"

# Generate icons if missing
ICON_SRC="$PROJECT_ROOT/Assets.xcassets/AppIcon.appiconset"
if [ ! -f "$ICON_SRC/icon_512@2x.png" ]; then
    echo "🎨 Generating app icons..."
    python3 Scripts/create-icons-simple.py
fi

# Compile PNG set into AppIcon.icns (required for Finder/Dock icon display)
echo "🎨 Compiling AppIcon.icns..."
ICONSET="$PROJECT_ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$ICON_SRC/icon_16.png" "$ICONSET/icon_16x16.png"
cp "$ICON_SRC/icon_16@2x.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SRC/icon_32.png" "$ICONSET/icon_32x32.png"
cp "$ICON_SRC/icon_32@2x.png" "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SRC/icon_128.png" "$ICONSET/icon_128x128.png"
cp "$ICON_SRC/icon_128@2x.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SRC/icon_256.png" "$ICONSET/icon_256x256.png"
cp "$ICON_SRC/icon_256@2x.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SRC/icon_512.png" "$ICONSET/icon_512x512.png"
cp "$ICON_SRC/icon_512@2x.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

# Make executable
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

# Sign the app bundle so Gatekeeper accepts it (ad-hoc for open-source distribution)
echo "🔏 Signing app bundle..."
codesign --force --sign - \
    --entitlements "$PROJECT_ROOT/OpenSwitch.entitlements" \
    --options runtime \
    "$APP_PATH/Contents/MacOS/$APP_NAME"
codesign --force --sign - \
    --entitlements "$PROJECT_ROOT/OpenSwitch.entitlements" \
    --options runtime \
    "$APP_PATH"

# Verify signature
codesign --verify --deep --strict "$APP_PATH"

echo "✅ Build complete: $APP_PATH"
