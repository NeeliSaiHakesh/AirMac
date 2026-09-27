#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$PROJECT_DIR/build/AirMac.app"
BIN_DIR="$PROJECT_DIR/.build/out/Products/Release"

echo "🔨 Building AirMac Hand Gesture App (Release)..."
cd "$PROJECT_DIR"
xattr -cr . || true
swift build -c release

echo "📦 Creating macOS App Bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Binary
cp "$BIN_DIR/HandGestureApp" "$APP_BUNDLE/Contents/MacOS/HandGestureApp"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/HandGestureAppCore/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Clean Extended Attributes & Sign with stable identifier and entitlements
echo "✍️ Codesigning App Bundle with stable identifier..."
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - --identifier "com.airmac.gestures" --entitlements "$PROJECT_DIR/AirMac.entitlements" "$APP_BUNDLE"

echo "✅ Build Complete: $APP_BUNDLE"
echo "👉 To launch: open $APP_BUNDLE"
