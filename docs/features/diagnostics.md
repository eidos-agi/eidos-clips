# Diagnose, build, and install

> **Implementation update — September 6, 2026:** Executable code now implements the compact capture, modular tools, local drawing, native iPad companion, editing/destination and diagnostic paths described in [../BUILD-PLAN.md](../BUILD-PLAN.md). Use [../FEATURE-MAP.md](../FEATURE-MAP.md) for current feature status and [../BUILD-REVIEW.md](../BUILD-REVIEW.md) for exact proof. Historical “missing/proposed” statements below describe the earlier baseline unless listed as still open in that ledger. Physical and signing acceptance are not implied.


Baseline: [feature map](../FEATURE-MAP.md). IDs D01–D05 and Q01–Q05. The full requested feedback-loop design is in [DIAGNOSTICS.md](../DIAGNOSTICS.md). Sources: [app lifecycle](../../Sources/EidosClips/main.swift), [encoder](../../Sources/ClipsMedia/SegmentedRecorder.swift), [native workflow](../../.github/workflows/native.yml), [release script](../../scripts/release-app.sh). Signing procedure: [LOCAL-AGENT.md](../LOCAL-AGENT.md) and [SIGNING.md](../SIGNING.md).

## Sub-features

- Existing: source-linked CI artifacts/logs, seven unit/media tests, synthetic recovery probe, native window render smoke, development package/icon, company signing/notarization script.
- Next: synchronous local diagnostic files at `~/Movies/Eidos Clips/Logs/` recording lifecycle, filter/output geometry, frame completeness, encoder wait milliseconds, queue overload, and export duration.
- Proposed: Reveal logs / Export diagnostics, bounded retention/rotation, random recording correlation ID and source/build identity. Do not log credentials, media bytes, window titles, or unnecessary personal paths.
- Requested extension: sanitized report outbox → validated local-agent repository commit → reproducer/fix/regression evidence. There is no working uploader yet.
- Unproven here: successful company notarization, actual signed download installation, physical device matrix, oldest-macOS support, long-session performance. Browser/other native platforms remain later work.

## How to get to it (user POV)

1. Today the app exposes notices near the current screen; it has no diagnostics menu or persisted application event log.
2. Developers can open the GitHub Actions run and download its Development artifact plus logs/PNG/JSON evidence. This is development packaging, not a trusted company download.
3. The authorized local Mac agent follows the signing handoff to run `bash scripts/release-app.sh` using the existing company keychain. No new key export or installed-app replacement is part of that script.
4. A future diagnostics action should reveal/export a bounded, content-free bundle a user can deliberately provide with a bug report.

## Driving it with build scripts and native UI

Preconditions: a clean exact-source checkout on an appropriate Mac; existing company keychain only for the release path. Record the OS/toolchain and archive hash. Tests/builds cannot run natively in the Linux authoring environment.

- Development: `swift test`, then `bash scripts/build-app.sh`. The workflow's native UI smoke renders recording/library/review/minimum-size screens using an isolated synthetic clip. Its commands are in the workflow; it does not interact through Accessibility or record a screen.
- Release: follow LOCAL-AGENT.md. Require the Eidos company identity, Apple Accepted status, staple validation, and Gatekeeper acceptance after unzipping the final archive. Keep evidence associated with the exact SHA.
- Installation: V36 still needs the actual quarantined download on a clean Mac/account, including permission behavior. Do not strip quarantine or bypass Gatekeeper.
- After D01 is implemented, perform a short start/pause/resume/stop/export and check a synchronous log tail immediately after each operation. Inject overload in a controlled fixture; verify latency/queue evidence without captured content. Test unwritable/full log destination and bounded log growth so diagnostics do not become the failure.
- V16–V17/V19–V21/V24/V36–V38 require physical evidence. A screenshot, accessibility failure, compile success, synthetic tone, and signed ZIP each establish different facts.

## Gotchas

- The local agent's Accessibility screenshot hung. Existing native renders can document appearance but do not verify real control actions or the installed app's behavior.
- Both dev and release builds currently use the same recording-data root. Separate bundle IDs do not isolate recordings; avoid driving two copies against the same user library.
- Synchronous logging must not add blocking file I/O to realtime audio callbacks. Aggregate frame statistics and write on a dedicated serial path; diagnose logging failures without recursive logging or unlimited memory.
- No GitHub releases were returned at the baseline fetch. An uncommitted local signed build may still exist; request its evidence through the local handoff rather than declaring it nonexistent.
- Public MIT source and a passing development build do not close M5.
