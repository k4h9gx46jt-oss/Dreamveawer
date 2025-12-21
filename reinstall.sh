#!/usr/bin/env bash
set -euo pipefail
#xcrun simctl boot 579F523E-61ED-47D3-87C7-F3E1AF3CDE7A
IOS_SIM="DD1955E9-8440-4978-AA06-0BDE7A2BDAFD"
WATCH_SIM="579F523E-61ED-47D3-87C7-F3E1AF3CDE7A"
IOS_APP="/Users/SEV0A/Library/Developer/Xcode/DerivedData/DreamWeaver-ewapafpdgzzigfgvlufslotbdihh/Build/Products/Debug-iphonesimulator/DreamWeaver.app"
WATCH_APP="/Users/SEV0A/Library/Developer/Xcode/DerivedData/DreamWeaver-ewapafpdgzzigfgvlufslotbdihh/Build/Products/Debug-watchsimulator/DreamWeaver WatchKit App.app"

echo "🔨 Building DreamWeaver (iOS + watchOS)..."
xcodebuild \
	-project Ihpone/DreamWeaver/DreamWeaver.xcodeproj \
	-scheme DreamWeaver \
	-configuration Debug \
	-destination "platform=iOS Simulator,id=${IOS_SIM}"

echo "📱 Reinstalling iPhone app..."

xcrun simctl uninstall "$IOS_SIM" GJDRW.DreamWeaver || true
xcrun simctl install "$IOS_SIM" "$IOS_APP"

echo "⌚ Reinstalling Watch app..."
xcrun simctl uninstall "$WATCH_SIM" GJDRW.DreamWeaver.watchkitapp || true
xcrun simctl install "$WATCH_SIM" "$WATCH_APP"
