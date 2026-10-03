#!/bin/zsh
# Build ScreenAlign.app and install it to ~/Applications.
set -e
cd "${0:A:h}"
APP=build/ScreenAlign.app
rm -rf build && mkdir -p $APP/Contents/MacOS
swiftc -O -o $APP/Contents/MacOS/ScreenAlign main.swift
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ScreenAlign</string>
  <key>CFBundleIdentifier</key><string>co.tomac.screenalign</string>
  <key>CFBundleExecutable</key><string>ScreenAlign</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force -s - $APP
mkdir -p ~/Applications && rm -rf ~/Applications/ScreenAlign.app && cp -R $APP ~/Applications/
echo "installed ~/Applications/ScreenAlign.app"
