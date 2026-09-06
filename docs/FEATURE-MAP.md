# Eidos Clips feature map

Use this page to discuss what belongs in Clips and to find the real user paths for verification. [ROADMAP.md](ROADMAP.md) orders delivery; [VALIDATION.md](VALIDATION.md) defines acceptance cases. This map connects both to the app a person can operate.

**Implementation batch: September 6, 2026.** The requested modular application is now being implemented, with native CI checkpoints. The machine-readable [delivery ledger](feature-map.json), [execution plan](BUILD-PLAN.md), and [build review](BUILD-REVIEW.md) distinguish executable code, synthetic evidence and physical acceptance. Earlier planning used `1eaf230`; it is no longer the application baseline.

## Read the map

Implementation and evidence are separate:

- **Exists:** an executable path is present in the source. This alone does not mean it works on a physical Mac.
- **Partial:** a usable subset or foundation exists; the named gap remains.
- **Missing:** no user-facing implementation found.
- **Next:** explicitly requested in WANT.md. **Planned:** already in the product/roadmap. **Proposed:** added here for discussion, not silently added to release scope. **Later:** intentionally deferred.
- Evidence names the actual boundary: native build, UI render, synthetic media, physical capture, or signed installation. An untested physical case stays untested.

Poteto's useful idea is to map features by their user entry points, driving steps, observable outcomes, and gotchas. The detail pages follow that shape. This is adapted from the [official pstack feature-map guidance](https://github.com/cursor/plugins/blob/4483dcd246c3212ff38890bd53977c16d7b54fb7/pstack/skills/create-verification-skill/SKILL.md). It does not install pstack or claim to provide an already-verified desktop automation skill.

## Product overview

| User job | Implemented path | Remaining gap | Detail |
|---|---|---|---|
| Get ready quickly | Compact panel, display/region selection, mic/camera device menus, remembered choices, countdown | Preflight preview/test capture, live device changes | [Prepare and record](features/record.md) |
| Stay in control | Floating strip, pause/finish, include Clips UI, global shortcuts, input meters | Physical interruption and accessibility qualification, live mute/camera controls | [Prepare and record](features/record.md) |
| Draw with optional devices | Pointer adapter, shared ink/tools, native iPad companion, scoped pairing/preview | Physical Pencil/radio/geometry evidence; other vendor adapters | [Drawing](features/drawing.md), [iPad](features/ipad-ink.md) |
| Keep useful work | Segmented originals, integrity checks, cache, Recently Deleted/undo | Orphan/manifest repair, full storage policy and physical fault evidence | [Recovery](features/recovery.md) |
| Finish and find it | Playback, title/notes, trim/cut, captions, search, cancellable exports | Projects, full timeline, transcription/search, persistent job queue | [Review](features/review.md) |
| Give it to someone | MP4, native Share, verified copy, portable watch folder | Hosted links/access/revoke, comments/reactions, provider integrations | [Handoff](features/handoff.md) |
| Diagnose and trust it | Typed bounded logs, validated outbox, local Git publisher, native CI, signing scripts | Physical acceptance and actual notarized artifact from signing Mac | [Diagnostics](features/diagnostics.md) |

The primary loop is **prepare → record → finish → review → export or hand off → find later**. Recovery and diagnosis must remain reachable when that loop fails.

## Inventory

