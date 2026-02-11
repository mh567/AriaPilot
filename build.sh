#!/bin/bash
set -e

APP_NAME="aria2bar"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

echo "Building release..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>aria2bar</string>
	<key>CFBundleDisplayName</key>
	<string>aria2bar</string>
	<key>CFBundleIdentifier</key>
	<string>com.aria2bar.app</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>aria2bar</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
</dict>
</plist>
EOF

echo "Done: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
