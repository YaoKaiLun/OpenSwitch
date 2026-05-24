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
mkdir -p "$APP_PATH/Contents/Frameworks"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_PATH/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "$APP_PATH/Contents/"

# Generate icons if not exists
if [ ! -f "Assets.xcassets/AppIcon.appiconset/icon_512@2x.png" ]; then
    echo "🎨 Generating app icons..."
    python3 Scripts/create-icons-simple.py
fi

# Copy assets
cp -r "Assets.xcassets" "$APP_PATH/Contents/Resources/"

# Make executable
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "✅ Build complete: $APP_PATH"