| ID | Feature | Implementation now | Scope and evidence |
|---|---|---|---|
| C01 | Compact ready panel | Exists: 420-point ready panel | Native app render; compact panel in CapturePanel.swift |
| C02 | Whole-display selection/capture | Exists: stable display identity, refreshed choices | Native compile; physical reconnect/layout validation remains |
| C03 | Region selection, drag and Esc cancel | Exists: per-display drag picker, Esc cancel, normalized crop | Region model bounds tests; physical mixed-DPI/output validation remains |
| C04 | Window selection/capture | Missing | Later than the next brief; still in the wider M2 plan |
| C05 | Exact capture preview/border | Partial: scoped remote preview during capture | No preflight preview or persistent crop border yet |
| C06 | Mic, system audio, camera switches before start | Exists: optional mic, Mac audio and camera | Native/synthetic audio checks; real devices unproven |
| C07 | Device pickers, separate meters, test recording | Partial: device menus and separate recording input meters | Meter math has synthetic tests; device levels and quick preflight playback remain unqualified |
| C08 | Permission help and recovery | Partial; prompts and text errors exist | No proven denial/retry journey; dedicated readiness view proposed, V01–V03 |
| C09 | Countdown, cancel preparation, remembered presets | Partial: cancellable three-second countdown and remembered inputs | Demo/Call named presets remain; native compile evidence |
| R01 | Floating recording HUD and shrink/hide studio | Exists: floating 60-point strip, drawing tools expand it | Native render; main window hides when capture begins |
| R02 | Include Clips UI in recorded video | Exists: own application included; own audio excluded | SCContentFilter source verified; actual captured-window proof remains |
| R03 | Pause/resume, stop, elapsed time | Exists | Synthetic clock/media proof; physical static-screen pause and controller races unproven, V04–V06/V13 |
| R04 | Reopen Clips during recording | Exists via menu/reopen; page navigation is disabled during a take | Next capture policy must make reopened window visible in output |
| R05 | Keyboard controls | Partial: app shortcuts plus global Control-Option-Space / Period | Registration recorded in native UI smoke; physical interaction and VoiceOver remain |
| R06 | Camera positioning and live inputs | Partial; fixed-size draggable camera window | Resize/persist/live camera-off/mute missing; actual composition unproven |
| R07 | Device/display loss, lock/sleep, repeated commands | Partial: stream-error and sleep interruption | Full unplug, route, lock, disk and race matrix remains |
| R08 | Restart or discard an unwanted take safely | Missing dedicated action | Proposed; preserve the first take in recoverable trash |
| S01 | Durable original and new-file export | Exists; committed segments, digests, decode checks, no overwrite | Synthetic evidence; no power-loss or worst-case loss-bound claim |
| S02 | Recover after process termination | Partial; verified committed segments only | Synthetic SIGKILL evidence for tested checkpoints, V10 |
| S03 | Repair manifest/orphan media | Missing; corruption blocks export and preserves originals | Planned; reject-corruption tests do not prove repair, V11 |
| S04 | Low disk and destination failures | Partial; 128 MiB reserve and surfaced failures | Fault-injection and physical storage proof missing, V08–V09 |
| S05 | Storage location, size, retention, trash/restore | Partial: chosen storage folder, Recently Deleted, undo move | No automatic original deletion; retention/usage UI remains |
| E01 | Preview and playback | Exists with native AVPlayerView | Render evidence; generated media decodes; physical playback journey unproven |
| E02 | Rename and nondestructive trim/export | Exists: rename, trim and remove-selection export | Saved edit recipe beside output; native decoded cut/trim tests |
| E03 | Export progress, cancellation, queue | Partial: cancellable progress jobs, stale-result gate, separate Stop | One interactive export at a time; persistent background queue remains |
| E04 | Record another, retain earlier clip | Exists | Source path; complete user journey unproven, V26 |
| L01 | Local clips, thumbnails, title search, Finder | Exists: local list, thumbnails, title search, verified preview cache | Native fixture renders; scale and cache-retention policy remain |
| L02 | Projects, notes, search beyond titles | Partial: local notes per recording | Projects and notes search remain |
| L03 | Transcript search and captions | Partial: optional SRT/WebVTT import and synchronized captions | No automatic transcription or transcript search; native evidence in build review |
| H01 | Export ordinary MP4 and native Share sheet | Exists | Local export evidence; no proof of recipient access or remote delivery |
| H02 | Named folder destinations, verified copy, retry | Partial: folder destination, digest-verified copy, idempotent retry | Native copy/retry test; saved destinations and persistent retries remain |
| H03 | Local agent commands and completion events | Missing | Planned M4; clips-probe is only a fixture tool |
| H04 | Direct upload, share links, provider processing | Partial: portable watch folder with HTML player | Local output only; no hosted upload, public link, access or provider service |
| D01 | Local synchronous diagnostic file | Exists: typed JSONL writer on dedicated utility queue | Lifecycle, permissions, output dimensions, frame summaries, encoder waits and exports; one-second flush interval |
| D02 | Reveal/export diagnostic bundle | Exists: Save diagnostic report and reveal outbox | Strict allowlist; no arbitrary error strings, media, paths or attachments |
| D03 | Bounded logs and recording correlation | Partial: file/total/age bounds, run and recording correlation | Some performance/provider metrics still future work; privacy/validation tests pass |
| D04 | Sanitized reports committed to repo by local agent | Partial: validated outbox and local Git publication command | Python validator tests; actual local-agent GitHub authentication/configuration remains |
| D05 | Incident to reproducer to regression evidence | Partial: versioned report plus source commit and regression suites | No real physical incident report has completed the loop |
| Q01 | Mac CI, package icon, development ZIP | Exists: Mac build, tests, native renders, development ZIP, iPad simulator build | See pinned build review; development artifacts are not notarized releases |
| Q02 | Company-signed, notarized install | Partial; release script exists | No release artifact/signing evidence found in fetched repo/releases; local Mac action remains |
| Q03 | Physical capture and supported-device matrix | No completed physical evidence found | V01–V38 remain subject to their exact evidence requirements; M5 open |
| Q04 | Update/reinstall path | Missing product flow | Proposed; stable identity, preserved recordings/permissions, user-controlled updates |
| Q05 | Browser edition / other native platforms | Missing | Browser later M6; other native platforms separate decision |
| A01 | Pair/reconnect/revoke a drawing device | Partial: ephemeral nearby pairing, two-device code approval, disconnect/re-pair | Crypto transcript/replay tests pass; actual radios, reconnect and revocation need two devices |
| A02 | Selected-area preview for capable remote drawing adapters | Partial: explicitly enabled selected recording preview, one frame in flight | Native implementation; image quality, latency and radio backpressure unproven |
| A03 | Device-neutral ink visible on Mac and in export | Exists in source: shared portable scene and native overlay renderer | Local adapter render tested; physical screen/video inclusion still unproven |
| A04 | Laser pointer and fading marks | Partial: laser tool and periodic expiration | Physical feel and exact fading timing need validation |
| A05 | Whiteboard canvas and return to the demo | Exists in source: optional Mac whiteboard background | Native source; physical capture proof remains |
| A06 | Ink geometry, latency and reconnect correctness | Partial: normalized geometry, epoch changes, ordered messages, re-pair | Physical Pencil latency, rotation, display mapping and recovery remain open |
| A07 | Optional ink source and structured performance evidence | Partial: local annotation snapshot/timeline sidecars and aggregate diagnostics | Sidecars checkpoint asynchronously; editable re-render and detailed latency trace remain |
| A08 | Mouse/trackpad drawing and drawing-off recorder path | Exists: pointer adapter and optional-module disable path | Native adapter routing/disable checks; physical mouse drawing remains |
| A09 | Additional pen/touch/browser input adapters | Partial: iPad Pencil/finger companion and adapter interface | Other vendors/browser/Android adapters remain |
| X01 | Narrow versioned subsystem contracts and capability registry | Exists: versioned contracts, typed adapter registration/lookup | Drawing, editing, export, processors and destinations registered; no arbitrary code loader |
| X02 | Editing/processing/sharing jobs separate from recording | Exists: export/edit/destination contracts, job gate and retained originals | Native cut/source-preservation/copy/retry checks; durable job queue remains |
| X03 | Extension compatibility, isolation and disable path | Partial: bundled capability registry and disable path | First-party modules share process; external crash/resource isolation remains unimplemented |
| X04 | Portable artifacts and missing-extension behavior | Partial: MP4, JSON ink/recipes, notes, WebVTT, portable watch folder | Unknown third-party edit round-trip is future SDK work |
| X05 | Extension diagnostics and contract acceptance | Partial: contract, privacy, stale job and crypto regression tests | Complete external-isolation and hardware matrix remains open |

