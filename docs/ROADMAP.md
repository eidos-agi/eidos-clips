# Delivery plan

The first native prototype is implemented. No milestone exit gate is complete yet. [Implementation status](IMPLEMENTATION.md) records the current scope, deliberate deviations, and evidence limits. CI produces a source-linked evidence artifact; physical Mac cases remain pending. The ordered work packages below remain the acceptance contract. [FEATURE-MAP.md](FEATURE-MAP.md) supplies user paths and implementation/evidence status; [LOOM-GAPS.md](LOOM-GAPS.md) records broader opportunities for discussion. Neither adds all proposed features to the release gate.

## Milestones

| Milestone | Deliverable and dependency | Exit gate |
|---|---|---|
| M0 — Prove the foundation | Native project, platform floor, upstream reuse inventory, recovery and audio prototypes | Runnable Mac spike, architecture decision with measured tradeoffs, process-kill recovery evidence, and a pinned build toolchain |
| M1 — Trusted recording | M0; display + microphone capture, pause, lifecycle owner, recoverable storage, error reporting, basic MP4 export | First internal build passes normal stop, Quit, repeat commands, disk failure, and crash/reopen tests; no false success |
| M2 — Confident capture | M1; source picker, camera composition, audio tracks/meters, presets, shortcuts, and interruption handling | Display/window/region output matches preview on supported display layouts; double-talk and permission/device scenarios pass |
| M3 — Complete the daily workflow | M2; preview, nondestructive trim, rename, export, clip catalog, recoverable deletion | A user records, reviews, trims, exports, finds, and re-records without losing a take; this is the first full dogfood workflow |
| M4 — Put clips to work | M3; verified folder copies, durable jobs, local commands, and replayable events | Offline/retry/duplicate handoff and local authorization cases pass without deleting the original |
| M5 — Native 1.0 | M4; packaging, signing, notarization, help, accessibility, performance, and release evidence | Full native matrix passes on the shipped artifact; no unresolved recording-loss/privacy/corruption issue; distribution prerequisites are met |
| M6 — Browser edition | After M5; durable drafts, capability matrix, safe launcher, export, and recovery | A separately labeled Chrome/Edge release passes Windows/macOS browser cases; supported behavior is documented per platform |

M1 is for short internal tests with expendable material. M3 is the everyday workflow candidate. Neither carries public release claims before M5. Browser work must not block native reliability. A native Windows app is a separate future decision.

## Work packages

| ID | Work | Depends on | Proof / acceptance |
|---|---|---|---|
| P00 | Inventory any reused Not Loom code; preserve upstream notices and separate artwork/binaries | None | Source provenance record and no inherited release binary |
| P01 | Establish Xcode app + Swift core package; pin SDK and supported OS/architecture | P00 | Fresh build and launch on the declared oldest OS; smoke build in Mac CI |
| P02 | Compare fragmented vs segmented recovery; choose one | P01 | Kill at varied write/checkpoint boundaries; reopen/decode and document maximum observed loss |
| P03 | Verify mic/system capture, sample rates, clocks, and echo behavior | P01 | Two-source fixture and real-device playback; measured drift and double-talk outcome |
| R10 | Implement session command/state owner and cleanup | P02, P03 | Repeated Start/Stop, canceled start, source-ended + Stop races, and normal Quit settle once |
| R11 | Implement recording package, journal, recovery, and export validation | R10 | Interrupted package reopens; completed output has expected tracks and duration |
| R12 | Add storage budgeting and writer failure paths | R11 | Disk-full and permission failures keep completed data and show an actionable error |
| U20 | Build ready panel, scope picker, presets, meters, and permission flow | R12 | Returning-user setup path and denied/missing optional device cases |
| U21 | Implement scene rendering and display/window/region geometry | U20 | Pixel-inspected exports on mixed-DPI layouts; Clips windows inside the selected scope included per WANT.md and camera present once |
| U22 | Complete pause/resume, shortcuts, mute/camera-off, and interruption UI | U21 | Static-screen pause, source unplug, Bluetooth change, lock/sleep, keyboard and VoiceOver cases |
| F30 | Add preview, title, trim, export queue, and retained takes | U22 | Frame/duration-checked trim exports; Record again retains earlier recording |
| F31 | Add small catalog, project/notes search, missing-file and trash handling | F30 | Catalog rebuild from packages; repair stale index; recover an accidental deletion |
| I40 | Implement destination picker, verified copies, retry queue, and source retention | F31 | Cross-volume/offline/destination-full/restart cases; no false Uploaded or Link ready |
| I41 | Implement local CLI, pairing/scopes, and replayable completion events | I40 | Same lifecycle semantics as UI; duplicate-safe command/job handling; unpaired clients denied |
| Q50 | Package signed artifact, notarize/staple, verify installation and branding | I41 | Fresh-machine installation without quarantine-removal instructions; artifact SHA and source SHA recorded |
| Q51 | Complete performance, accessibility, playback, and long-session matrix | Q50 | Release evidence bundle and all native acceptance gates closed |
| W60 | Prototype browser container reconstruction and storage durability | Q51 | Recovery feasibility recorded per actual browser/codec, including quota and reload behavior |
| W61 | Implement and qualify browser edition | W60 | Safe draft/export UX, feature matrix, and supported browser runs |

