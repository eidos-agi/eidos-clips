# Build review — September 6, 2026

## Verified checkpoints

| Source | Native run | Result |
|---|---|---|
| `2d18c79ca8cf4f2192f4bda0e7c5a4c41e4cc6c8` | [34017142115](https://github.com/eidos-agi/eidos-clips/actions/runs/34017142115) | Mac compile, 12 XCTest tests, five native views, existing synthetic recovery probes passed |
| `53bd1218df166f7485e073873d6a420f77df4b6d` | [34017531698](https://github.com/eidos-agi/eidos-clips/actions/runs/34017531698) | Mac compiled/tests passed; iPad compilation failed because the shared logger used a macOS-only directory API |
| `7aa3f0d3aaf373ecd38c5d6239ff2049489d80d7` | [34017757191](https://github.com/eidos-agi/eidos-clips/actions/runs/34017757191) | Corrected platform path; native Mac and iPad Simulator compilation, contract/crypto/media tests, native views and recovery probes passed |
| `07cd5ddc55d96a36057f22f5af70485c5e1f3192` | [34018312819](https://github.com/eidos-agi/eidos-clips/actions/runs/34018312819) | 14 XCTest tests, Mac/iPad compilation, native local drawing/disable/shortcut checks and synthetic recovery probes passed |
| `e3f8fc3e00779a220bbb1e8039c916a3ac1c7d96` | [34018703977](https://github.com/eidos-agi/eidos-clips/actions/runs/34018703977) | 15 XCTest tests, four Python diagnostic tests, Mac/iPad builds, real iPad Simulator launch/screenshots, six Mac native renders/adapter checks, synthetic recovery probes passed |

[Application, companion and evidence artifact](https://github.com/eidos-agi/eidos-clips/actions/runs/34018703977/artifacts/9984848025) contains the Mac development ZIP, iPad Simulator ZIP, logs, renders and JSON evidence. Artifact digest: `sha256:7dbcecee7c1489a2db7197f6e14b340a29fa0943e4bc5d14569d4b07839bf951`; GitHub currently retains it until September 20, 2026.

The following cleanup adds preparation-cancel/quit behavior, input-disconnect observers, removal of the obsolete large recording view, and dirty-build provenance. Main is advanced only after its native workflow succeeds.

## What these checks establish

- Retained segments have digests and decode successfully; corrupted source is rejected.
- Synthetic interrupted packages recover only committed finalized media. Empty pre-checkpoint output is not called a successful recovery.
- Pause removes time across synthetic tracks. Requested audio cannot disappear without failure.
- Trim and remove-selection exports preserve originals; output frame counts/durations are checked.
- Drawing state rejects invalid coordinates, stale epochs, missing sequence numbers and duplicate commands.
- Pairing channels derive matching comparison codes, reject replay/tampering and cannot be opened by an unrelated key.
- Optional capability disable and cancelled/stale job gates are exercised.
- Diagnostics reject unapproved fields and text payloads. Four Python tests include a real local Git worktree/push/ack/retry/collision round trip against a bare fixture repository; no public GitHub report was uploaded by that test.
- The iPad companion installed and launched in Simulator. Its evidence explicitly says `networkPaired:false` and `pencilInputExercised:false`.
- Native UI smoke routes pointer operations into the Mac overlay renderer and verifies optional-module disable behavior. It does not inject physical mouse/Pencil input or capture that overlay through ScreenCaptureKit.

## What remains unproven

Real screen, microphone, system audio, camera, Pencil, radio transport, palm rejection, real-device latency, mixed-DPI/rotated/negative-origin display geometry, screen lock/sleep/device route changes, two-hour A/V alignment, actual quit/reopen capture behavior, VoiceOver, battery/memory/performance and power-loss durability require physical runs. Simulator compilation and native fixture renderings do not close those cases.

The macOS artifact is development/ad-hoc signed. Company Developer ID signing, notarization/stapling and clean-Mac Gatekeeper validation require the Eidos signing keychain. The iPad companion needs separate iOS development provisioning. Neither private signing environment is available in this authoring session.
