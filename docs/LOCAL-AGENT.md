# Local Mac agent handoff

Build the current `main` of `eidos-agi/eidos-clips` into a company-signed, notarized ZIP using the existing Eidos signing Mac. Return the artifact and verification evidence to Daniel. The native application and release scripts are committed; actual company signing and physical capture validation are still pending.

Read [SIGNING.md](SIGNING.md), [IMPLEMENTATION.md](IMPLEMENTATION.md), and [VALIDATION.md](VALIDATION.md) before executing. The signing reference is [eidos-desktop-app-builder](https://github.com/eidos-agi/eidos-desktop-app-builder/tree/958661919e65bb8f066cdcee73a0e34293eaff1e), especially its identity matrix and credential-custody instructions. Use applicable local agent instructions as well.

## 1. Fetch and isolate the exact source

Use the existing authenticated Clips checkout. Preserve local work and installed applications. Fetch `main` and create a separate detached worktree so unrelated edits cannot enter the release:

```bash
set -euo pipefail
git fetch origin main
clips_source_sha="$(git rev-parse refs/remotes/origin/main)"
clips_release_root="$(mktemp -d "${TMPDIR:-/tmp}/eidos-clips-handoff.XXXXXX")"
git worktree add --detach "$clips_release_root/source" "$clips_source_sha"
cd "$clips_release_root/source"
printf 'Building source commit: %s\n' "$clips_source_sha"
git status --short
```

If no checkout exists, clone `https://github.com/eidos-agi/eidos-clips.git` into a new directory using existing GitHub authentication, then follow the steps above. Do not reset or clean another checkout. Record the resolved full SHA; a branch name alone is insufficient build provenance.

## 2. Use the existing company signing setup

Run on the Apple Silicon signing Mac documented as `daniel-laptop-01`. Verify the selected Xcode toolchain; CI passed with Xcode 16.4 / Swift 6.1.2. Record any different toolchain instead of assuming equivalent results.

- Signing identity: `Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)`.
- Team: `Y6CQ4SWPWM`.
- Existing notary keychain profile: `eidos-notary`.
- If its local name differs, set `CLIPS_NOTARY_PROFILE` to the existing profile name only.

Do not create/export a signing certificate, move a private key, paste credentials into chat, or add signing secrets to CI. The release script checks keychain availability. If the existing keychain/profile cannot be used, report the exact failed step with sanitized output; do not substitute ad-hoc signing or disable Gatekeeper.

From the new worktree:

```bash
set -euo pipefail
mkdir -p dist
{ sw_vers; uname -m; xcodebuild -version; swift --version; } > dist/local-toolchain.txt
bash scripts/release-app.sh 2>&1 | tee dist/local-release.log
```

The script runs tests, builds and signs the app with hardened runtime, submits it to Apple, requires `Accepted`, staples the ticket, verifies Gatekeeper, and repeats staple/Gatekeeper checks after extracting the final ZIP. It never replaces an installed application. A signing or notarization failure is a failed release; there is no unsigned fallback.

## 3. Preserve and return the verified release

Successful output:

- `dist/EidosClips-Notarized-<12-character-source-SHA>.zip`
- The matching `.zip.sha256` file.
- `dist/release-<full-source-SHA>/`, including `release.json`, notarization, signature, staple, and Gatekeeper evidence.
- `dist/local-toolchain.txt` and `dist/local-release.log`.

Check `release.json` against the checkout SHA and archive hash. Copy the outputs into a durable local release folder before removing the temporary worktree. Return that folder's absolute path and the ZIP to Daniel using the available local handoff mechanism. Do not publish a GitHub release, change repository access, upload personal recordings, or send messages to other people as part of this handoff.

## 4. Separate signing verification from physical Mac acceptance

Signing success does not establish that screen, microphone, camera, or system audio capture works. The successful [CI run for source `85e37ca`](https://github.com/eidos-agi/eidos-clips/actions/runs/34010493990) established native compilation, seven tests, four native UI renders, and synthetic export/recovery checks. It did not use physical capture hardware. The handoff documentation adds no new hardware evidence.

Where a permitted test environment and the needed devices are available, test the actual notarized archive with a non-sensitive test scene. Keep source recordings and diagnostic evidence locally. Do not overwrite an existing installed app or reset its privacy permissions without authorization. Do not strip quarantine attributes or use a Gatekeeper override. If a check needs user interaction, a fresh Mac/account, or an unavailable device, mark it blocked or untested and identify what is needed.

Prioritize these checks from [VALIDATION.md](VALIDATION.md):

| Cases | Local evidence needed |
|---|---|
| V36 | Open the actual downloaded, quarantined signed build on a clean Mac/account, verify identity and usable permission prompts; command-line assessment on the signing Mac alone does not close this case. |
| V01–V03 | Screen permission denial/retry; unavailable or denied optional mic/camera; no false successful narrated recording. |
| V06, V12–V13 | Ten start/stop cycles, normal Quit during capture, repeated pause/resume on a static screen; inspect exported picture and sound. |
| V23–V25, V37 | App chrome excluded, camera appears once, keyboard/VoiceOver behavior, finish/play/trim/rename/export, originals preserved, QuickTime playback. |
| V16–V17, V19–V21, V38 | Two-hour sync/soak, resource measurements, actual audio routes, device removal, lock/sleep/wake, mixed-scale displays. These remain unproven until performed. |

Whole-display capture is currently implemented, capped at 1920 pixels wide and nominal 30 fps. Window/region capture, input device pickers, live input toggles, trash, and agent handoff are planned. Do not claim these work, or mark a broader validation case passed based on only its implemented subset. Recovery from committed synthetic checkpoints also does not prove orphan/manifest reconstruction, sudden power-loss recovery, or real-device failure handling.

## Return a concise result

Report the source SHA, machine/macOS/toolchain, ZIP path and SHA-256, Apple notarization result, company identity, and final extracted-app staple/Gatekeeper results. List physical cases as passed, failed, blocked, or untested with observed evidence. For a failure, include the reproduction and sanitized log location. Do not mark M5 complete merely because the signed app builds or opens. Leave code changes and further release/distribution actions for a separate instruction.
