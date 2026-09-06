# What a complete Loom-type experience still needs

Discussion baseline: September 6, 2026. [FEATURE-MAP.md](FEATURE-MAP.md) describes the actual Clips source. This page broadens the opportunity list beyond the four immediate WANT.md changes. These are recommendations and scope choices, not implemented features or promises of a particular release date.

Loom's published capabilities span recording, editing, accessible playback, sharing, and content management. It advertises share links, embeds, captions, drawing and feedback; its editing includes trimming/stitching and overlays. See [Loom's recorder overview](https://www.loom.com/screen-recorder) and [product overview](https://www.loom.com/). Access controls are a separate documented sharing capability: [video permissions](https://support.atlassian.com/loom/docs/manage-the-permissions-and-privacy-of-your-videos/). Availability varies by plan/platform; this comparison is about product capabilities, not price or entitlement parity.

## Opportunity map

| ID | User expectation or opportunity | Clips gap | Recommended treatment |
|---|---|---|---|
| O01 | Start a good take quickly | Compact controls, countdown/cancel, stable device selection, meters, test playback and presets missing | Complete the recorder before adding destinations |
| O02 | Show exactly the right thing | No region/window picker, real scope preview, or persistent boundary | Region is already requested; retain window selection on the map for the following slice |
| O03 | Direct the viewer's attention | Cursor visible but no click emphasis, drawing, arrows, spotlight/zoom, or recording markers | High-value demo improvements; test click emphasis and drawing first. [Loom click emphasis](https://support.atlassian.com/loom/docs/highlight-your-mouse-clicks/), [drawing](https://support.atlassian.com/loom/docs/use-the-drawing-tool/) |
| O04 | Avoid revealing something private | No blur/redaction tools, notification suppression integration, or pre-share privacy review | Add explicit privacy tools; do not assume selected-scope capture alone solves this. A blurred export does not remove material from the retained original |
| O05 | Present confidently | Camera bubble cannot resize/persist placement; no camera-only mode, speaker notes, background treatment, or chosen quality preset | Prioritize bubble controls and camera-only if useful; notes/backgrounds later. Notes must stay outside captured scope under the new include-Clips policy. [Loom capture options](https://support.atlassian.com/loom/docs/choose-your-recording-mode/) |
| O06 | Fix a mistake without starting over | Only leading/trailing trim; no remove-middle, stitch takes, undo/history, or saved edits | Next editing step: cut a middle mistake and join takes while keeping originals; avoid a general editor timeline until needed |
| O07 | Make speech accessible and searchable | No captions/transcript files, editable transcript, chapters, summary or transcript search | Attach a chosen local/external processor; retain portable SRT/VTT/text and time alignment. Do not require AI to record. [Loom enhancements](https://support.atlassian.com/loom/docs/enhance-and-personalize-your-videos/) |
| O08 | Send one link the recipient can watch immediately | Local MP4 and Share sheet only; no hosted playback page or confirmed share URL | Biggest gap for Loom-style video messaging. Design a destination adapter and a small playback page with mobile/keyboard playback, speed/seek/captions, and optional download |
| O09 | Know who can view it and revoke access | No link access policy, password/expiry/revocation, or recipient-access check | Required if O08 ships; access semantics belong to the selected provider, not a misleading generic Private badge |
| O10 | Discuss a specific moment | No timestamped comments, reactions, follow-up links or embed workflow | Later collaboration layer; a timestamped link plus chosen task/agent system may cover the first need without another notification inbox |
| O11 | Find, organize, and reuse past work | Title search only; no folders/projects/notes, import, archive/trash, or duplicate | Extend the small library; keep storage/export state visible and avoid deleting originals after delivery |
| O12 | See whether a message helped | No viewer completion/engagement evidence | Optional recipient analytics after sharing exists; aggregate and permission-aware. Forward useful events to a chosen log/task destination |
| O13 | Install, update, and recover reliably | Release script exists; executed clean-install, upgrade/rollback and oldest-OS evidence missing | Stable company identity, saved data/grants, signed updates, explicit supported configurations |
| O14 | Report a broken or slow experience without detective work | No application diagnostic log or report outbox | Build structured telemetry and the repo feedback loop below with the recorder, not as an afterthought |
| O15 | Use it from a chosen agent or work system | No user CLI/MCP/events; fixture probe only | Shared capture command contract and durable completion/error events; intelligence can be replaced without rewriting the recorder |

Loom's [published feature inventory](https://www.loom.com/pricing) also lists content management, recording enhancements and viewer/engagement insights. That is a useful completeness check, not a reason to copy every team administration or monetization feature.

## Suggested sequence for discussion

1. **Trust and control:** the four WANT.md items, diagnostic report outbox, permission/device readiness, real audio meters, countdown/cancel, physical capture evidence, and signed installation.
2. **A better explanation:** cursor emphasis, bubble size/position, global shortcuts, cut-middle/stitch, undo, captions, projects and recoverable trash.
3. **A useful recipient experience:** chosen-host playback link, explicit access/revoke behavior, timestamps, captions and mobile playback. Folder handoff remains valuable but does not meet the same user expectation as a watch link.
4. **Optional intelligence and collaboration:** transcript search, chapters/tasks, processing adapters, comments and engagement events where actual use justifies them.

Two decisions matter more than decorative polish: whether the first release focuses on short demos or long calls, and whether sharing means sending a local file or delivering a watchable link. Keep both opportunities visible; do not silently treat file export as a complete Loom replacement.

## Improvement loop

Every requested feature, observed failure, and measured bottleneck should resolve to a stable feature-map ID. The [diagnostics design](DIAGNOSTICS.md) specifies the event coverage, local evidence, sanitized repository report, deduplication and regression-test loop. Successes need timing evidence too, so the agent can see slow setup, repeated exports and resource growth before they become crashes.

This comparison does not change the no-required-account/local-recording promise or authorize automatic uploads. Hosted playback, processing, and diagnostic publication each have an explicit destination contract.
