# Build review — September 6, 2026

## Verified checkpoints

| Source | Native run | Result |
|---|---|---|
| `2d18c79ca8cf4f2192f4bda0e7c5a4c41e4cc6c8` | [34017142115](https://github.com/eidos-agi/eidos-clips/actions/runs/34017142115) | Mac compile, 12 XCTest tests, five native views, existing synthetic recovery probes passed |
| `53bd1218df166f7485e073873d6a420f77df4b6d` | [34017531698](https://github.com/eidos-agi/eidos-clips/actions/runs/34017531698) | Mac compiled/tests passed; iPad compilation failed because the shared logger used a macOS-only directory API |
| `7aa3f0d3aaf373ecd38c5d6239ff2049489d80d7` | [34017757191](https://github.com/eidos-agi/eidos-clips/actions/runs/34017757191) | Corrected platform path; native Mac and iPad Simulator compilation, contract/crypto/media tests, native views and recovery probes passed |

The current source adds more executable checks and application features after these checkpoints. Its final source/run/artifact evidence is recorded below once available.

## What these checks establish

- Retained segments have digests and decode successfully; corrupted source is rejected.
- Synthetic interrupted packages recover only committed finalized media. Empty pre-checkpoint output is not called a successful recovery.
- Pause removes time across synthetic tracks. Requested audio cannot disappear without failure.
- Trim and remove-selection exports preserve originals; output frame counts/durations are checked.
- Drawing state rejects invalid coordinates, stale epochs, missing sequence numbers and duplicate commands.
- Pairing channels derive matching comparison codes, reject replay/tampering and cannot be opened by an unrelated key.
- Optional capability disable and cancelled/stale job gates are exercised.
- Diagnostics reject unapproved fields and text payloads.

## What remains unproven

Real screen, microphone, system audio, camera, Pencil, radio transport, palm rejection, real-device latency, mixed-DPI/rotated/negative-origin display geometry, screen lock/sleep/device route changes, two-hour A/V alignment, actual quit/reopen capture behavior, VoiceOver, battery/memory/performance and power-loss durability require physical runs. Simulator compilation and native fixture renderings do not close those cases.

The macOS artifact is development/ad-hoc signed. Company Developer ID signing, notarization/stapling and clean-Mac Gatekeeper validation require the Eidos signing keychain. The iPad companion needs separate iOS development provisioning. Neither private signing environment is available in this authoring session.
