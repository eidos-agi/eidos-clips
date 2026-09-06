# Baseline review and decisions

Reviewed 2026-09-06. Destination `eidos-agi/eidos-clips` was an empty private repository. Reference source is [Not Loom at d58e7eb](https://github.com/eidos-agi/notloom-public/tree/d58e7ebc33e7e9a4ea2e7d3dfe3aeb9155d0b80e). The reference repository remained at that SHA when rechecked for this plan.

The assessment comes from source inspection of the native Swift app, browser HTML, build scripts, launchers, README, plist, and bundled executable metadata. The native app was not run in this environment. The earlier browser preview attempt was blocked, so no interactive UI/audio/display behavior is claimed as tested. The plan separates observed implementation choices from risks requiring reproduction.

## Preserve what works conceptually

Keep local files, no required account, a compact native utility, camera overlay, excluded recording controls, pause/resume, system/mic capture, and compatibility with user-owned destinations. Reuse justified code with attribution instead of assuming every component needs replacement. Introduce modules and tests around media/lifecycle risk, without adding a web service or heavyweight desktop runtime.

## Findings carried into the plan

Native references below point to [native/main.swift](https://github.com/eidos-agi/notloom-public/blob/d58e7ebc33e7e9a4ea2e7d3dfe3aeb9155d0b80e/native/main.swift); browser references point to [index.html](https://github.com/eidos-agi/notloom-public/blob/d58e7ebc33e7e9a4ea2e7d3dfe3aeb9155d0b80e/index.html).

| ID | Observed source behavior | Consequence / uncertainty | Planned response |
|---|---|---|---|
| B01 | Native append return values are ignored; stopRecording does not verify completed status after finishWriting | A finalization failure can reach the normal finished flow; exact failure cases require native reproduction | R10–R12; V07 |
| B02 | App Quit directly terminates; no application termination handler finalizes active capture | Interrupted-file loss risk; recovery behavior is unproven | P02, R10–R11; V10–V12 |
| B03 | Browser accumulates all chunks until finalization; resetToSetup clears the blob without a saved check | No durable draft recovery; starting another take can discard an unsaved result | W60–W61; V39/V42 |
| B04 | Native audio tap reduces mic volume toward 0.15 while far-end audio is active, including voice-processing mode | Deliberate suppression during overlapping speech; real audibility/echo quality requires hardware tests | P03, U22; V16–V19 |
| B05 | cameraTapped only hides/shows the window; capture session continues | “Camera Off” does not release camera capture | U22; V18 |
| B06 | Native picks main display; browser PiP mapping assumes a display layout | No native user source picker; browser cannot guarantee arbitrary monitor mapping | U20–U21, W61; V21–V23/V40 |
| B07 | Pause offset is updated by video callbacks; audio reads the shared offset independently | Resume ordering/static-frame timing needs explicit multi-track tests; no measured drift claim | R10, P03, U22; V13–V16 |
| B08 | Upload monitoring calls fileproviderctl evict and treats nonzero file size/zero allocated blocks as uploaded | No generic provider upload receipt; provider-specific behavior is unverified | I40; V30–V31; no auto-eviction in 1.0 |
| B09 | scheduleEviction interpolates a configured folder path into a bash command string | Shell metacharacters can be interpreted; destination paths should remain literal data | I40; V32; remove detached shell eviction |
| B10 | Native finishFlow offers Keep/Re-record without a playback preview and removes the original on Re-record | Weak review experience and a destructive retake flow | F30–F31; V25–V27 |
| B11 | Browser download fallback displays Saved immediately after initiating a download | The application has no actual download-completion confirmation | W61; V42 |
| B12 | Mac browser launcher uses python http.server without an explicit loopback bind | Server can bind beyond localhost; directory exposure and port ownership require correction | W61; V41 |
| B13 | Native binary inspected as ARM64; build script defaults to ad-hoc signing; README suggests quarantine removal | Public distribution and supported architectures need real release engineering | P01, Q50–Q51; V36–V38 |
| B14 | Reviewed tree has no automated test suite/CI, and both implementations are large single files | Current recording guarantees lack repeatable evidence; single-file contribution rule hinders separation | P01 onward; core regression suite and milestone evidence |

Additional lifecycle concerns to reproduce in M0/M1: partial start cleanup, concurrent stop/write callbacks, ring-buffer locking/allocation under audio deadlines, a microphone device held by multiple capture paths, and codec/container behavior after crashes. Treat these as targeted test risks until measured.

The source review is a planning input, not a claim that all affected scenarios were reproduced or that Eidos Clips contains the same defects. No fixes have been implemented in this repository yet.

## Proposed decisions

| Decision | Choice | Rationale / revisit condition |
|---|---|---|
| D01 Product | Small local recorder with a complete capture/review/export loop | A short path to a usable artifact is the product's value |
| D02 Platform | Native Apple Silicon Mac first; proposed macOS 14 floor | Concentrate hardware/media validation; confirm floor in M0; Intel/browser have separate gates |
| D03 Structure | Thin native app plus small core modules; minimal dependencies | Test media/state independently; preserve a small app without a single-file constraint |
| D04 Capture | Explicit screen/camera composition using a common preview scene | Supports display/window/region consistently; M0 renderer spike validates performance |
| D05 Audio | Separate retained mic/system tracks and a normal mixed export | Preserves repair options and simultaneous speech; processing remains evidence-driven |
| D06 Recovery | Journal plus proven fragmented/segmented media | Choose from decoded crash recovery evidence, not API naming; M0 resolves the format |
| D07 Storage | Local packages, ordinary exports, rebuildable catalog | No backend or database server required; later indexing based on measured need |
| D08 Handoff | Copy/verify first; keep local original; truthful completion levels | Folder presence is not remote durability; defer eviction and provider adapters |
| D09 Agents | Opt-in local commands and durable events with scoped access | Works with replaceable agents; no required AI call or hidden recording |
| D10 Browser | Separate later edition with explicit limitations | Browser permissions, audio, PiP, codecs, and storage have different guarantees |
| D11 Distribution | Organization-controlled signing, notarized release, stable bundle ID | Installation must not require bypass instructions; preserve upstream license obligations |
| D12 Network | Capture/review/export offline; explicit optional integrations | Keep user control and accurate privacy copy |

## Decisions still requiring evidence or release input

| Question | Default and resolution point |
|---|---|
| Fragmented file or short finalized segments? | P02 selects after recovery and continuity tests; default target ≤10-second verified checkpoints |
| Oldest macOS and Intel support? | P01 tests the proposed macOS 14/Apple Silicon target; do not advertise untested platforms |
| Echo cancellation routing and mic API? | P03 measures actual speakers/headphones/Bluetooth; newer API only with a supported fallback |
| Who owns signing and what bundle ID? | Use an organization-controlled Apple identity; settle before Q50, with all non-credential work prepared first |
| Public release and licensing of new code? | Repo stays private; preserve MIT notices for any upstream reuse; settle release policy before distribution |
| Preferred direct storage or transcript provider? | None required; folder/share-sheet workflow ships first; configure only for a demonstrated need |

## Primary technical references

These were checked during planning on 2026-09-06. They support the API constraints cited in the architecture; they do not establish that our implementation passes them.

- [Apple: ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) — native screen and audio capture framework.
- [Apple: ScreenCaptureKit additions at WWDC24](https://developer.apple.com/videos/play/wwdc2024/10088/) — microphone stream output and direct recording callbacks; availability must be checked against the chosen deployment target.
- [Apple: AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter) — writer lifecycle and per-output ownership.
- [Apple: finishWriting](https://developer.apple.com/documentation/avfoundation/avassetwriter/finishwriting(completionhandler:)) — completion status must be inspected.
- [Apple: movieFragmentInterval](https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval) — partially written media capability to evaluate in the recovery spike.
- [Apple: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime) — release packaging requirements.
- [MDN: MediaStream Recording API](https://developer.mozilla.org/en-US/docs/Web/API/MediaStream_Recording_API) — slices may require reassembly before playback; error handling is explicit.
- [MDN: dataavailable](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder/dataavailable_event) — timeslice timing is not exact.
- [Chrome/web.dev: Origin private file system](https://web.dev/articles/origin-private-file-system) — browser-local storage is quota-bound and removable with site data.

Review this decision record at each milestone. When evidence changes a choice, record the replacement, measured reason, affected contracts, and migration impact. Keep product claims aligned with the latest validated release.
