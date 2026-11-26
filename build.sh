#!/bin/bash
# Builds a release binary and wraps it in a minimal .app bundle.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/FlipFocus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/FlipFocus "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>FlipFocus</string>
  <key>CFBundleIdentifier</key><string>local.flipfocus</string>
  <key>CFBundleExecutable</key><string>FlipFocus</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
