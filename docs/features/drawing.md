# Drawing with any supported input, or no drawing at all

**Requested architecture, not implemented.** The [optional-subsystem design](../PLUGINS.md) separates annotation state/rendering from input devices. [Draw from iPad](ipad-ink.md) is one proposed adapter. Feature IDs A01–A09; host boundaries X01–X05 in [FEATURE-MAP.md](../FEATURE-MAP.md).

## Sub-features

- Normal recorder with drawing off and no companion/device setup.
- Bundled optional annotation subsystem with mouse/trackpad input. Pen/highlighter, erase, undo/redo/clear, laser and whiteboard remain planned/proposed as recorded in the feature map.
- Capability-based input adapters: paired iPad/Pencil first remote case; attached pen devices and other touch/browser companions as qualified additions. No specific non-iPad hardware is promised supported yet.
- Device-neutral scene/ink data, optional pressure/tilt/hover, shared coordinate transforms and host-owned timing. Pairing and video preview apply only to adapters that need them.

## How to get to it (user POV)

Proposed paths; these controls are not currently present:

1. **No drawing:** open Clips and record normally. No extension picker or pairing prompt interrupts setup.
2. **Mouse/trackpad:** choose **Draw**, pick a tool, and enter drawing mode over the selected capture. Toggle back to pointer mode to operate the underlying app; visibly distinguish these modes. Keep a keyboard exit available so a full-screen drawing layer cannot trap input.
3. **Attached pen:** select a detected supported input if it needs configuration; basic pen input may use the local pointer adapter when appropriate. Enable advertised capabilities only after qualification.
4. **Paired device:** **Draw → Connect device**, choose an available adapter, pair and explicitly allow selected-area preview if needed. Ink enters the same scene used by local input.
5. Erase/undo/clear and finish. Verify the same accepted marks appear once on the Mac and in exported media. Disconnecting a companion leaves local controls usable.

## Driving it with native UI and adapter contract fixtures

Preconditions: the implemented host and adapters, a harmless calibration scene, and the actual hardware for device claims. Currently this is a verification plan only.

- With all optional modules disabled, complete ordinary capture/play/export; no device or network requirement may appear.
- Enter and exit mouse drawing mode, operate the Mac app between annotations, and inspect the exported scene. Verify letterboxing, region changes and undo history.
- Replay canonical strokes through a fixture adapter and compare scene revisions/geometry against local input. Fixtures prove the host contract, not device latency/palm rejection.
- Qualify the iPad flow with A-V01–A-V07; use equivalent target/ordering/reconnect tests for each additional adapter. Absence of pressure/hover must produce deliberate simple strokes.
- Disable or disconnect one input and verify accepted ink persists and another allowed input can operate. Initially permit one active drawing source at a time; handover is explicit to avoid conflicting undo/tool state.
- Exercise permission denial, malformed/stale/oversized events, cancellation and extension removal using X-V01–X-V10 as applicable. Report implementation and hardware evidence separately.

## Gotchas

- PencilKit drawing objects, vendor device IDs and transport packets must not become the canonical recording-package format. The adapter translates them at its boundary.
- Mouse annotation requires an explicit choice between drawing and clicking the underlying app. A remote pen can contribute ink while the Mac pointer stays usable, but that does not prove the local overlay receives both kinds of input correctly.
- Pairing is not required for local input; preview video is not required for an attached pen. Do not force every adapter through an iPad-shaped API.
- Multiple simultaneous drawers, collaborative whiteboards, semantic anchoring to app elements and arbitrary live effect code are outside the initial contract.
- Disabling the drawing subsystem must not disable recovery, baseline playback/export or diagnostic recording. Unknown extension edit data stays preserved alongside portable originals.
