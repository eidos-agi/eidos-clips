# Draw from iPad with Apple Pencil

> **Implementation update — September 6, 2026:** Executable code now implements the compact capture, modular tools, local drawing, native iPad companion, editing/destination and diagnostic paths described in [../BUILD-PLAN.md](../BUILD-PLAN.md). Use [../FEATURE-MAP.md](../FEATURE-MAP.md) for current feature status and [../BUILD-REVIEW.md](../BUILD-REVIEW.md) for exact proof. Historical “missing/proposed” statements below describe the earlier baseline unless listed as still open in that ledger. Physical and signing acceptance are not implied.


**Requested by Daniel on September 6, 2026; not implemented.** Core outcome: while recording from a MacBook Pro, draw with Apple Pencil on a paired iPad and see those marks on the Mac and in the finished recording. No change to the recording app's local-first or replaceable-agent architecture is needed. This is an iPad input companion, not a commitment to build a full iPad recorder.

This is a specialization of [device-neutral drawing](drawing.md), governed by [PLUGINS.md](../PLUGINS.md). Mouse/trackpad drawing and recording with drawing off remain usable without an iPad. PencilKit and the pairing transport stay inside this adapter; canonical ink and the trusted renderer belong to the host annotation subsystem.

Feature IDs A01–A07 in [FEATURE-MAP.md](../FEATURE-MAP.md). Companion protocol scope belongs in [INTEGRATIONS.md](../INTEGRATIONS.md); performance/report rules belong in [DIAGNOSTICS.md](../DIAGNOSTICS.md).

## Sub-features

| ID | Capability | Scope |
|---|---|---|
| A01 | Pair one iPad to the Mac, reconnect and revoke | Requested core integration; pairing UX/security design proposed |
| A02 | Show the selected Mac capture area on iPad | Recommended first-version requirement for accurate placement; explicit preview sharing |
| A03 | Live persistent ink visible on Mac and in export | Requested core; pen/highlighter, colors, thickness, eraser, undo/redo/clear proposed |
| A04 | Temporary laser pointer and fading marks | Proposed presentation mode |
| A05 | Switch to a blank whiteboard and return to the demo | Proposed second canvas mode; preserve each canvas separately |
| A06 | Correct crop/scale/orientation, bounded lag and reconnect | Required correctness and reliability for A01–A03 |
| A07 | Retain optional time-aligned ink source and diagnostic evidence | Ink sidecar proposed; content-free latency/reliability metrics required for verification |

### Recommended experience

Mac: **Draw → Connect device → iPad** → choose/pair the iPad → explicitly share the selected display/region preview. iPad: the preview fills a canvas with a small Pencil toolbar. Pencil draws; fingers operate the toolbar or pan/zoom locally. Drawing must not click buttons or move windows in the underlying Mac app. Keep the Mac mouse/trackpad available for the actual demonstration.

Persistent annotations explain something: a circle, handwritten label, arrow or diagram. Laser mode points briefly and fades. Whiteboard mode provides a clean page for a detour, then returns to the live demonstration. These should be small tool choices, not a general illustration editor.

### Approaches to test

| Approach | What it gives us | What it does not establish |
|---|---|---|
| Sidecar plus a Mac annotation canvas | Existing Apple mirroring/extension and Pencil input; wireless or USB setup | Clips still needs a drawing layer, correct focus/geometry and recorded-output proof; Sidecar alone does not add ink over arbitrary apps |
| Native iPad companion, using PencilKit for input and a paired local transport | Own pairing flow, Pencil-oriented toolbar, selected-area preview and annotation protocol | Needs an iPad target/distribution path and real latency/reconnection work; PencilKit is not a synchronization protocol |
| Browser canvas on iPad | Possible later installation-light entry point | Pencil/palm behavior, transport trust and local-network/browser constraints require separate proof; do not assume parity with native input |

Recommendation: implement a shared minimal annotation surface with local mouse/trackpad input first, then evaluate Sidecar against it as the shortest physical iPad experiment. Use its measured behavior to decide whether it meets the intended integrated experience. The preferred dedicated product direction is a native companion if Sidecar's focus, setup or canvas limitations interfere. Do not build both complete transports before that comparison.

