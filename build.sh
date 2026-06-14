#!/bin/bash
set -e

APP_NAME="AriaPilot"
APP_VERSION="1.5.0"
BUILD_NUMBER="150"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ZIP_NAME="$APP_NAME-v$APP_VERSION-macos.zip"
ICON_FILE="assets/AppIcon.icns"
ARIA2_VENDOR_BINARY="vendor/aria2/darwin-arm64/aria2c"
ARIA2_VENDOR_LIB_DIR="vendor/aria2/darwin-arm64/lib"
ARIA2_RESOURCES="$RESOURCES/aria2"

if [ -x "scripts/prepare_vendor_update.sh" ]; then
    scripts/prepare_vendor_update.sh
fi

echo "Building release..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
if [ ! -f "$ICON_FILE" ]; then
    echo "Missing app icon: $ICON_FILE" >&2
    exit 1
fi
cp "$ICON_FILE" "$RESOURCES/AppIcon.icns"
if [ -f "$ARIA2_VENDOR_BINARY" ]; then
    mkdir -p "$ARIA2_RESOURCES"
    cp "$ARIA2_VENDOR_BINARY" "$ARIA2_RESOURCES/aria2c"
    chmod 755 "$ARIA2_RESOURCES/aria2c"
    if [ -d "$ARIA2_VENDOR_LIB_DIR" ]; then
        cp -R "$ARIA2_VENDOR_LIB_DIR" "$ARIA2_RESOURCES/lib"
        chmod -R u+rwX,go+rX "$ARIA2_RESOURCES/lib"
    fi
else
    echo "Warning: bundled aria2 backend not found at $ARIA2_VENDOR_BINARY" >&2
fi

cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>AriaPilot</string>
	<key>CFBundleDisplayName</key>
	<string>AriaPilot</string>
	<key>CFBundleIdentifier</key>
	<string>com.ariapilot.app</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>CFBundleShortVersionString</key>
	<string>$APP_VERSION</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>AriaPilot</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSLocalNetworkUsageDescription</key>
	<string>AriaPilot 需要连接本机 aria2 RPC 服务。</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
</dict>
</plist>
EOF

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "Creating release zip..."
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo "Done: $APP_BUNDLE"
echo "Package: $ZIP_NAME"
echo "Run with: open $APP_BUNDLE"
