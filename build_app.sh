#!/bin/bash
set -e

APP_NAME="Mectrics.app"
BUNDLE_ID="com.openmectrics.mectrics"
BUILD_DIR=".build/release"
PLIST_FILE="Sources/Resources/Info.plist"

echo "🔨 Building Mectrics in Release mode..."
swift build -c release

echo "📦 Packaging $APP_NAME bundle..."
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/Mectrics" "$APP_NAME/Contents/MacOS/Mectrics"
chmod +x "$APP_NAME/Contents/MacOS/Mectrics"

# Copy Info.plist
if [ -f "$PLIST_FILE" ]; then
    cp "$PLIST_FILE" "$APP_NAME/Contents/Info.plist"
elif [ -f "Info.plist" ]; then
    cp "Info.plist" "$APP_NAME/Contents/Info.plist"
fi

# Copy AppIcon if available
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_NAME/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_NAME/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_NAME/Contents/Info.plist" 2>/dev/null || true
fi

# Ad-hoc code signing
echo "🔏 Code-signing $APP_NAME..."
codesign --force --deep --sign - "$APP_NAME"

echo "✅ Successfully built $APP_NAME!"

# Optional install to /Applications
if [ "$1" == "--install" ] || [ "$1" == "-i" ]; then
    echo "🚀 Installing to /Applications/Mectrics.app..."
    pkill -f "Mectrics.app" || true
    rm -rf "/Applications/Mectrics.app"
    cp -R "$APP_NAME" "/Applications/"
    
    # Try creating CLI symlink
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        ln -sf "/Applications/Mectrics.app/Contents/MacOS/Mectrics" "/usr/local/bin/mectrics" 2>/dev/null || true
        echo "🔗 CLI symlink created at /usr/local/bin/mectrics"
    fi
    
    echo "🎉 Installed! Launching Mectrics..."
    open "/Applications/Mectrics.app"
fi