For a broader Loom-type opportunity inventory, including attention tools, privacy/redaction, editing, hosted viewing, access, and collaboration, see [LOOM-GAPS.md](LOOM-GAPS.md). The [structured diagnostics design](DIAGNOSTICS.md) covers the requested local-log-to-repository feedback loop.

## Gaps worth discussing first

The user authorized implementation of the broader map. The execution plan prioritizes local recording, optional tools and trustworthy evidence; hosted services and new external providers still require a concrete provider/access configuration.

1. **Make setup truthful.** Region boundary/preview, real mic/system meters, and a short test-and-playback action help answer “what am I recording, and can you hear me?” Include clear permission/device readiness.
2. **Make a bad take cheap.** Countdown with Esc cancel, global pause/stop, and Restart/Discard with undo. A recorder should stay easy to control when another app has focus.
3. **Make failures explainable.** Add the requested local log with bounded growth, then a Reveal/Export diagnostics action. Include source/build identity and session IDs; exclude content, window titles, credentials, and unnecessary paths. Batch frame counters before a synchronous write on a dedicated logging/writer queue; do not add per-frame disk I/O to an audio callback.
4. **Make ownership visible.** Show original/export sizes, storage location, and recoverable trash. Separate “original safely retained,” “export finished,” and “handoff completed.”
5. **Choose the first audience.** Recommendation: finish the short screen-demo/bug-report workflow first. Keep two-hour call recording as an explicit qualification track with real audio-route and sync evidence. Both jobs remain in the product plan; this is a discussion about delivery order.
6. **Keep intelligence attachable.** A local MP4 plus a small metadata/completion contract can feed a chosen agent later. Transcription, captions, summaries, and upload providers should not block local capture.

The four original WANT.md changes are implemented in this batch, now extended by Daniel’s request for structured reports committed back through the local agent. Signing and physical validation remain necessary alongside it. This map does not make cloud upload, built-in AI, accounts, notifications, or an editor timeline prerequisites for a useful recorder.

### Requested addition: Optional drawing and replaceable tools

Daniel wants Apple Pencil drawing for himself and a design that also supports people with another input device or no drawing device. The [drawing subsystem](features/drawing.md) owns portable ink and tools; local mouse/trackpad and [iPad](features/ipad-ink.md) are input adapters. Drawing can be off without affecting recording. Editing, sharing, processing and diagnostic publishing have separate contracts in [PLUGINS.md](PLUGINS.md), with bundled defaults and no initial marketplace/runtime loader. These additions now have executable implementations. See BUILD-PLAN.md for shipped boundaries and the remaining work; physical evidence is tracked separately.

## Evidence

See [BUILD-REVIEW.md](BUILD-REVIEW.md) for exact source commits, successful native runs, artifact links, tests and unproven hardware cases. Compilation is not installation approval. A simulator is not an iPad/Pencil or radio test.

## Keep this map useful

For each feature change, update the matching stable ID, its detail page, the applicable validation cases, and source/build evidence. List every entry point affected: main window, menu bar, app shortcut, future HUD/global shortcut/CLI. Record failed and blocked paths too. Never advance a whole validation case because one subcase passed. Keep new suggestions labeled Proposed until Daniel chooses them; do not grow the release gate by implication.
