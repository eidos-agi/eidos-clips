#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Eidos Clips must be built on macOS with Xcode installed.' >&2
  exit 1
fi
swift build --configuration release
mkdir -p dist
stage="$(mktemp -d "${TMPDIR:-/tmp}/eidos-clips.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/EidosClips.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/EidosClips "$app/Contents/MacOS/EidosClips"
cp packaging/Info.plist "$app/Contents/Info.plist"
codesign --force --sign "${CODESIGN_IDENTITY:--}" "$app"
codesign --verify --strict --verbose=2 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/EidosClips-macOS.zip
shasum -a 256 dist/EidosClips-macOS.zip > dist/EidosClips-macOS.zip.sha256
echo 'Built dist/EidosClips-macOS.zip. The default ad-hoc signature is for development, not a notarized release.'
