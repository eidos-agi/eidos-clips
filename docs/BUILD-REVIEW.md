# Build review — September 6, 2026

## Verified checkpoints

| Source | Native run | Result |
|---|---|---|
| `2d18c79ca8cf4f2192f4bda0e7c5a4c41e4cc6c8` | [34017142115](https://github.com/eidos-agi/eidos-clips/actions/runs/34017142115) | Mac compile, 12 XCTest tests, five native views, existing synthetic recovery probes passed |
| `53bd1218df166f7485e073873d6a420f77df4b6d` | [34017531698](https://github.com/eidos-agi/eidos-clips/actions/runs/34017531698) | Mac compiled/tests passed; iPad compilation failed because the shared logger used a macOS-only directory API |
| `7aa3f0d3aaf373ecd38c5d6239ff2049489d80d7` | [34017757191](https://github.com/eidos-agi/eidos-clips/actions/runs/34017757191) | Corrected platform path; native Mac and iPad Simulator compilation, contract/crypto/media tests, native views and recovery probes passed |
| `07cd5ddc55d96a36057f22f5af70485c5e1f3192` | [34018312819](https://github.com/eidos-agi/eidos-clips/actions/runs/34018312819) | 14 XCTest tests, Mac/iPad compilation, native local drawing/disable/shortcut checks and synthetic recovery probes passed |
| `e3f8fc3e00779a220bbb1e8039c916a3ac1c7d96` | [34018703977](https://github.com/eidos-agi/eidos-clips/actions/runs/34018703977) | 15 XCTest tests, four Python diagnostic tests, Mac/iPad builds, real iPad Simulator launch/screenshots, six Mac native renders/adapter checks, synthetic recovery probes passed |
| `e293e837be9a222449ff716f3356f6332ce1c75d` | [34019790388](https://github.com/eidos-agi/eidos-clips/actions/runs/34019790388) | Final 0.3.0 application source: 15 XCTest tests, four Python tests, both builds, iPad Simulator launch, native render/adapter checks and recovery probes passed; includes committed-key pairing v2, pause-scoped preview and responsive job cancellation |

## Current development artifacts

[Download the Mac development app, iPad Simulator companion and evidence](https://github.com/eidos-agi/eidos-clips/actions/runs/34019790388/artifacts/9985191407).

- Application source: `e293e837be9a222449ff716f3356f6332ce1c75d`, advanced to main after its complete workflow succeeded.
- Artifact digest: `sha256:cc5a714c797d18778d75ddacccfc71a715cf5b35c9f9f8cc1afcea763153d3e4`.
- Current GitHub expiration: September 20, 2026. Preserve needed artifacts locally before then.
- The Mac ZIP is development/ad-hoc signed, not notarized. The companion ZIP is for Simulator, not a provisioned physical iPad.
- Earlier artifact links in workflow history are superseded. Build both devices from current main for pairing protocol v2.

The final code includes preparation cancellation, clean job cancellation on Quit, explicit input/display-loss interruption, removal of the obsolete studio recording page, dirty-build provenance, cancellation-aware hashing/decoding, and recording-clock cutoff at Stop. The following documentation-only commit updates this evidence link; it does not change application code.

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
