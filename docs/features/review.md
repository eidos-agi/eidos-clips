# Review and find clips

Baseline: [feature map](../FEATURE-MAP.md). IDs E01–E04 and L01–L03. Main sources: [ClipsModel](../../Sources/EidosClips/ClipsModel.swift), [ClipsView](../../Sources/EidosClips/ClipsView.swift), [MediaExport](../../Sources/ClipsMedia/MediaExport.swift), [RecordingStore](../../Sources/ClipsCore/RecordingStore.swift).

## Sub-features

- Existing: playback/seek, rename, trim range, new MP4 export, Finder, Record another, thumbnail grid, title search.
- Partial: progress is busy text; original discovery exists but no full missing-file repair flow.
- Missing: persisted trim recipes, cancelable/background export queue, project/notes fields/search, trash/restore. Transcript search is later.

## How to get to it (user POV)

1. Finish a recording to enter **Review clip**, or open **Your clips** and click a tile. A damaged or unfinished package can show **Recover**.
2. Play/seek in the native player. Edit **Clip title** and press Return or **Save name**.
3. Enable **Trim**, set **Trim start** and **Trim end**, and click **Export trim**. Without trim, use **Export clip**. Choose a new MP4 path in the native save panel.
4. Use **Show in Finder** or **Share** for the current exported file. **Record another** returns to preparation while keeping the earlier take.
5. In **Your clips**, use **Find a clip** to search titles. **Open recordings folder** in the sidebar opens the local storage root.

## Driving it with native UI and media probes

Preconditions: an expendable clip with a known visible timeline and identifiable sound, plus a separate export destination. Preserve source hashes before edits.

- Finish → play → seek → rename → trim → export → QuickTime playback → Record another → reopen the earlier clip. Verify title persistence, frame boundaries, sound, file duration, and unchanged original bytes.
- Cancel the save panel; expect no new export and no new success claim. Try an occupied destination; verify no overwrite. Record the exact file offered by Share and Finder after each export.
- Search for matching and nonmatching titles, close/reopen the app, and verify the clip remains discoverable. Empty-library and no-match states are separate paths.
- Existing `swift test` media cases and `python3 scripts/recovery-probe.py .build/release/clips-probe dist/foundation-evidence.json` exercise synthetic export/trim/source preservation after building. They do not drive save panels or Share.
- Relevant cases: V25–V30 and V37. Keep action evidence distinct from the static library/review PNGs in CI.

## Gotchas

- Opening a library clip currently exports a new MP4 before review; repeated opens can create additional exports and add latency.
- Changing trim sliders does not create a new shared file. Share uses `exportedURL`, which changes only after a successful export. The product needs to keep that distinction clear.
- Trim bounds live in the model, not a persisted edit recipe. Reopening does not restore the edit.
- New capture is blocked during an export. A percentage indicator or background job queue is not implemented.
- Search covers titles only. There are no project, notes, transcript, or delete controls to test yet.
