# Agent and handoff contract

Proposed for M4; the CLI, event stream, and data model described here do not exist yet. A later stdio MCP adapter must reuse the same service operations and permission model.

## Interaction principle

An agent can help organize and process a finished clip. Recording, playback, editing, and export work without that agent. The app exposes local state and durable events instead of building a notification inbox. Optional processing must not hold up Stop, save, or review.

## Recording and artifact metadata

| Object | Required fields / meaning |
|---|---|
| Recording | schema_version, recording_id, title, created_at, capture_state, recorded_duration_ms, optional project_ref and notes |
| Capture configuration | selected scope, preset, source identifiers, dimensions, frame rate, color mode, camera placement/mirror, enabled audio sources |
| Track | track_id, kind, relative path, codec/format, timing origin, processing mode, retained duration, known gaps |
| Checkpoint | sequence, durable media boundary, track coverage, journal version; only committed after durable media |
| Edit | edit_revision, ordered retained time ranges; references immutable originals |
| Export artifact | artifact_id, recording_id, edit_revision, relative/local path, MIME type, bytes, SHA-256, duration, completed_at, validation result |
| Handoff job | job_id, artifact_id, destination_id, state, attempt count, last error, provider receipt if present |
| Event | event_id, sequence, schema_version, type, recording_id, optional artifact_id/job_id, occurred_at, minimal payload |

Project references are opaque values meaningful to the user's workflow; the app does not require a remote project database. Imported manifests are untrusted: validate schema, relative-path containment and symlinks, size bounds, and referenced files. Do not execute commands or follow arbitrary remote URLs embedded in metadata. Unknown schema versions open with a clear compatibility error or read-only mode, never destructive migration.

Device identifiers and local paths remain local. A handoff sidecar uses an explicit allowlist; omit device IDs, raw window titles, absolute home paths, and diagnostic logs by default. Do not include credentials. User notes or project metadata are transferred only as part of the chosen handoff policy.

## Proposed CLI surface

The final command spelling is fixed during implementation; these are the intended operations.

| Command | Effect | Scope |
|---|---|---|
| `eidos-clips status --json` | Current session state, selected preset, active inputs, and actionable errors | read_status |
| `eidos-clips list --json` | Clips within approved library/project scope | read_clips |
| `eidos-clips inspect <id> --json` | Metadata and available artifacts | read_clips |
| `eidos-clips start --preset <name> --request-id <id>` | Start the user-authorized preset with visible countdown/indicator | capture |
| `eidos-clips pause <session-id>` / `resume <session-id>` | Change the identified active session | capture |
| `eidos-clips stop <session-id>` | Finalize once and return the session/job status | capture |
| `eidos-clips export <id> --destination <name> --request-id <id>` | Produce validated MP4 in an approved destination | export |
| `eidos-clips handoff <artifact-id> --destination <name> --request-id <id>` | Queue an authorized artifact copy/transfer | handoff |
| `eidos-clips events --after <sequence> --json` | Replay and then follow authorized events | read_events |

Long-running commands return an operation ID and status; do not block indefinitely. Structured outcomes include invalid request, invalid state, permission denied, source unavailable, unsupported capability, storage full, canceled, and recoverable failure. Mutating request IDs deduplicate retries. A stale session ID must never stop a different active recording. Export and handoff require a completed validated artifact and known destination; reject unrestricted arbitrary paths.

## Local authorization

Automation is opt-in. Pair a local client once with revocable capabilities, allowed presets, library/project scope, and named destinations. Routine actions inside that grant do not demand repetitive approvals. Starting camera/microphone capture still obeys OS permission and the saved user capture policy; always display active capture. Expanding scope or adding an online destination requires explicit user choice.

Prefer authenticated local IPC with peer/code identity checks where available and a restrictive per-user socket/service. Avoid an unauthenticated localhost HTTP server. Any token is kept in the OS credential store and never supplied in logs or a public URL. Same-user untrusted processes must not inherit authority merely by reaching the endpoint. M4 must document the exact trust boundary and pairing mechanism before exposing capture commands.

