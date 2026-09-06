# Prepare and record

Baseline and evidence: [feature map](../FEATURE-MAP.md). IDs C01–C09 and R01–R08. Main sources: [CaptureController](../../Sources/EidosClips/CaptureController.swift), [ClipsModel](../../Sources/EidosClips/ClipsModel.swift), [ClipsView](../../Sources/EidosClips/ClipsView.swift), [app/menu lifecycle](../../Sources/EidosClips/main.swift).

## Sub-features

- Existing: display selection; optional default mic, camera, system audio; start; pause/resume; finish; elapsed time; reopen app; draggable camera window.
- Partial: permission errors, interruption handling, keyboard controls, normal Quit finalization.
- Next: compact ready panel/HUD, include Clips in video, region selection with Esc cancel. None is implemented at this baseline.
- Planned: device pickers/meters, exact preview, countdown, presets, global shortcuts, live input control. Window selection can wait per WANT.md.

## How to get to it (user POV)

1. Launch Clips, or choose **Open Clips** in its menu-bar menu. **New recording** opens the recording page from the library/review area when idle.
2. Click **Choose a display…**. With screen permission, select an enumerated display; **Refresh displays** reloads the list. Turn **Microphone**, **Camera**, and **System audio** on/off before starting.
3. Click **Start recording** or use app-scoped **Command-Shift-R**. No countdown exists. The canvas is an illustration, not a live preview.
4. Use **Pause/Resume** or **Finish recording** in the window, or **Pause / Resume** / **Finish recording** from the menu bar. App-scoped **Command-.** is a finish shortcut; it is not a system-wide shortcut.
5. Close/reopen the main window using the menu bar or Dock. Reopening works, but current capture excludes the Clips process except its camera window. Page navigation and setup switches are disabled during capture.

## Driving it with native UI

Preconditions: a permitted physical test Mac, a specific source/app hash, a non-sensitive display, and explicit capture inputs. Follow [LOCAL-AGENT.md](../LOCAL-AGENT.md) for build identity; do not replace the installed app or reset privacy grants as test setup.

- Record a visible changing counter while speaking known words; enable system audio only when testing a known playback source. Observe the action and state transitions, then finish and inspect the exported MP4 in QuickTime.
- Repeat pause/resume on a static desktop. Compare elapsed recorded time and decoded duration; check both audio sources rather than relying on a UI icon. Exercise both window and menu entry points.
- Exercise denied/missing optional inputs deliberately; expect a clear failure, not a successful-looking silent narration. Repeated Start/Stop and Quit need one finalization and retained data.
- For the next implementation, drag regions on each supported display layout, cancel with Esc, then compare selected bounds against decoded pixels. Open Clips during the take: the window/HUD must appear if inside the selected scope; the camera must appear once. Keep current-process audio excluded.
- Capture observations and media locally; report V01–V06, V12–V24 only to the extent exercised. No automated physical driver is currently committed.

## Gotchas

- Capture refreshes display enumeration and selects by index. Display removal/reordering needs explicit regression coverage; do not assume stable source identity.
- The app is currently large: launch requests 1040×780 and enforces an 880×640 minimum. The existing `ui-compact.png` is that minimum studio layout, not the requested small HUD.
- A fixed-size camera preview window is captured directly; DPI, spaces, occlusion, and crop behavior remain unproven. No independent camera original is retained.
- Stream start does not prove every requested input has delivered usable media. Preflight meters/first-input readiness are important gaps.
- UI smoke directly sets model state and never starts capture. It proves layouts, not controls, permissions, or hardware.
