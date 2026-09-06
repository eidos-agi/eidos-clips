# Product and experience

Planning baseline: 2026-09-06. All features below are proposed unless explicitly described as existing in the [feature map](FEATURE-MAP.md). The later [WANT.md](WANT.md) brief takes priority for the next slice: compact controls, region capture, and Clips windows included in recorded video. Window selection remains in the wider plan and can follow that slice.

## Promise

Make a clear recording in seconds, trust that it is being saved, and leave with a useful file. The product should feel like a small, finished Mac utility. Reliability, capture clarity, and the recipient's ability to play the export are the differentiators.

Primary jobs:

| Job | Successful result |
|---|---|
| Explain a feature or decision | A clean screen recording with optional face and narration, ready to send |
| Report a bug or give feedback | A short named clip associated with a project; confidential material stays outside the selected capture |
| Keep a call | Both sides remain intelligible, including overlapping speech; a long session survives ordinary interruptions |
| Feed a work pipeline | A completed local artifact and metadata can be picked up by the user's chosen agent |

Proposed positioning: **Eidos Clips — Show it. Keep it. Put it to work.** Use “Eidos Clips” consistently in the app, repository, installer, help, and exports. “Clips” can be the short in-app label.

## The main experience

### 1. Ready

A menu-bar icon and configurable global shortcut open a compact capture panel. Show the selected display, window, or region; a live preview; camera and microphone choices; separate mic/system meters; estimated storage use; and the destination. Remember the last valid choices and revalidate device identities on each start.

Two presets keep setup quick: **Demo** defaults to screen, microphone, and camera; **Call** defaults to screen, microphone, and system audio with camera off. Both remain editable. Source selection for screen and system audio is explicit: choosing a window must not silently imply all-system audio when app-specific capture was expected.

Request OS permissions when the corresponding feature is enabled. A missing optional camera does not prevent a screen recording. If an explicitly selected audio source is unavailable, explain the problem before starting and offer a deliberate silent-recording choice. Do not silently turn a failed microphone request into a successful-looking recording.

Preview the exact capture bounds. Label the display and selected window by recognizable names, and distinguish the two monitors in a multi-display setup. Changing a device, unplugging a display, or resizing the source revalidates the preview.

### 2. Record

A cancellable three-second countdown gives time to switch context. A compact floating control strip shows record/pause state, elapsed recorded time, audio activity, and Stop. It can collapse while the menu-bar indicator remains obvious. Clips windows and controls are included when inside the selected capture scope, as requested in WANT.md; the camera appears exactly once. Opening Clips during a take is allowed. Current-process audio remains excluded to avoid recording the app playback itself. This supersedes the original excluded-controls design and is not yet implemented in the baseline source.

Move and resize the camera bubble within the capture area; remember its normalized placement per preset. “Camera off” stops camera capture. “Microphone muted” prevents microphone samples from being retained. Show these states consistently in the panel, menu bar, and automation status.

Pause removes time from the saved media across every track. On resume, the UI timer and exported duration remain consistent. A global shortcut can pause/resume or stop, with configurable bindings and conflict detection. A source-loss interruption pauses safely and asks for a replacement; it never silently switches to a different display or microphone.

Low disk, a failed writer, and missing selected audio produce actionable recording status. Closing the control panel does not stop the session. Normal Quit waits for safe finalization. Lock/sleep stops new capture into an interrupted session; reopening requires a deliberate resume or finish action.

### 3. Finish

Stopping opens a playback preview as soon as the media can be read. Display saving/export progress separately from capture completion. The original is kept automatically; there is no destructive “keep or lose this take” decision.

Primary actions: **Trim**, **Rename**, **Export MP4**, **Reveal in Finder**, and **Send to…**. The native share sheet appears only after an export is ready. Trim is nondestructive and updates a simple edit description. Exact cuts may require re-encoding near boundaries; the UI must not imply instant lossless export for every edit.