No hidden call detection or autonomous always-on capture. A remote agent receives finished artifacts only through an explicitly configured route. Each destination/policy is separate so unrelated projects or accounts do not mix by default.

## Drawing adapters and paired companions

The [drawing subsystem](features/drawing.md) accepts local pointer/pen and paired-device adapters through the same canonical ink contract. Local input needs neither pairing nor streamed preview. The requested [iPad adapter](features/ipad-ink.md) is separate from the M4 coding-agent client. A paired drawing device receives only the explicitly selected screen/region preview, when its adapter requires it, and can send validated ink operations for that target. It does not inherit recording start/stop, arbitrary Mac input, library access, or upload authority. Separate permission for preview sharing from remembered device pairing; reconnect must not silently share the whole desktop.

Mac owns the session/timeline/target epoch and accepted ink revision. The proposed protocol carries versioned, bounded stroke events plus reliable commit/undo/clear and reconnect snapshots, with encrypted authenticated transport and revocation. Scope changes invalidate stale coordinates. Preview video goes to the iPad; ink returns to the Mac. Keep both contents out of logs and public diagnostic packets. The exact transport and iPadOS app/distribution path need a physical feasibility spike; no remote-control service has been implemented.

## Editor, processor and destination contracts

[PLUGINS.md](PLUGINS.md) defines separate owners for edit recipes, artifact processing, export validation and delivery receipts. Providers receive granted immutable artifacts and return typed proposals/results through host-owned jobs; they do not edit the recorder manifest directly. Include source digest/edit revision, adapter contract/version, operation ID, cancellation and idempotency semantics. Reject stale results and preserve originals when an adapter fails, is removed or becomes incompatible.

Keep built-in preview/trim/local MP4/native sharing usable without external installs. A richer editor, transcription model, share-link provider or diagnostic publisher can be replaced independently. Device input does not gain agent-control authority, and choosing an upload destination does not authorize sharing unrelated clips or diagnostics.

## Completion events

- `recording.ready`: the retained original passed validation and is available for review.
- `recording.interrupted`: useful material is retained with the reason and recovered duration.
- `export.completed`: a specific export revision is validated and has an immutable artifact identity/hash.
- `handoff.completed`: include completion level: local_copy, provider_upload, or share_link, plus corresponding evidence.
- `operation.failed`: a specific operation failed; include whether retry/recovery is possible.

Persist the terminal state and event together in a recoverable journal/outbox. Deliver at least once; consumers deduplicate by event_id and artifact_id. Define cursor retention and return a resync-needed response if a cursor is too old. Rebuilding from manifests must not fabricate a different artifact identity or trigger duplicate side effects. Consumers such as Reeves should react to `export.completed` for transferable video and use `recording.ready` only when they explicitly support the internal package.

M4's minimum pipeline proof is: create a synthetic clip → export it → deliver one event twice → a sample consumer writes one local acknowledgement. This tests the integration contract without uploading or invoking a paid model.

## Destination behavior

| Destination | Completion evidence | User-facing status |
|---|---|---|
| Local or synced folder | Copy completed and destination bytes/hash verified | Copied to folder |
| Native share sheet | Artifact provided to the selected share action; recipient delivery generally unknown | Opened share action; avoid an unsupported Delivered claim |
| Future object-storage provider | Provider confirms upload with expected object identity, size, and supported integrity evidence | Uploaded |
| Future share-link provider | Upload plus valid link and known access settings | Link ready |

M4 implements folder copies and native share-sheet handoff. Remote providers and hosted playback pages are deferred. A generic synced directory never becomes provider-confirmed just because local disk blocks disappear. Keep originals after handoff. Cleanup is a distinct user-controlled retention action.

A proposed future processor can write transcript, captions, summary, tasks, or clips back as derived artifacts referencing recording/export IDs. Preserve source provenance, model/processor version, and cost if applicable. Never replace original media with generated text. Let the processor and destination be replaceable; no fixed inference vendor, storage provider, Render service, or Eidos backend is required by the recorder.
