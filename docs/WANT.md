# Next: compact capture like Loom

> **Implementation update — September 6, 2026:** Executable code now implements the compact capture, modular tools, local drawing, native iPad companion, editing/destination and diagnostic paths described in [BUILD-PLAN.md](BUILD-PLAN.md). Use [FEATURE-MAP.md](FEATURE-MAP.md) for current feature status and [BUILD-REVIEW.md](BUILD-REVIEW.md) for exact proof. Historical “missing/proposed” statements below describe the earlier baseline unless listed as still open in that ledger. Physical and signing acceptance are not implied.


Work for the next agent. Do this in `eidos-agi/eidos-clips`. MIT, public, free.

See [FEATURE-MAP.md](FEATURE-MAP.md) for current behavior and proof, [LOOM-GAPS.md](LOOM-GAPS.md) for broader opportunities, and [DIAGNOSTICS.md](DIAGNOSTICS.md) for the structured logging/report design. These documents do not mark the work below implemented.

## Product

1. **Record the Clips UI while recording.** Stop excluding this process from ScreenCaptureKit. Today `CaptureController` builds `SCContentFilter` with `excludingApplications: ownApps`. Include Clips windows in the stream (HUD, main window, camera bubble). Keep `excludesCurrentProcessAudio = true` so the app does not hear itself.

2. **Do not take over the screen.** Ready state is a small panel, not an 880×640 studio. While recording, hide or shrink the main window and show a floating control strip: timer, pause/resume, stop. Menu bar keeps working. Opening Clips during a take is allowed and must appear in the recording.

3. **Region picker.** Display is already there. Add drag-to-select a portion of the screen (Esc cancels). Feed `SCStreamConfiguration.sourceRect` in display coordinates. Window capture can wait.

4. **Diagnostic logging.** Synchronous file log under `~/Movies/Eidos Clips/Logs/`. Log start/stop/pause, filter and output size, frame completeness, encoder wait milliseconds, queue overload, export duration. No secrets, no media bytes. This is how we find bottlenecks.

5. **Close the diagnostic feedback loop.** Daniel also wants enough structured evidence for the local agent to commit useful reports back to this repository so a coding agent can diagnose bottlenecks and regressions. Design coverage includes successful and failed actions, source/build identity, correlated sessions, latency/queue metrics, and a sanitized report outbox. Raw logs/media stay local; the public repo receives validated bounded reports through the existing local agent. The transport and publication setup remain a design to implement, not an active uploader.

6. **Draw from a paired iPad with Apple Pencil.** Daniel wants to annotate while recording from his MacBook Pro, with the drawing visible on the Mac and in the saved video. Add pairing, an accurately mapped selected-area preview, and live ink. Laser/whiteboard modes and a native companion are proposed design choices; compare a Sidecar experiment before committing to the transport. See [features/ipad-ink.md](features/ipad-ink.md) and feature IDs A01–A07. No companion feature code or physical proof exists yet.

7. **Keep tools modular and devices optional.** Drawing is its own device-neutral subsystem; mouse/trackpad, iPad/Pencil, pen tablets and future companions are adapters, with no requirement to draw at all. Editing, processing, sharing and diagnostic publication use separate contracts and jobs. Core capture/save/recovery/basic playback/MP4 export must work with all optional extensions off. Start with trusted bundled modules and narrow interfaces; external plugin loading is later work requiring real compatibility/isolation. See [PLUGINS.md](PLUGINS.md) and [features/drawing.md](features/drawing.md). No framework or adapter implementation is claimed.

## Do not

- Mark M5 or physical cases passed.
- Replace an installed app.
- Strip quarantine or weaken Gatekeeper.
- Claim window capture, meters, or live mute work until they exist.

## Files to start from

- `Sources/EidosClips/CaptureController.swift` — exclusion + full-display-only config
- `Sources/EidosClips/ClipsView.swift` / `main.swift` — large window
- `Sources/ClipsMedia/SegmentedRecorder.swift` — encoder wait loop
