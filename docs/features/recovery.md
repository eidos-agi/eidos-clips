# Keep and recover a recording

Baseline: [feature map](../FEATURE-MAP.md). IDs S01–S05. Main sources: [RecordingStore](../../Sources/ClipsCore/RecordingStore.swift), [SegmentedRecorder](../../Sources/ClipsMedia/SegmentedRecorder.swift), [MediaExport](../../Sources/ClipsMedia/MediaExport.swift), [recovery probe](../../scripts/recovery-probe.py).

## Sub-features

- Existing: relative-path `.eidosclip` packages, checked committed segments, independent audio tracks, retained originals, new-file export, visible failed packages.
- Partial: recovery of manifest-committed media after process kill; low-space reserve; normal Quit cleanup.
- Missing: orphan salvage/journal reconstruction, configurable storage and size display, recoverable deletion, proven sudden-power-loss handling.

## How to get to it (user POV)

1. A normal recording keeps an original under `~/Movies/Eidos Clips/Recordings/` and exports under the sibling `Exports/` folder.
2. After interruption/relaunch, open **Your clips**. Click a tile marked **Recover** to attempt export of verified completed media.
3. If the package is damaged, opening it reports an error; the original remains. **Open recordings folder** gives Finder access for diagnosis.
4. Low disk or media errors appear in the current notice area. There is no separate Recovery Center, trash view, or diagnostic bundle button yet.

## Driving it with native UI and process-kill probes

Preconditions: expendable synthetic media or a permitted test recording, an isolated evidence folder, and the PID of the exact instance started by the test. Never kill by process name or fill the user's system disk.

- Existing CI runs the recovery probe after the development build. Inspect `foundation-evidence.json` for each kill point and the decoded frames/audio actually retained, not only process exit status.
- Before any committed video, recovery must reject false success. After committed checkpoints, decode the retained output and compare source hashes before/after recovery.
- Corrupt a copied fixture segment without changing its size; expect export refusal and unchanged originals. This proves detection, not repair.
- On a physical Mac, separately exercise normal Quit, repeated stop, source-ended races, and reopen through the actual library. Use a controlled disposable volume for low-space/read-only/destination-loss tests.
- Relevant cases: V05–V12, V26/V28/V30. Report tested bounds and failures; no fixed loss guarantee is established.

## Gotchas

- Two seconds is a target segment duration, not the maximum possible loss after a crash.
- A missing/corrupt manifest or committed segment blocks recovery; orphan media is retained but not reconstructed. Do not call V11 passed because corruption was rejected.
- The 128 MiB reserve is a defensive threshold, not a measured guarantee for every failure or storage device.
- A successful synthetic SIGKILL test is not evidence for sudden power loss, device unplug, interrupted permissions, or a two-hour real call.
- Automatic deletion/eviction is absent. Future Restart/Discard should use recoverable trash; exports and originals need separate retention decisions.
