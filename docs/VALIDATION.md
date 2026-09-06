# Validation and release evidence

Nothing in this file has passed yet. The current change contains documentation only. Source findings are in [BASELINE-AND-DECISIONS.md](BASELINE-AND-DECISIONS.md); these cases define the evidence required before claiming the successor works.

## Test layers

- Core tests: state transitions, timeline math, manifest/journal reconciliation, geometry, path containment, and job idempotency. Use deterministic media and fault injection.
- Native integration tests: encode/decode known screen/audio fixtures, repeated start/stop, export, interrupted storage, and permission/error adapters.
- Physical Mac sessions: real permissions, displays, actual camera/mic devices, Bluetooth, echo/double-talk, lock/sleep, Gatekeeper, and long recording.
- Browser sessions in M6: actual OS/browser/codec combinations, background capture, quota, reload, and exported playback.

Tests should prove a user-visible outcome or safety invariant. Record the failing fixture before fixing a consequential bug. A unit test with a mocked writer is insufficient proof of playable recovered media.

## Acceptance matrix

| ID | Scenario | Required outcome | Gate |
|---|---|---|---|
| V01 | Fresh install with screen permission denied | No capture; clear route to the necessary OS setting; retry succeeds without stale state | M1/M5 |
| V02 | Camera denied/unavailable; screen and mic allowed | Optional camera stays off and deliberate screen/mic recording works | M2 |
| V03 | Selected mic denied/unavailable | Explain before start; no silent fallback to an apparently complete narrated recording | M2 |
| V04 | Start twice, Stop twice, Stop while preparing | One owner/session; resources close; one truthful terminal outcome | M1 |
| V05 | Source-ended callback races with Stop/Quit | Exactly one finalization; no duplicate export, invalid writer append, or deletion | M1 |
| V06 | Ten start/stop cycles | Playable clips, released devices, stable resource use | M1 |
| V07 | Inject start/append/finalize failure | Error preserved; no false Saved; recoverable media retained | M1 |
| V08 | Disk fills during capture/export | Stop while finalization reserve remains; original/verified portions retained | M1 |
| V09 | Destination becomes read-only or disappears | Local recording survives; handoff/export can retry | M1/M4 |
| V10 | Process killed before/after varied checkpoints | Reopen and decode through the verified checkpoint; report retained bounds honestly | M0/M1 |
| V11 | Partial/corrupt manifest or orphan media segment | Recovery reconciles journal and files without overwriting the original | M1 |
| V12 | Normal Quit during capture | Safely finalize or retain a recoverable session before termination | M1 |
| V13 | Pause/resume repeatedly on a static screen | Paused time absent across all tracks; no resume gap or timestamp reversal | M2 |
| V14 | First audio precedes first video; late/out-of-order callback | Valid timeline, bounded handling, playable output | M1/M2 |
| V15 | Change system wall clock during recording | Media time and elapsed timer stay monotonic | M1 |
| V16 | Two-hour call with known sync markers | All selected tracks present; A/V offset within target at beginning/end and no unexplained growth | M2/M5 |
| V17 | Speakers, wired headphones, AirPods, dock audio | Both sides intelligible; processing mode accurate; overlap speech not forcibly suppressed | M2/M5 |
| V18 | Mic/camera off during recording | Disabled input stops capture/retention as specified; final media and UI agree | M2 |
| V19 | Device unplug or Bluetooth route change | Explicit interruption/reselection; no unrelated device silently selected | M2 |
| V20 | Lock, sleep, wake, or display removal | Stop new capture, retain partial session, deliberate resume/finish on return | M2 |
| V21 | Retina + non-Retina displays, negative origins, scaled display | Source/bubble coordinates agree between preview and decoded output | M2 |
| V22 | Display, window, and region; source resize/minimize | Correct capture bounds, clear unsupported/interrupted state, no unrelated content leakage | M2 |
| V23 | Open menus/dialogs/control windows while recording | App chrome absent from encoded frames; camera appears once | M2 |
| V24 | Start, stop, and operate recording with keyboard/VoiceOver | Controls named, focus predictable, state conveyed without relying on color | M2/M5 |
| V25 | Finish → preview → trim → rename → export | Correct selected frames/duration, playable audio mix, original unchanged | M3 |
| V26 | Record again before exporting the last take | Earlier clip remains accessible and recoverable | M3 |
| V27 | Delete, undo/restore, and restart | Recoverable trash behavior; permanent deletion requires explicit action | M3 |
| V28 | Move package; missing export; catalog deleted | Relative references survive; missing items explained; index rebuilds | M3 |
| V29 | Export while another capture is active | Bounded workload; recording not starved; progress remains truthful | M3/M5 |
| V30 | Cross-volume folder copy, existing filename, full destination | Verify copy and resolve collisions; retain original; no partial final filename | M4 |
| V31 | Offline sync folder; retry; app restart mid-copy | State is Copied to folder or failed, never unverified Uploaded; retry is idempotent | M4 |
| V32 | Paths with spaces, quotes, dollar signs, Unicode, traversal, symlinks | Literal paths handled; approved roots enforced; no shell execution or escape | M4 |
| V33 | CLI double request, stale session, unpaired client | Shared UI semantics; structured conflict/denial; no hidden capture | M4 |
| V34 | Completion event replay after consumer crash | Dedupe by event/artifact identity; one completed job effect; delivery recoverable | M4 |
| V35 | Disable network during capture/review/export | Local workflow works; optional transfers retain retry state | M4/M5 |
| V36 | Install the actual signed download on a clean Mac | Correct identity, notarization/staple accepted, permissions usable, no xattr workaround | M5 |
| V37 | 1080p and higher-resolution playback in target players | MP4 decodes and seeks; both voices present; unsupported presets not advertised | M5 |
| V38 | 60-minute memory/CPU/disk observation and two-hour soak | No duration-dependent memory growth; resource targets reported with hardware/configuration | M5 |
| V39 | Browser reload/crash, quota exhaustion, ordered chunk recovery | Recover only proven playable content; visible export state; no unlimited-memory fallback | M6 |
| V40 | Browser backgrounding, sharing stopped externally, multi-display PiP | Recording remains valid where supported; unsupported bubble/audio configurations are unavailable or clearly labeled | M6 |
| V41 | Browser launch port conflict and local HTTP requests | Loopback only; asset allowlist/containment; do not open another process's server | M6 |
| V42 | Browser canceled save, download fallback, Record another | No unverified Saved label and no accidental loss of an unexported draft | M6 |

