# Requested build: compact capture and modular tools

Daniel's request is now in executable code. [FEATURE-MAP.md](FEATURE-MAP.md) tracks all 57 features; [BUILD-PLAN.md](BUILD-PLAN.md) orders completion and gives local-agent instructions; [BUILD-REVIEW.md](BUILD-REVIEW.md) records exact evidence.

| Requested behavior | Implementation | Remaining acceptance |
|---|---|---|
| Include Clips in the take | ScreenCaptureKit filter includes own windows, camera and drawing; own process audio excluded | Physical output check for each selected area/display |
| Compact panel and recording strip | 420-point ready panel; main hides during recording; floating timer/pause/draw/finish; reopen/menu/global controls | Real multi-display interaction and accessibility |
| Drag a region, Esc to cancel | Per-display selector, top-left normalized geometry, stable display identity and sourceRect | Retina/mixed-DPI/rotated/negative-origin captured pixels |
| Structured local logs | Typed bounded JSONL, one-second utility-queue flush/fsync, lifecycle/configuration/input/encoder/export events | Real overhead and complete fault attribution |
| Reports back to the repo | Strict public packet validator, local outbox, local-agent Git publisher, isolated worktree/retry/ack | Local agent configuration and a real incident-to-fix cycle |
| Draw from iPad with Pencil | Native companion, encrypted nearby link, confirm codes on both devices, explicit selected-area preview, normalized ink | Physical iPad provisioning, radio pairing, Pencil feel/latency and exported ink |
| Modules/adapters without core coupling | Real typed registry; pointer/nearby inputs, editor/exporter, caption processor, folder/watch destinations; recorder owns Stop | External plugin containment and additional vendor adapters remain future work |

Built alongside that brief: countdown/cancel, remembered input choices, device menus, recording meters, global shortcuts, separate preview/export jobs, cut-middle export, saved recipes, captions, local notes, verified preview cache, Recently Deleted/undo, verified folder copies and portable watch folders.

No native build or simulator closes physical acceptance. Company notarization still requires the existing Eidos signing Mac. A portable watch folder is local output; hosted links, provider accounts, comments and view analytics are unimplemented parts of the wider roadmap. There is no arbitrary third-party code loader.