“Record again” starts a new take and retains the previous one. Delete moves a clip to a recoverable trash state. A permanent delete is explicit and never follows automatically from a successful handoff.

### 4. Find it later

A small Clips window contains a prominent Record action and recent clips with thumbnail, title, duration, date, project, and storage/export status. Search title, project, and manually entered notes. Use a list/grid toggle only if it improves actual navigation; avoid adding dashboards, unread counters, or social features.

Recovered or interrupted recordings are visible here with the retained duration and the exact limitation. A missing external destination does not hide the local original. Project association is optional; recording should never require creating a project first.

## Visual direction

Use a restrained native interface: system typography, clear spacing, strong focus states, and one Eidos accent. Support system light/dark appearance. Use red only for active capture or destructive actions. Pair color with text/icons for recording, paused, saving, and failed states. Avoid long implementation explanations in the recording flow.

Keep the camera bubble and control strip visually distinct. Provide practical bubble sizes and optional mirroring; preview and output must use the same transformation. Keyboard navigation, VoiceOver labels, reduced motion, readable meters, and macOS text sizing are part of the core experience.

Initial design deliverables during M2: ready panel, recording strip, finish screen, Clips window, and recovery state. Review them at laptop scale and on an external display. These are future implementation deliverables; no mockups have been created in this planning change.

### Optional tools and input devices

Recording works without drawing hardware or optional extensions. **Draw** can use the Mac mouse/trackpad, a supported attached pen, or a paired device such as iPad/Pencil. The annotation subsystem owns portable ink and tool behavior; adapters own device input/transport. Pairing appears only when a selected input needs it.

Basic playback/trim/local MP4 remain bundled. Richer editors, processing/captions and sharing destinations attach through independent contracts; expose them as familiar actions such as **Edit with…** or **Send to…**, not a technical plugin dashboard in the recording flow. Disabled or missing optional tools must not compromise original recordings. See [PLUGINS.md](PLUGINS.md).

## Scope

| Capability | Native 1.0 | Later |
|---|---|---|
| Display, window, and region recording | Yes; consistent preview and coordinate mapping | Additional capture modes if justified |
| Camera circle and device selection | Yes | Optional independent camera source for post-recording repositioning |
| Microphone and system audio | Separate retained tracks and a playable mixed export | More processing options after hardware validation |
| Video output | SDR H.264/AAC MP4; 1080p30 default and validated higher-resolution preset | HDR/60 fps when measured and needed |
| Recovery, pause, device loss | Required release behavior | Stronger recovery bounds if validated |
| Trim, rename, recent clips | Yes | Captions, annotations, cursor emphasis, chapter markers |
| Sharing | Native share sheet and named folder destinations | Direct provider upload and verified share links |
| Agent use | Local CLI, project metadata, durable events | Optional stdio MCP adapter and processing adapters |
| Browser edition | M6, after native release | Capability-tested Chrome/Edge on macOS and Windows |
| Native Windows/Linux | No launch promise | Separate product decision based on demand |

No required cloud service, account, mandatory AI call, team administration, notification inbox, or general-purpose video editor in 1.0. Optional online processing and transfers must clearly identify their destination. Recording/export remains usable offline without them.

## Proposed measurable outcomes

These are targets to validate, not measured claims:

- Returning user begins capture within ten seconds of opening the panel, excluding OS prompts.
- A five-minute default demo is ready for review within five seconds of Stop; export progress is shown if an edit needs longer processing.
- No completed recording is lost by Record again, ordinary Quit, or a failed handoff.
- A/V offset is within 100 ms at the beginning and end of a two-hour call on supported hardware.
- Standard 1080p30 capture stays below 500 MB resident memory, with no sustained duration-dependent growth.
- Recovery after process termination retains everything through the most recent verified checkpoint. M0 targets a checkpoint interval no longer than ten seconds and must demonstrate the actual loss bound before a numerical guarantee is published.

The full evidence matrix and measurement definitions live in [VALIDATION.md](VALIDATION.md).
