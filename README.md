# Eidos Clips

**Show it. Keep it. Put it to work.**

Eidos Clips is a native screen recorder prototype for clear demonstrations, walkthroughs, and call recordings. Capture your screen, camera, microphone, and system audio; review and trim the result; keep an ordinary video file; optionally hand it to a destination or agent you choose.

**Status: first native prototype; physical Mac validation and release signing are pending.** This repository now includes the application, core/media tests, development packaging, and a macOS CI workflow. See [implementation status](docs/IMPLEMENTATION.md) for implemented features and the remaining gates. A green synthetic test is not evidence that real screen, camera, microphone, or speaker capture works.

## Build and try it

On a Mac with Xcode 16.4 selected:

```sh
swift test
bash scripts/build-app.sh
```

Unzip `dist/EidosClips-macOS.zip` and open `EidosClips.app`. The app is development signed by default; this is not a notarized download. CI artifacts include the zipped app, its SHA-256, toolchain information, test log, and synthetic recovery evidence when all checks pass. The development bundle ID is `org.eidos.clips`, pending ownership confirmation before release.

Choose a display and grant Screen Recording permission in System Settings. Enable the optional microphone, system audio, and camera before pressing Record. Pause/Resume and Stop are also available in the menu bar. Stop validates the recording and opens playback. Use Recover / Open for retained takes, or enter start/end seconds and Export trim. Files remain under `~/Movies/Eidos Clips/`; Share opens the macOS share sheet for an exported file.

Current capture is **whole display only**, up to 1920 pixels wide at a nominal 30 fps. Camera uses a floating preview window on that display. Window/region capture, device pickers, meters, live mute/camera controls, remembered presets, search/trash, and agent handoff are still planned. The app prevents starting another capture while an export is running.

## The product we are building

- A compact native Mac app with a screen/window/region picker, camera bubble, audio meters, and remembered settings.
- Recording that reports failures, preserves recoverable material, and never labels an unsuccessful save as complete.
- A finish screen with playback, trim, rename, export, and a small searchable collection of your clips.
- Local capture and export without an account, subscription, telemetry service, or required backend.
- Optional folder handoff and a local agent interface, with explicit destination and capture permissions.

The first supported target is **Apple Silicon macOS**, with macOS 14 as the proposed minimum pending the M0 compatibility spike. Browser recording for desktop Chrome/Edge follows the native release. Intel support requires a separate validated build. These are planned support targets, not compatibility claims.

## Read the plan

| Document | Purpose |
|---|---|
| [Product and experience](docs/PRODUCT.md) | Users, recording flows, scope, visual direction, and platform boundaries |
| [Architecture](docs/ARCHITECTURE.md) | Capture pipeline, recording lifecycle, recovery, storage, and provider boundaries |
| [Delivery plan](docs/ROADMAP.md) | Ordered work packages, dependencies, release gates, and next executable work |
| [Validation plan](docs/VALIDATION.md) | Failure tests, real-device scenarios, measurable targets, and evidence requirements |
| [Agent and handoff contract](docs/INTEGRATIONS.md) | Local commands, completion events, project metadata, and destination behavior |
| [Source review and decisions](docs/BASELINE-AND-DECISIONS.md) | Findings from Not Loom, research references, unresolved questions, and rationale |

## Delivery sequence

M0 technical proof → M1 trusted recording → M2 capture experience → M3 review and clips → M4 handoff and automation → M5 signed native release. M6 adds the browser edition after the native release gate.

The first usable internal build is M1. The first complete everyday workflow is M3. Public distribution requires M5; planning this product does not change repository visibility or authorize publishing recordings.

## Heritage

Not Loom provides the reference implementation and product starting point. No upstream application code, artwork, or binary has been copied into this repository. Any future code reuse must retain the applicable upstream MIT copyright and license notices. Eidos Clips will have its own name, icon, bundle identifier, and release artifacts. Repository visibility and a license for new contributions remain explicit release decisions.
