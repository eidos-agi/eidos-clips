#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Eidos Clips must be built on macOS with Xcode installed.' >&2
  exit 1
fi
kind="${CLIPS_BUILD_KIND:-development}"
if [[ "$kind" != development && "$kind" != release ]]; then
  echo 'CLIPS_BUILD_KIND must be development or release.' >&2
  exit 1
fi
identity='Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)'
if [[ "$kind" == release ]]; then
  if [[ -z "${CLIPS_APP_OUTPUT:-}" ]]; then
    echo 'Use scripts/release-app.sh to build a signed release.' >&2
    exit 1
  fi
  security find-identity -v -p codesigning | grep -Fq "\"$identity\"" || {
    echo 'The Eidos AGI LLC Developer ID identity is unavailable in this keychain.' >&2
    exit 1
  }
fi
swift build --configuration release
mkdir -p dist
stage="$(mktemp -d "${TMPDIR:-/tmp}/eidos-clips.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="${CLIPS_APP_OUTPUT:-$stage/Eidos Clips Dev.app}"
if [[ -e "$app" ]]; then
  echo 'Refusing to replace an existing application bundle.' >&2
  exit 1
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/EidosClips "$app/Contents/MacOS/EidosClips"
cp packaging/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ClipsSourceCommit string $(git rev-parse HEAD)" "$app/Contents/Info.plist"
clips_source_dirty=false
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then clips_source_dirty=true; fi
/usr/libexec/PlistBuddy -c "Add :ClipsSourceDirty bool $clips_source_dirty" "$app/Contents/Info.plist"
swift scripts/create-icon.swift "$stage/Clips.iconset"
iconutil -c icns "$stage/Clips.iconset" -o "$app/Contents/Resources/Clips.icns"
if [[ "$kind" == development ]]; then
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.eidos.clips.dev' "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName Eidos Clips Dev' "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Eidos Clips Dev' "$app/Contents/Info.plist"
  codesign --force --sign - "$app"
else
  codesign --force --sign "$identity" --options runtime --timestamp \
    --entitlements packaging/Release.entitlements "$app"
fi
codesign --verify --strict --verbose=2 "$app"
if [[ "$kind" == development ]]; then
  archive='dist/EidosClips-Development-macOS.zip'
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  shasum -a 256 "$archive" > "$archive.sha256"
  echo 'Development build only. For a notarized download, run bash scripts/release-app.sh on the Eidos signing Mac.'
else
  echo "Signed release staged at: $app. Notarization is still required."
fi
