# Next: compact capture like Loom

Work for the next agent. Do this in `eidos-agi/eidos-clips`. MIT, public, free.

## Product

1. **Record the Clips UI while recording.** Stop excluding this process from ScreenCaptureKit. Today `CaptureController` builds `SCContentFilter` with `excludingApplications: ownApps`. Include Clips windows in the stream (HUD, main window, camera bubble). Keep `excludesCurrentProcessAudio = true` so the app does not hear itself.

2. **Do not take over the screen.** Ready state is a small panel, not an 880×640 studio. While recording, hide or shrink the main window and show a floating control strip: timer, pause/resume, stop. Menu bar keeps working. Opening Clips during a take is allowed and must appear in the recording.

3. **Region picker.** Display is already there. Add drag-to-select a portion of the screen (Esc cancels). Feed `SCStreamConfiguration.sourceRect` in display coordinates. Window capture can wait.

4. **Diagnostic logging.** Synchronous file log under `~/Movies/Eidos Clips/Logs/`. Log start/stop/pause, filter and output size, frame completeness, encoder wait milliseconds, queue overload, export duration. No secrets, no media bytes. This is how we find bottlenecks.

## Do not

- Mark M5 or physical cases passed.
- Replace an installed app.
- Strip quarantine or weaken Gatekeeper.
- Claim window capture, meters, or live mute work until they exist.

## Files to start from

- `Sources/EidosClips/CaptureController.swift` — exclusion + full-display-only config
- `Sources/EidosClips/ClipsView.swift` / `main.swift` — large window
- `Sources/ClipsMedia/SegmentedRecorder.swift` — encoder wait loop
