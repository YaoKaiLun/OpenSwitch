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

# Add install helper to remove Gatekeeper quarantine (fixes "app is damaged" after download)
cat > "$TMP_DIR/Install OpenSwitch.command" << 'INSTALL_EOF'
#!/bin/bash
set -e
APP_NAME="OpenSwitch"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="/Applications/$APP_NAME.app"

echo "Installing $APP_NAME..."
rm -rf "$TARGET"
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$TARGET"
xattr -cr "$TARGET"
echo "Done! Launching $APP_NAME..."
open "$TARGET"
INSTALL_EOF
chmod +x "$TMP_DIR/Install OpenSwitch.command"

# Create DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo "✅ DMG created: $PROJECT_ROOT/$DMG_NAME"
