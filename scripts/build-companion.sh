#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Simulator output is explicitly not a provisioned iPad application.
app='dist/Clips Draw Simulator.app'
mkdir -p "$app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -swift-version 5 -O -sdk "$sdk" -target arm64-apple-ios17.0-simulator \
  -parse-as-library Sources/ClipsModules/*.swift Companion/ClipsDraw/ClipsDrawApp.swift \
  -o "$app/ClipsDraw"
cp Companion/ClipsDraw/Info.plist "$app/Info.plist"
codesign --force --sign - "$app"
ditto -c -k --keepParent "$app" dist/ClipsDraw-Simulator.zip
printf '%s\n' 'Built simulator companion. Physical iPad installation requires Apple Development provisioning in Xcode.'