Apple documents [Pencil input through Sidecar](https://support.apple.com/en-us/102597), including compatible-device/account requirements and wireless/USB use. [PencilKit](https://developer.apple.com/documentation/pencilkit/drawing-with-pencilkit) supplies native drawing facilities. [Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity) is a candidate for nearby discovery/communication; evaluate it against Network.framework/Bonjour with authenticated transport rather than promising a particular wireless route. [Local-network permission](https://developer.apple.com/videos/play/wwdc2020/10110/) must be handled explicitly. These are platform capabilities, not evidence the integration works in Clips.

## How to get to it (user POV)

The following flow is proposed; these controls do not exist yet.

1. On the Mac ready panel/HUD, choose **Draw → Connect device → iPad**. Open the Clips companion on iPad. Discover nearby Mac or scan its short-lived QR invitation, then confirm the intended device/session on the Mac. A matching-code alternative can help when scanning is inconvenient; authentication design must resist guessing and replay.
2. Share only the current selected display/region preview to the paired iPad. Make pairing and active screen-preview sharing separate visible states. No cloud account is required by the proposed design.
3. Draw a circle around a button, underline text, or write a label. The iPad displays immediate local ink; the Mac displays the acknowledged ink layer. Both reflect undo/erase/clear consistently.
4. Use **Laser** for a temporary point or **Whiteboard** for a diagram. Return to the screen without losing the separate whiteboard canvas. Keep capture start/stop controlled on the Mac in the first version; remote capture control is a separate capability.
5. Finish the take and play the MP4. Ink inside the captured scope must appear once at the intended time and position. Disconnect/revoke pairing from the Mac when finished.

## Driving it with a physical Mac and iPad

Preconditions: a permitted test MacBook Pro, compatible iPad/Pencil, exact app/toolchain/device versions, a harmless numbered-grid test scene, and source hashes. A native companion needs its own iPadOS provisioning/distribution; the existing macOS Developer ID script does not sign an iPad app. No app replacement, credential export or privacy reset is implied by this plan.

| Case | Required proof |
|---|---|
| A-V01 Pair/revoke | Correct intended peer, deny/wrong/expired/replayed invitation, local-network denial/retry, revoked peer cannot send ink or receive preview |
| A-V02 Placement | Circle known grid targets; inspect Mac display and decoded output at full-display and region scopes, Retina/scaled/negative-origin displays, iPad rotation and letterboxing |
| A-V03 Pencil behavior | Actual palm contact, finger use, rapid writing, eraser/undo/redo/clear and supported Pencil gestures; no accidental clicks in the underlying Mac app |
| A-V04 Timing | Measure local ink response, stroke arrival, Mac display presentation, preview age and recorded-frame appearance separately; report median/p95/max and environment |
| A-V05 Capture lifecycle | Draw before/during capture, pause/resume, clear, finish; one visible ink layer and correct saved timing, no double compositing or lost committed strokes |
| A-V06 Reconnect | Wi-Fi interruption, iPad lock/background, app restart and packet reordering; Mac recording continues, existing ink remains, stale strokes cannot enter a new session |
| A-V07 Load/privacy | Extended drawing plus video/audio capture; bounded queues/RSS, adaptive preview quality, no Pencil paths, screenshots or pairing material in public reports |

Initial performance goal for discussion: added Pencil-to-visible-Mac-ink latency around 100 ms or less at p95 on the chosen local setup. This is a proposed target, not a measured promise. End-to-end physical measurement is necessary; ACK timing is not display latency, and independent device clocks cannot be subtracted without estimating offset/uncertainty. Record preview lag separately because stale background video makes accurate annotation harder even when ink delivery is fast.

### Data/rendering boundaries to prove

- The Mac host is authoritative for the capture session, target rectangle, ink revision and timeline. The iPad adapter translates to the same device-neutral ink operations as local mouse/pen input; native drawing objects must not become the only saved format. Send a versioned target description with aspect ratio, crop and transform. Use normalized canvas coordinates with explicit letterbox/pan/zoom conversion; reject stale target epochs after a scope change.
- Use bounded ordered ink messages with session/epoch, stroke ID, sequence, tool and points; reliable commit/undo/clear operations plus snapshots reconcile reconnects. Validate sizes, rates, coordinates and tool enums. PencilKit snapshot/delta behavior and partial-stroke latency need a spike; do not repeatedly send the entire drawing unboundedly for every point.
- A selected-area preview goes Mac → iPad; ink goes iPad → Mac. Prioritize ink/control over the preview stream and lower preview quality under load. Preview is screen content shared to the paired device and must remain outside logs/report commits.
- Render through one defined ink layer. With the requested include-Clips capture policy, a scoped Mac overlay can provide the first implementation, provided output confirms it is captured exactly once. If later composited directly into video, prevent the same on-screen overlay from being captured a second time.
- Avoid a preview feedback loop: do not recursively send a displayed preview of the preview. Choose whether the iPad receives clean background plus canonical ink or already-composed background; do not overlay both copies of the ink. Test Sidecar/mirror arrangements explicitly.
- Proposed pause policy: Mac/iPad ink can change while capture is paused; on resume, the current agreed ink state appears without adding paused time. Disconnect preserves accepted ink and stops accepting unknown/stale events; recording does not depend on the companion staying connected.
- Screen annotations are anchored to capture coordinates, not the meaning of a webpage element. If the demo scrolls, ink does not magically follow the button. Provide Clear/Fade and deliberate page changes; semantic tracking is out of initial scope.

## Gotchas

- Sidecar supports Pencil in the mirrored/extended Mac environment, but this is not evidence of a ready-made Clips annotation overlay. Verify device compatibility and actual drawing behavior first.
- Same Wi-Fi is not authentication. Pair a device with a revocable encrypted session, a short-lived invitation and explicit preview scope. No hidden remote desktop/keyboard/camera authority follows from pairing.
- A global click-through overlay keeps Mac controls usable, but direct Sidecar Pencil input may need an explicit drawing mode to receive events. This focus tradeoff is part of the experiment; do not promise both behaviors from an untested NSWindow flag.
- Pressure, tilt, hover, double-tap and squeeze vary by Pencil/iPad. Basic drawing should not depend on a premium gesture; validate the actual user hardware before promising these extras.
- A retained ink sidecar contains user-created content, possibly handwriting or private annotations. Keep it with the local recording, never in public diagnostic reports. Reports may contain counts, timing histograms, loss/reconnect numbers and target-size classes.
- Synthetic geometry/protocol tests can establish transforms, ordering and reconnect invariants; they cannot establish Pencil feel, palm handling, visible latency or actual capture. None of these physical cases is passed yet.
