# Eidos Clips feature map

Use this page to discuss what belongs in Clips and to find the real user paths for verification. [ROADMAP.md](ROADMAP.md) orders delivery; [VALIDATION.md](VALIDATION.md) defines acceptance cases. This map connects both to the app a person can operate.

**Source baseline:** [`1eaf230`](https://github.com/eidos-agi/eidos-clips/commit/1eaf230f7ff0ed3609c66ddfe328fd5b456006cd), fetched September 6, 2026. That commit publishes the MIT license and [compact-capture brief](WANT.md); it adds no feature code. This map is a source audit and discussion document, not a claim that a native user journey was exercised in this authoring session.

## Read the map

Implementation and evidence are separate:

- **Exists:** an executable path is present in the source. This alone does not mean it works on a physical Mac.
- **Partial:** a usable subset or foundation exists; the named gap remains.
- **Missing:** no user-facing implementation found.
- **Next:** explicitly requested in WANT.md. **Planned:** already in the product/roadmap. **Proposed:** added here for discussion, not silently added to release scope. **Later:** intentionally deferred.
- Evidence names the actual boundary: native build, UI render, synthetic media, physical capture, or signed installation. An untested physical case stays untested.

Poteto's useful idea is to map features by their user entry points, driving steps, observable outcomes, and gotchas. The detail pages follow that shape. This is adapted from the [official pstack feature-map guidance](https://github.com/cursor/plugins/blob/4483dcd246c3212ff38890bd53977c16d7b54fb7/pstack/skills/create-verification-skill/SKILL.md). It does not install pstack or claim to provide an already-verified desktop automation skill.

## Product overview

| User job | What exists at the baseline | What is missing or needs to change | Detail |
|---|---|---|---|
| Get ready quickly | Large recording window, display selector, three optional input switches | Compact ready panel, region selector, exact preview, countdown, meters, remembered choices | [Prepare and record](features/record.md) |
| Stay in control during a take | Pause/resume/finish in app and menu bar; timer; floating camera | Small HUD, include Clips in video, global shortcuts, live input controls, stronger interruption behavior | [Prepare and record](features/record.md) |
| Keep useful work | Segmented originals, checked export, failed/recoverable package discovery | Physical failure evidence, manifest/orphan repair, storage management, safe discard/trash | [Keep and recover](features/recovery.md) |
| Finish and find it | Playback, title, trim-to-new-MP4, thumbnails, title search, Finder | Saved edit decisions, projects/notes, faster repeat opening, useful library storage controls | [Review and library](features/review.md) |
| Give it to someone or an agent | Local MP4 and native Share sheet | Verified folder delivery, reusable destinations, local command/event contract; links/transcripts later | [Share and hand off](features/handoff.md) |
| Trust and diagnose the app | CI tests/probes, development packaging, company signing script | In-app diagnostic files/export, executed signing evidence, clean-Mac install, physical acceptance | [Diagnostics and delivery](features/diagnostics.md) |

The primary loop is **prepare → record → finish → review → export or hand off → find later**. Recovery and diagnosis must remain reachable when that loop fails.

## Inventory

| ID | Feature | Implementation now | Scope and evidence |
|---|---|---|---|
| C01 | Compact ready panel | Missing; launch is 1040×780 with 880×640 minimum | Next; native renders show the existing large layout |
| C02 | Whole-display selection/capture | Exists; refreshed display list and selected index | Physical permission/display behavior unproven |
| C03 | Region selection, drag and Esc cancel | Missing | Next; display-coordinate and mixed-DPI output proof required, V21–V22 |
| C04 | Window selection/capture | Missing | Later than the next brief; still in the wider M2 plan |
| C05 | Exact capture preview/border | Missing; current canvas is decorative | Planned preview; persistent region boundary proposed for discussion |
| C06 | Mic, system audio, camera switches before start | Exists using default mic/camera | Native synthetic audio checks do not prove devices, V02–V03/V17 |
| C07 | Device pickers, separate meters, test recording | Missing | Pickers/meters planned; quick playback check proposed |
| C08 | Permission help and recovery | Partial; prompts and text errors exist | No proven denial/retry journey; dedicated readiness view proposed, V01–V03 |
| C09 | Countdown, cancel preparation, remembered presets | Missing | Planned Demo/Call presets and countdown; persistent device identity needs validation |
| R01 | Floating recording HUD and shrink/hide studio | Missing | Next; timer/pause/finish remain available in current app/menu |
| R02 | Include Clips UI in recorded video | Missing desired behavior; own app is currently excluded except camera | Next; keep current-process audio excluded; replaces the old hide-controls requirement |
| R03 | Pause/resume, stop, elapsed time | Exists | Synthetic clock/media proof; physical static-screen pause and controller races unproven, V04–V06/V13 |
| R04 | Reopen Clips during recording | Exists via menu/reopen; page navigation is disabled during a take | Next capture policy must make reopened window visible in output |
| R05 | Keyboard controls | Partial; app-scoped start/finish shortcuts and menu actions | Global configurable shortcuts missing; VoiceOver unproven, V24 |
| R06 | Camera positioning and live inputs | Partial; fixed-size draggable camera window | Resize/persist/live camera-off/mute missing; actual composition unproven |
| R07 | Device/display loss, lock/sleep, repeated commands | Partial; stream errors interrupt; no complete device/route recovery flow | Planned; physical races/routes/sleep unproven, V05/V19–V21 |
| R08 | Restart or discard an unwanted take safely | Missing dedicated action | Proposed; preserve the first take in recoverable trash |
| S01 | Durable original and new-file export | Exists; committed segments, digests, decode checks, no overwrite | Synthetic evidence; no power-loss or worst-case loss-bound claim |
| S02 | Recover after process termination | Partial; verified committed segments only | Synthetic SIGKILL evidence for tested checkpoints, V10 |
| S03 | Repair manifest/orphan media | Missing; corruption blocks export and preserves originals | Planned; reject-corruption tests do not prove repair, V11 |
| S04 | Low disk and destination failures | Partial; 128 MiB reserve and surfaced failures | Fault-injection and physical storage proof missing, V08–V09 |
| S05 | Storage location, size, retention, trash/restore | Missing user controls | Location/trash planned; disk usage and retention UI proposed, no automatic original deletion |
| E01 | Preview and playback | Exists with native AVPlayerView | Render evidence; generated media decodes; physical playback journey unproven |
| E02 | Rename and nondestructive trim/export | Exists; sliders export a new MP4 | Synthetic trim/source-preservation proof; saved edit recipe missing, V25 |
| E03 | Export progress, cancellation, queue | Partial; busy text and capture gate | Percentage/cancel/background queue missing; no concurrent-capture claim |
| E04 | Record another, retain earlier clip | Exists | Source path; complete user journey unproven, V26 |
| L01 | Local clips, thumbnails, title search, Finder | Exists; scans recording packages | Native fixture render; no large-library performance or missing-file recovery proof |
| L02 | Projects, notes, search beyond titles | Missing | Planned in M3 |
| L03 | Transcript search and captions | Missing | Later via a chosen processor; not required to record/export |
| H01 | Export ordinary MP4 and native Share sheet | Exists | Local export evidence; no proof of recipient access or remote delivery |
| H02 | Named folder destinations, verified copy, retry | Missing | Planned M4; must report Copied to folder, not Uploaded |
| H03 | Local agent commands and completion events | Missing | Planned M4; clips-probe is only a fixture tool |
| H04 | Direct upload, share links, provider processing | Missing | Later; explicit destination/access and separate proof required |
| D01 | Local synchronous diagnostic file | Missing | Next; lifecycle, filter/size, frame completeness, encoder wait, queue overload, export duration |
| D02 | Reveal/export diagnostic bundle | Missing | Proposed; one useful handoff for Daniel/local agent, no private media |
| D03 | Bounded logs and recording correlation | Missing | Proposed guardrail for D01; limit disk use and connect events to a random session ID |
| D04 | Sanitized reports committed to repo by local agent | Missing | Requested feedback loop; schema validation/outbox/Git transport design in DIAGNOSTICS.md |
| D05 | Incident to reproducer to regression evidence | Missing end-to-end loop | Requested improvement goal; link report/feature/fix/test IDs, never treat logs as executable instructions |
| Q01 | Mac CI, package icon, development ZIP | Exists | Build, seven tests, four UI renders, synthetic probes passed at baseline |
| Q02 | Company-signed, notarized install | Partial; release script exists | No release artifact/signing evidence found in fetched repo/releases; local Mac action remains |
| Q03 | Physical capture and supported-device matrix | No completed physical evidence found | V01–V38 remain subject to their exact evidence requirements; M5 open |
| Q04 | Update/reinstall path | Missing product flow | Proposed; stable identity, preserved recordings/permissions, user-controlled updates |
| Q05 | Browser edition / other native platforms | Missing | Browser later M6; other native platforms separate decision |

For a broader Loom-type opportunity inventory, including attention tools, privacy/redaction, editing, hosted viewing, access, and collaboration, see [LOOM-GAPS.md](LOOM-GAPS.md). The [structured diagnostics design](DIAGNOSTICS.md) covers the requested local-log-to-repository feedback loop.

## Gaps worth discussing first

These priorities are recommendations. Items marked Proposed above need a scope decision before implementation.

1. **Make setup truthful.** Region boundary/preview, real mic/system meters, and a short test-and-playback action help answer “what am I recording, and can you hear me?” Include clear permission/device readiness.
2. **Make a bad take cheap.** Countdown with Esc cancel, global pause/stop, and Restart/Discard with undo. A recorder should stay easy to control when another app has focus.
3. **Make failures explainable.** Add the requested local log with bounded growth, then a Reveal/Export diagnostics action. Include source/build identity and session IDs; exclude content, window titles, credentials, and unnecessary paths. Batch frame counters before a synchronous write on a dedicated logging/writer queue; do not add per-frame disk I/O to an audio callback.
4. **Make ownership visible.** Show original/export sizes, storage location, and recoverable trash. Separate “original safely retained,” “export finished,” and “handoff completed.”
5. **Choose the first audience.** Recommendation: finish the short screen-demo/bug-report workflow first. Keep two-hour call recording as an explicit qualification track with real audio-route and sync evidence. Both jobs remain in the product plan; this is a discussion about delivery order.
6. **Keep intelligence attachable.** A local MP4 plus a small metadata/completion contract can feed a chosen agent later. Transcription, captions, summaries, and upload providers should not block local capture.

The four original WANT.md changes form the next requested implementation slice, now extended by Daniel’s request for structured reports committed back through the local agent. Signing and physical validation remain necessary alongside it. This map does not make cloud upload, built-in AI, accounts, notifications, or an editor timeline prerequisites for a useful recorder.

## Evidence fetched with this map

- GitHub reports the repo **public**, license **MIT**; no GitHub releases were returned on September 6, 2026. That does not prove no signed local build exists on Daniel's Mac.
- [Native run 34014597627](https://github.com/eidos-agi/eidos-clips/actions/runs/34014597627) passed for `1eaf230`: macOS 15.7.9 arm64, Xcode 16.4, Swift 6.1.2; seven XCTest tests, native development app build, four native window renders, and synthetic media/recovery probes.
- [Development artifact and evidence](https://github.com/eidos-agi/eidos-clips/actions/runs/34014597627/artifacts/9983533018) includes the ZIP, logs, `ui-*.png`, and evidence JSON. It is not notarized. Artifact retention is finite.
- The native UI smoke writes PNGs through the app's own rendering path; it does not require the accessibility screenshot that hung on the local agent. It assigns fixture state directly, so it proves rendering rather than a user clicking through the workflow. No physical screen/mic/camera evidence follows from it.

## Keep this map useful

For each feature change, update the matching stable ID, its detail page, the applicable validation cases, and source/build evidence. List every entry point affected: main window, menu bar, app shortcut, future HUD/global shortcut/CLI. Record failed and blocked paths too. Never advance a whole validation case because one subcase passed. Keep new suggestions labeled Proposed until Daniel chooses them; do not grow the release gate by implication.