## Next executable work

The immediate product slice is [WANT.md](WANT.md): compact ready/HUD, include Clips in video while excluding its audio, region selection with Esc cancel, and diagnostic logging. Extend diagnostics toward the structured report/repo feedback design in [DIAGNOSTICS.md](DIAGNOSTICS.md). Its public-report validator and local Git bridge need their own evidence before automatic publication; raw logs are not repository fixtures. Window selection can follow this slice. Broader opportunities remain for discussion in the feature map.

In parallel with that slice, close P00–P03 using the prototype and its CI evidence. Validate the app on a physical Mac and make a two-minute display/microphone recording. Then terminate the process during capture and recover the playable portion. Measure startup, retained duration, A/V alignment, and memory. Record the chosen container/checkpoint design and supported macOS floor. Finish this proof before polishing the library or implementing cloud integrations.

If M0 cannot meet the proposed recovery interval, document the measured limitation and revise the design/target explicitly. Do not carry an unproven guarantee into UI copy or the README. Prefer a narrower working capture mode for M1 over claiming all scopes before M2.

## Release and review rules

Every completed work package needs: code SHA, relevant test results, environment, resulting behavior, and known limitations. Review reusable interfaces at the milestone boundary, not on every cosmetic edit. Add regression coverage for actual failure classes; avoid tests that merely restate implementation.

Use synthetic/public-domain media for test evidence. Record hardware, OS, browser/SDK, resolution, sample rates, duration, and artifact hashes. Real calls and private desktop captures are not suitable repository fixtures.

CI should run formatting/build and meaningful core/integration checks on Mac. Hardware-only cases stay marked pending until performed on a physical supported Mac; a green simulator or headless job cannot substitute for permission prompts, real displays, Bluetooth, and speakers.

The repository became public and MIT-licensed at `1eaf230` on September 6, 2026. The existing company Developer ID and stable release bundle ID are documented in SIGNING.md; executed notarization and clean-install evidence remain required for a trusted binary release. Source publication does not close M5. Missing access to the signing Mac can block binary delivery while code, packaging, tests, and development artifacts continue. Never commit secrets, signing material, raw private diagnostics, or personal recordings.

## Deferred ideas and revisit triggers

| Idea | Revisit when |
|---|---|
| Independent camera originals and post-recording layout | Users repeatedly need to resize/remove the camera after a take, and storage impact is measured |
| Captions, transcript search, summaries, and task extraction | A chosen external/local processor can consume the M4 artifact contract without delaying capture |
| Cursor emphasis, keystroke display, annotations, background treatment | A small design test shows it improves comprehension and does not expose private input |
| Direct storage providers and share-link creation | Folder/share-sheet handoff is insufficient for real use; destination access and credentials are explicit |
| stdio MCP adapter | A real local agent needs discovery beyond the CLI; reuse existing commands/scopes |
| Native Windows/Linux | Sufficient demand justifies OS-specific capture, installer, and device validation |
| Automatic online-only eviction | A provider-specific implementation can prove remote durability and the user chooses that retention behavior |

After each release, review recording failure reports, export/playback failures, recovery outcomes, setup friction, and resource measurements. Diagnostics are local/opt-in. Revisit SDK capabilities at release planning, record the reason for a dependency/platform change, and retire complexity when native APIs demonstrably replace it.
