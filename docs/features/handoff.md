# Share and hand off

Baseline: [feature map](../FEATURE-MAP.md). IDs H01–H04 and L03. Main sources: [ClipsModel](../../Sources/EidosClips/ClipsModel.swift), [MediaExport](../../Sources/ClipsMedia/MediaExport.swift). Future contract: [INTEGRATIONS.md](../INTEGRATIONS.md).

## Sub-features

- Existing: ordinary local MP4, Finder reveal, native macOS Share sheet.
- Missing but planned: named folder destinations, verified copy/retry jobs, project metadata, local agent commands and replayable completion events.
- Later: provider-confirmed uploads/share links, optional transcription/captions/summaries, stdio MCP adapter when needed. No account/backend is required for local capture/export.

## How to get to it (user POV)

1. In **Review clip**, export the full clip or trim to a user-chosen file.
2. Click **Show in Finder** to locate it or **Share** to choose an available macOS share extension.
3. For now, an agent or recipient receives that ordinary file through an existing user-selected route. There is no **Send to agent**, paired-client setup, upload progress, or Copy link button.

## Driving it with native UI and file inspection

Preconditions: a harmless test MP4 and a deliberate local test destination. Sending a message or uploading a recording is a separate authorized action; merely opening the Share sheet is sufficient for this map's entry-point check.

- Export, reveal in Finder, open the revealed file in QuickTime, and compare its hash/duration with the intended export. Confirm Share is offering the current completed export.
- Cancel the Share sheet; do not claim anything was delivered. Choosing a share extension is not evidence of recipient access or remote durability.
- Future folder delivery must copy to a temporary name, verify bytes, finalize, and retain the original. Exercise offline/full destination/retry/restart and name collisions before closing V30–V31.
- Future agent commands must use the same lifecycle owner as buttons, require explicit capture authorization, and deduplicate command/event replay. V32–V34 need actual command/event evidence.

## Gotchas

- `clips-probe` is a synthetic verification executable, not an implemented user control API or MCP server.
- A local sync-folder copy can prove **Copied to folder**, not **Uploaded** or **Link ready**.
- Keep processing/provider failures out of the capture/save path. A usable local original must survive a failed handoff.
- There is no built-in transcript, hosted link, or team workspace to demonstrate yet. These are scope choices, not hidden existing capabilities.
