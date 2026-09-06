# Native prototype status

This is a first executable slice, not completion of M0–M5. The original milestone gates remain in [ROADMAP.md](ROADMAP.md) and [VALIDATION.md](VALIDATION.md).

## What exists

- An AppKit macOS application built with SwiftPM: selected-display recording through ScreenCaptureKit; optional default microphone, system audio, and camera bubble; pause/resume; menu-bar stop and safe finalization on normal Quit.
- One host-clock pause history for every track. A screen-frame cadence holds the last complete image during a static desktop. This needs real capture/latency validation.
- A versioned `.eidosclip` package with independent two-second target video/mic/system segments, SHA-256 verification, file synchronization, and atomic manifest replacement. Only completely finalized and decoded segments enter the manifest.
- Errors from writers and exports are surfaced. A 128 MiB free-space reserve is checked while writing. This is a defensive stop threshold, not a tested disk-full guarantee.
- Checked MP4 export, native playback, title changes, trim to a new file, recent recordings, Finder access, and the macOS share sheet. Originals remain intact. Two audio sources receive equal fixed gain with mix headroom; there is no speech-triggered ducking or echo-cancellation claim.
- A development app bundle, pinned CI action revisions, Xcode 16.4, and tests that use real AVFoundation encoding/decoding on synthetic video and two audio tones.

## Recovery contract and limits

Recover / Open loads the manifest, rejects unsupported schemas, unsafe paths, symlinks and bad digests, fully decodes each committed segment, and exports a new MP4. It never overwrites the package. A process-killed recording retains the `recording` state; that label is not a success claim. Before the first committed video segment, no playable recovery is promised.

Incomplete or orphan segments are retained but not automatically salvaged. A corrupt manifest or committed segment blocks export rather than silently omitting damaged material. There is no journal reconstruction yet. Two seconds is the segment target, **not a proven maximum loss bound**: queue delays, writer finalization, storage failure, and sparse/missing inputs can change retained bounds. Sudden power loss is untested. Segmentation is provisional; the planned fragmented-versus-segmented comparison is still open.

## Evidence mapping

| Automated check | Relevant cases | What a passing run proves |
|---|---|---|
| Clock and state unit tests | Parts of V04, V13–V15 | Pause arithmetic, delayed sample mapping, rejected duplicate state transitions; not capture controller races or physical static-screen behavior |
| Store unit tests | Parts of V07, V11, V32 | Invalid packages and same-size corruption rejected, source bytes retained, traversal/symlinks blocked; not orphan salvage or disk-full behavior |
| Native media XCTest | Parts of V25, V30 | Synthetic video fully decodes; trim duration and existing-destination refusal preserve originals |
| Eight-second, three-track probe with one-second pause | Parts of V13, V25 | Deterministic encode/mix/export/trim frame counts, audio sample counts and duration; not measured acoustic echo, device capture, or A/V marker alignment |
| SIGKILL before first and after one/three video checkpoints | Part of V10 | Committed synthetic video can be decoded after process termination; no-video package refuses false success; originals unchanged |
| Same-size media corruption probe | Parts of V07, V11 | Corruption prevents a completed export and leaves source untouched |

CI uploads the app only after these checks succeed. `foundation-evidence.json` and `swift-tests.log` are authoritative for the actual run, not this list of intended checks. A separate `--ui-smoke` launch opens the real AppKit window, checks that recording/review controls fit and start in an idle state, and saves `ui-smoke.json` plus a rendering of the app's own view. It never starts screen, mic, or camera capture. The media probe is headless and uses synthetic input.

## Scope decisions and open work

The first bundle uses SwiftPM plus a packaging script instead of an Xcode app project. Xcode can open the package for debugging, but oldest-OS launch validation and an organization-controlled signing identity remain open. No upstream source, artwork, or binary was copied; this is a new implementation informed by the Not Loom review.

Camera composition currently relies on an included floating camera window while the rest of the app is excluded from display capture. This is an explicit provisional departure from the planned single scene renderer. It must be checked for occlusion, spaces/fullscreen, mixed DPI, and exactly-once inclusion before being relied on. Window/region capture is unavailable. The camera and microphone use default devices; their switches apply before recording. There are no live mute controls, audio meters, global shortcuts, echo processing, saved presets, search/trash, background export queue, handoff jobs, or local agent control yet. `clips-probe` is a test tool, not the planned user CLI.

Remaining physical Mac gates include fresh permission denial/retry, a two-minute real capture and playback, ten recording cycles, real Quit and source-ended races, actual static-screen pause, mic/camera unplug and route changes, lock/sleep/display removal, mixed-DPI geometry and app-window exclusion, speakers/headphones double-talk, long-session drift/performance, VoiceOver, macOS 14 launch, and signed/notarized clean-machine installation. Disk-full/read-only fault injection and varied checkpoint/power-loss testing also remain open. No milestone is marked complete until its corresponding evidence exists.