## Targets and how to measure them

| Measure | Proposed target | Method |
|---|---|---|
| Setup time | Returning user to active capture ≤10 seconds, excluding OS prompts | Screen-observed task timing with saved presets |
| Review latency | Five-minute 1080p30 demo preview ready ≤5 seconds after Stop | Measure Stop command to successful seek/playback |
| A/V offset | ≤100 ms at start/end of a two-hour session | Synthetic flash/click and separately identifiable audio markers; repeat on actual routes |
| Recovery bound | ≤10 seconds uncommitted media after process kill, subject to M0 proof | Vary kill point; decode recovered frames/audio and compare last source marker; report worst result |
| Capture memory | <500 MB RSS for standard 1080p30; no sustained growth with duration | Sample RSS at minute 5/30/60; compare end-of-session baseline and repeated sessions |
| Recording continuity | No unexplained gap >250 ms in a moving test scene or chosen audio | Decode timestamps plus identifiable frame/audio fixtures; distinguish deliberate pauses |
| File size | Display measured estimate per preset | Compare actual bytes/minute; budget extra original tracks, edits, and export copies |

If a target fails, narrow supported configuration or improve the implementation. Do not replace an unmet target with an unqualified performance claim. Recovery after sudden power loss and unreliable external disks needs additional evidence beyond process termination.

## Hardware matrix

Primary dogfood hardware should include an Apple Silicon laptop and desktop, built-in camera/mic/speakers, a USB microphone or camera, wired headphones, Bluetooth headphones, and an external display at a different scale. Run the oldest supported macOS and the current supported release. Do not record these runs as completed until hardware is available and evidence exists.

Use QuickTime Player plus supported desktop Chrome/Edge playback for exported MP4 compatibility. Test Windows playback explicitly before promising recipient compatibility there. For M6 record exact browser build, OS, MIME type, selected surface, audio capability, PiP configuration, and quota policy. Browser feature detection does not replace recording/playback tests.

## Evidence record

Each gate stores an evidence record with: work package and case IDs; source commit; build artifact SHA-256; environment; inputs; expected and observed outcome; pass/fail/blocked; logs stripped of secrets; synthetic output artifact hashes; and known limits. Use `docs/evidence/` for small reports and CI/release artifacts for large synthetic media. Do not commit binary recordings or personal call material.

M5 requires all applicable native cases passed, all recording-loss/privacy/corruption blockers closed, and documentation matching the actual shipped support matrix. M6 has its own gate. A documentation check verifies plan consistency only and cannot count as a product test.
