#!/bin/bash
# Company direct-distribution lane. Uses the existing local keychain; never exports credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  echo 'Release requires the Apple Silicon Eidos signing Mac.' >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo 'Release requires a clean, committed checkout. No installed app will be changed.' >&2
  exit 1
fi
source_sha="$(git rev-parse HEAD)"
identity='Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)'
profile="${CLIPS_NOTARY_PROFILE:-eidos-notary}"
security find-identity -v -p codesigning | grep -Fq "\"$identity\"" || {
  echo 'Missing Eidos AGI LLC Developer ID private key in this Mac keychain. No unsigned fallback is allowed.' >&2
  exit 1
}
stage="$(mktemp -d "${TMPDIR:-/tmp}/eidos-clips-release.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
xcrun notarytool history --keychain-profile "$profile" --output-format json > "$stage/notary-preflight.json"
evidence="dist/release-$source_sha"
mkdir -p "$evidence"
swift test
CLIPS_BUILD_KIND=release CLIPS_APP_OUTPUT="$stage/Eidos Clips.app" bash scripts/build-app.sh
app="$stage/Eidos Clips.app"
codesign -d --verbose=4 "$app" 2> "$evidence/codesign.txt"
grep -Fxq 'TeamIdentifier=Y6CQ4SWPWM' "$evidence/codesign.txt"
grep -Fxq "Authority=$identity" "$evidence/codesign.txt"
grep -Fq runtime "$evidence/codesign.txt"
ditto -c -k --sequesterRsrc --keepParent "$app" "$stage/submit.zip"
xcrun notarytool submit "$stage/submit.zip" --keychain-profile "$profile" --wait \
  --output-format json > "$evidence/notarization.json"
python3 - "$evidence/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple did not accept this submission. See notarization.json; no release ZIP was produced.')
PY
xcrun stapler staple "$app" > "$evidence/staple.txt" 2>&1
xcrun stapler validate "$app" >> "$evidence/staple.txt" 2>&1
codesign --verify --deep --strict --verbose=2 "$app" >> "$evidence/codesign.txt" 2>&1
spctl --assess --type execute --verbose=4 "$app" > "$evidence/gatekeeper.txt" 2>&1
# The final archive must contain the STAPLED app, not the pre-notarization upload.
ditto -c -k --sequesterRsrc --keepParent "$app" "$stage/final.zip"
ditto -x -k "$stage/final.zip" "$stage/unpacked"
xcrun stapler validate "$stage/unpacked/Eidos Clips.app" >> "$evidence/staple.txt" 2>&1
spctl --assess --type execute --verbose=4 "$stage/unpacked/Eidos Clips.app" >> "$evidence/gatekeeper.txt" 2>&1
archive="dist/EidosClips-Notarized-${source_sha:0:12}.zip"
if [[ -e "$archive" ]]; then
  echo 'A verified release ZIP already exists for this commit. Refusing to replace it.' >&2
  exit 1
fi
mv "$stage/final.zip" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
python3 - "$evidence" "$source_sha" "$archive" <<'PY'
import hashlib, json, pathlib, sys
folder, source, archive = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
notary = json.loads((folder / 'notarization.json').read_text())
(folder / 'release.json').write_text(json.dumps({'sourceCommit': source, 'teamID': 'Y6CQ4SWPWM',
    'notarySubmission': notary['id'], 'notarization': 'Accepted', 'stapleValidatedAfterUnzip': True,
    'gatekeeperAccepted': True, 'archive': archive.name,
    'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}, indent=2) + '\n')
PY
echo "Notarized release ready: $archive"
echo "Verification evidence: $evidence"
echo 'No installed application was replaced.'
