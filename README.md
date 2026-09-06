# Eidos Clips

**Show it. Keep it. Put it to work.**

[![CI](https://github.com/eidos-agi/eidos-clips/actions/workflows/native.yml/badge.svg)](https://github.com/eidos-agi/eidos-clips/actions/workflows/native.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Eidos Clips is a **free, MIT-licensed** native Mac screen recorder. Capture your screen, camera, microphone, and system audio; review and trim the result; keep an ordinary video file. No account, no subscription, no required backend.

**Status: first native prototype.** Physical Mac validation is still pending. See [implementation status](docs/IMPLEMENTATION.md). A green synthetic test is not evidence that real screen, camera, microphone, or speaker capture works.

**Next:** a compact Loom-style panel, region picker, Clips UI included in the recording, and diagnostic logs — [docs/WANT.md](docs/WANT.md).

## Build and release

The app now separates **New recording**, **Your clips**, and **Review clip**. Recording has one primary action and optional input switches. The library has thumbnails and title search. Review provides playback, title editing, trim sliders, export, and sharing.

On a Mac with Xcode 16.4 selected:

```sh
swift test
bash scripts/build-app.sh
```

This produces `dist/EidosClips-Development-macOS.zip`, containing **Eidos Clips Dev** with a separate development bundle identity. It is an engineering artifact, not a notarized download.

For an installable company release, use a clean checkout on the Eidos signing Mac:

```sh
bash scripts/release-app.sh
```

Local Mac agents: follow the [build, signing, and verification handoff](docs/LOCAL-AGENT.md) for the exact checkout procedure, artifact delivery, and remaining physical tests.

The release script uses the existing **Developer ID Application: Eidos AGI LLC (Y6CQ4SWPWM)** identity and **eidos-notary** keychain profile, enables hardened runtime and camera/mic entitlements, submits to Apple, staples the accepted ticket, verifies Gatekeeper, and repacks the stapled application. It refuses an unsigned fallback and never replaces an installed app. See [signing and release](docs/SIGNING.md), grounded in Eidos's desktop build repository. The signed release still requires execution on that Mac; the Linux authoring session and ordinary CI runner do not have its private key.

Choose a display, select optional inputs, then Start recording. Pause and Finish are also available in the menu bar. Your clips stay under `~/Movies/Eidos Clips/`. Click a clip to review or recover completed media. Trim exports keep the original.

Current capture is **whole display only**, at most 1920 pixels wide at a nominal 30 fps. Camera uses a floating preview window on that display. Window/region capture, device pickers, meters, live mute/camera controls, remembered presets, trash, and agent handoff remain planned. The app prevents new capture while exporting.

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
| [Next: compact capture](docs/WANT.md) | Include Clips in the recording, small HUD, region picker, diagnostic logs |
| [Contributing](CONTRIBUTING.md) | Build, tests, and how to send a change |

## Delivery sequence

M0 technical proof → M1 trusted recording → M2 capture experience → M3 review and clips → M4 handoff and automation → M5 signed native release. M6 adds the browser edition after the native release gate.

The first usable internal build is M1. The first complete everyday workflow is M3. A notarized download still needs the signing Mac; see [LOCAL-AGENT.md](docs/LOCAL-AGENT.md).

## License

[MIT](LICENSE). Copyright 2026 Eidos AGI LLC. Free for anyone to use, copy, modify, and ship.

## Heritage

Not Loom is the product reference. No upstream application code, artwork, or binary was copied. Any future code reuse must keep the applicable upstream MIT notices.
