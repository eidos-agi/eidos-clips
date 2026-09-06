import AppKit
import AVKit
import Combine
import UniformTypeIdentifiers
import ClipsCore
import ClipsMedia
import ClipsModules

enum ClipsPage { case record, library, review }

struct LibraryClip: Identifiable {
    let id: UUID
    let package: URL
    let title: String
    let date: Date
    let duration: Double
    let status: RecordingStatus
    var thumbnail: NSImage?
    var needsRecovery: Bool { status != .ready }
}

@MainActor
final class ClipsModel: ObservableObject {
    let capture = CaptureController()
    let registry = ExtensionRegistry()
    let drawing = DrawingController()
    let regionPicker = RegionPicker()
    let nearby = NearbyDrawingAdapter()
    private var remoteEpoch: UUID?
    let exportAdapter = NativeExportAdapter()
    let editProvider = BasicEditProvider()
    let folderDestination = LocalFolderDestination()
    let captionProcessor = SubtitleImportProcessor()
    let watchDestination = LocalWatchDestination()
    @Published var captions: [CaptionCue] = []
    @Published var captionText = ""
    let jobGate = JobGate()
    @Published var selectedDisplayID: UInt32?
    @Published var region: CaptureRegion?
    @Published var removeSelection = false
    @Published var jobProgress = 0.0
    @Published var modulesEnabled = true
    @Published var notes = ""
    @Published var lastTrashed: URL?
    private var job: Task<Void, Never>?
    private var annotationPackage: URL?
    private var annotationEvents: [AnnotationArchive.TimedInk] = []
    let annotationArchive = AnnotationArchive()
    private var targetFrame: CGRect?
    var quitting = false
    var configureWindow: (() -> Void)?
    @Published var page: ClipsPage = .record
    @Published var phase: CaptureState = .idle
    @Published var countdown = 0
    @Published var countdownEnabled = true
    private var countdownTask: Task<Void, Never>?
    @Published var microphoneID: String?
    @Published var cameraID: String?
    @Published var microphoneDevices: [AVCaptureDevice] = []
    @Published var cameraDevices: [AVCaptureDevice] = []
    @Published var micLevel: Double?
    @Published var systemLevel: Double?
    @Published var microphone = true
    @Published var systemAudio = false
    @Published var camera = false
    @Published var displayIndex = 0
    @Published var displayNames: [String] = []
    @Published var elapsed = 0.0
    @Published var notice: String?
    @Published var busy = false
    @Published var clips: [LibraryClip] = []
    @Published var search = ""
    @Published var selected: LibraryClip?
    @Published var exportedURL: URL?
    @Published var player = AVPlayer()
    @Published var poster: NSImage?
    @Published var hasPlayed = false
    private var playbackObservation: AnyCancellable?
    @Published var title = ""
    @Published var duration = 0.0
    @Published var trimStart = 0.0
    @Published var trimEnd = 0.0
    @Published var trimming = false
    var showWindow: (() -> Void)?
    var stateChanged: (() -> Void)?
    private var timer: Timer?
    var active: Bool { phase != .idle || countdown > 0 }
    var canRecord: Bool { !active && !busy }
    var filteredClips: [LibraryClip] { clips.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    var displayName: String { displayNames.indices.contains(displayIndex) ? displayNames[displayIndex] : "Choose a display" }

    init() {
        do {
            try registry.register(drawing: drawing.pointer); try registry.register(drawing: nearby)
            try registry.register(exporter: exportAdapter); try registry.register(editor: editProvider)
            try registry.register(destination: folderDestination)
            try registry.register(destination: watchDestination); try registry.register(processor: captionProcessor)
            try registry.register(ModuleDescriptor(id: "org.eidos.diagnostics.outbox", name: "Diagnostic outbox", capabilities: [.diagnostics]))
        } catch { notice = error.localizedDescription }
        nearby.onOperation = { [weak self] in self?.drawing.accept($0) }
        nearby.onConnection = { [weak self] approved in
            guard let self else { return }
            if approved { _ = self.drawing.useRemote(); self.synchronizeDevice() }
            else { self.drawing.usePointer(); self.capture.preview = nil; self.remoteEpoch = nil }
        }
        drawing.onSnapshot = { [weak self] snapshot in
            guard let self, self.nearby.approved, self.remoteEpoch != snapshot.epoch else { return }
            self.synchronizeDevice()
        }
        DiagnosticLog.shared.record(.appLaunch)
        capture.audioLevel = { [weak self] kind, level in if kind == .microphone { self?.micLevel = level } else { self?.systemLevel = level } }
        capture.packageReady = { [weak self] in self?.annotationPackage = $0; self?.annotationEvents = [] }
        capture.prepared = { [weak self] displayID, region in self?.prepareDrawing(displayID: displayID, region: region) }
        annotationArchive.failed = { [weak self] in Task { @MainActor in self?.notice = "Drawing sidecar could not be saved. Recorded video is retained." } }
        drawing.onRejected = { [weak self] in self?.nearby.deactivate(); self?.drawing.setInteractive(false) }
        drawing.onAccepted = { [weak self] operation in
            guard let self else { return }
            if self.nearby.approved && (operation.kind == .clear || operation.kind == .undo) { self.synchronizeDevice() }
            guard self.phase == .recording, self.annotationEvents.count < 20_000 else { return }
            self.annotationEvents.append(AnnotationArchive.TimedInk(elapsed: self.capture.elapsed, operation: operation))
            if operation.kind != .append { self.saveAnnotations() }
        }

        capture.changed = { [weak self] in
            guard let self else { return }
            let previous = self.phase
            self.phase = self.capture.state.value
            if self.phase != previous { self.drawing.invalidateInput() }
            self.drawing.inputAllowed = self.phase == .recording
            self.synchronizeDevice()
            if self.phase == .idle { self.nearby.sharingPreview = false; self.capture.preview = nil }
            if self.phase == .idle { self.saveAnnotations(); self.drawing.hide(); self.annotationPackage = nil }
            self.stateChanged?()
        }
        capture.report = { [weak self] message in self?.notice = message }
        capture.completed = { [weak self] package in
            self?.saveAnnotations()
            guard self?.quitting != true else { return }
            Task { @MainActor in guard let self, !self.quitting, let clip = self.readClip(package) else { return }; self.open(clip) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.elapsed = self.capture.elapsed
                let time = self.player.currentTime().seconds
                self.captionText = self.captions.filter { $0.start <= time && time < $0.end }.map(\.text).joined(separator: "\n")
            }
        }
        let preferences = UserDefaults.standard
        microphone = preferences.object(forKey: "microphone") as? Bool ?? true
        systemAudio = preferences.bool(forKey: "systemAudio"); camera = preferences.bool(forKey: "camera")
        countdownEnabled = preferences.object(forKey: "countdown") as? Bool ?? true
        microphoneID = preferences.string(forKey: "microphoneID"); cameraID = preferences.string(forKey: "cameraID")
        microphoneDevices = AVCaptureDevice.devices(for: .audio); cameraDevices = AVCaptureDevice.devices(for: .video)
        if let path = preferences.string(forKey: "recordingsPath") { capture.root = URL(fileURLWithPath: path, isDirectory: true) }
        refreshLibrary()
    }

    func navigate(_ destination: ClipsPage) {
        guard !active, !busy else { return }
        player.pause(); notice = nil; page = destination; configureWindow?()
        if destination == .library { refreshLibrary() }
    }

    func chooseDisplay() {
        guard canRecord else { return }
        busy = true; notice = nil
        Task {
            defer { busy = false }
            do {
                try await capture.refreshDisplays()
                displayNames = capture.displays.enumerated().map { index, display in
                    "Display \(index + 1) · \(display.width) × \(display.height)"
                }
                if let id = selectedDisplayID, let index = capture.displays.firstIndex(where: { $0.displayID == id }) { displayIndex = index }
                else { displayIndex = 0; selectedDisplayID = capture.displays.first?.displayID; region = nil }
            } catch { notice = error.localizedDescription }
        }
    }

    func start() {
        guard canRecord else { return }
        player.pause(); page = .record; notice = nil
        micLevel = nil; systemLevel = nil
        DiagnosticLog.shared.record(.commandAccepted)
        drawing.reset()
        if nearby.approved { _ = drawing.useRemote(); synchronizeDevice() }
        let preferences = UserDefaults.standard
        preferences.set(microphone, forKey: "microphone"); preferences.set(systemAudio, forKey: "systemAudio"); preferences.set(camera, forKey: "camera")
        preferences.set(microphoneID, forKey: "microphoneID"); preferences.set(cameraID, forKey: "cameraID"); preferences.set(countdownEnabled, forKey: "countdown")
        countdown = countdownEnabled ? 3 : 0
        countdownTask = Task {
            while countdown > 0 {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard !Task.isCancelled else { return }; countdown -= 1
            }
            guard !Task.isCancelled else { return }
            await capture.start(displayID: selectedDisplayID, region: region, microphone: microphone, systemAudio: systemAudio, camera: camera, microphoneID: microphoneID, cameraID: cameraID)
            countdownTask = nil
        }
    }
    func cancelPreparation() { countdownTask?.cancel(); countdownTask = nil; countdown = 0; capture.cancelPreparation(); notice = "Recording preparation cancelled." }
    func chooseRecordingFolder() {
        guard canRecord else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Use for recordings"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        capture.root = url.appendingPathComponent("Recordings", isDirectory: true)
        UserDefaults.standard.set(capture.root.path, forKey: "recordingsPath"); refreshLibrary()
    }
    func pause() { capture.togglePause() }
    func stop() {
        guard phase == .recording || phase == .paused else { return }
        Task { _ = try? await capture.stop(); refreshLibrary() }
    }

    func refreshLibrary() {
        clips = RecordingStore.recordings(in: capture.root).compactMap { readClip($0) }
    }

    func readClip(_ url: URL) -> LibraryClip? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let store = try? RecordingStore(open: url) else {
            // Damaged packages stay discoverable; opening them reports the underlying error.
            return LibraryClip(id: UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID(),
                package: url, title: "Recording needs attention", date: .distantPast,
                duration: 0, status: .failed, thumbnail: nil)
        }
        let m = store.manifest
        return LibraryClip(id: m.id, package: url, title: m.title, date: m.createdAt,
                           duration: m.duration, status: m.status, thumbnail: nil)
    }

    func loadThumbnail(_ clip: LibraryClip) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard let store = try? RecordingStore(open: clip.package),
                  let first = store.manifest.segments.first(where: { $0.kind == .video }),
                  let url = try? store.segmentURL(first.file) else { return nil }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 560, height: 320)
            guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            return NSImage(cgImage: image, size: .zero)
        }.value
    }

    func open(_ clip: LibraryClip) {
        guard canRecord else { return }
        busy = true; jobProgress = 0; notice = clip.needsRecovery ? "Recovering completed media…" : "Opening your clip…"
        job = Task {
            defer { busy = false; job = nil }
            do {
                let input = try artifact(for: clip.package)
                let request = JobRequest(adapter: exportAdapter.descriptor, input: input); jobGate.begin(request)
                let cache = capture.root.deletingLastPathComponent().appendingPathComponent("Previews")
                try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
                let movie = cache.appendingPathComponent(input.sha256 + ".mp4")
                let checksum = cache.appendingPathComponent(input.sha256 + ".sha256")
                let expected = try? String(contentsOf: checksum)
                let actual = try? await RecordingStore.digestAsync(movie)
                let cacheValid = expected?.count == 64 && actual != nil && expected == actual
                if !cacheValid {
                    try? FileManager.default.removeItem(at: movie)
                    _ = try await exportAdapter.run(package: clip.package, request: request, to: movie) { value in Task { @MainActor in self.jobProgress = value } }
                    let digest = try await RecordingStore.digestAsync(movie)
                    try digest.write(to: checksum, atomically: true, encoding: .utf8)
                }
                guard jobGate.finish(request, input: try artifact(for: clip.package)) else { throw CancellationError() }
                openReview(package: clip.package, export: movie)
                notice = clip.needsRecovery ? "Recovered completed media. Review the ending before sharing." : nil
            } catch is CancellationError { notice = "Cancelled. Your recording is kept." }
            catch { notice = error.localizedDescription; DiagnosticLog.shared.record(.exportFailed) }
        }
    }

    func openReview(package: URL, export: URL) {
        guard let clip = readClip(package) else { return }
        selected = clip; title = clip.title; exportedURL = export; player = AVPlayer(url: export)
        poster = nil; hasPlayed = false
        playbackObservation = player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main).sink { [weak self] state in
            if state == .playing { self?.hasPlayed = true }
        }
        Task {
            let image = await loadThumbnail(clip)
            if self.selected?.id == clip.id { self.poster = image }
        }
        duration = AVURLAsset(url: export).duration.seconds
        trimStart = 0; trimEnd = duration; trimming = false; page = .review
        captions = (try? JSONDecoder().decode([CaptionCue].self, from: Data(contentsOf: package.appendingPathComponent("captions.json")))) ?? []
        notes = (try? String(contentsOf: package.appendingPathComponent("notes.txt"))) ?? ""
        refreshLibrary(); notice = nil; configureWindow?(); showWindow?()
    }

    func saveTitle() {
        guard let selected, canRecord else { return }
        do {
            try RecordingStore(open: selected.package).rename(title)
            self.selected = readClip(selected.package); refreshLibrary(); notice = "Title saved."
        } catch { notice = error.localizedDescription }
    }

    func export() {
        guard let selected, canRecord else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = (name.isEmpty ? "Clip" : name) + (trimming ? "-trimmed.mp4" : ".mp4")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true; jobProgress = 0; notice = "Exporting your clip…"
        job = Task {
            defer { busy = false; job = nil }
            do {
                let input = try artifact(for: selected.package)
                let request = JobRequest(adapter: exportAdapter.descriptor, input: input); jobGate.begin(request)
                guard !trimming || registry.editor(editProvider.descriptor.id) != nil else { throw ModuleError.invalid("Editing module is disabled.") }
                let recipe = trimming ? try registry.editor(editProvider.descriptor.id)?.recipe(duration: duration, selection: EditRange(trimStart, trimEnd), removeSelection: removeSelection) : nil
                guard let exporter = registry.exporter(exportAdapter.descriptor.id) else { throw ModuleError.invalid("Export is unavailable.") }
                let result = try await exporter.run(package: selected.package, request: request, to: url, recipe: recipe, progress: { value in Task { @MainActor in self.jobProgress = value } })
                guard jobGate.finish(request, input: try artifact(for: selected.package)) else { throw CancellationError() }
                exportedURL = result
                if !captions.isEmpty { try Captions.webVTT(recipe.map { Captions.remap(captions, through: $0) } ?? captions).write(to: result.deletingPathExtension().appendingPathExtension("vtt"), options: .atomic) }
                if let recipe { try JSONEncoder().encode(recipe).write(to: result.deletingPathExtension().appendingPathExtension("edit.json"), options: .atomic) }
                notice = "Exported. Your original recording is kept."
            } catch is CancellationError { notice = "Cancelled. Your recording is kept." }
            catch { notice = error.localizedDescription; DiagnosticLog.shared.record(.exportFailed) }
        }
    }
    func cancelJob() { jobGate.cancel(); job?.cancel() }
    func cancelAndWaitForJob() async { let current = job; cancelJob(); await current?.value }
    private func artifact(for package: URL) throws -> ArtifactReference {
        let store = try RecordingStore(open: package)
        return ArtifactReference(id: store.manifest.id, sha256: try RecordingStore.digest(package.appendingPathComponent(RecordingStore.manifestName)), revision: 1)
    }
    func selectDisplay(_ index: Int) {
        guard canRecord, capture.displays.indices.contains(index) else { return }
        displayIndex = index; selectedDisplayID = capture.displays[index].displayID; region = nil
    }
    func chooseRegion() {
        guard canRecord else { return }
        regionPicker.begin { [weak self] id, region in
            guard let self, let region else { return }
            self.selectedDisplayID = id; self.region = region
            if let index = self.capture.displays.firstIndex(where: { $0.displayID == id }) { self.displayIndex = index }
            self.notice = "Area selected. Clips controls inside this area will be recorded."
        }
    }
    func prepareDrawing(displayID: UInt32, region: CaptureRegion?) {
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID }) else { return }
        let frame: CGRect
        if let r = region {
            frame = CGRect(x: screen.frame.minX + r.x * screen.frame.width,
                y: screen.frame.maxY - (r.y + r.height) * screen.frame.height,
                width: r.width * screen.frame.width, height: r.height * screen.frame.height)
        } else { frame = screen.frame }
        targetFrame = frame
        if modulesEnabled { drawing.show(frame: frame, interactive: false) }; synchronizeDevice()
    }
    func toggleDrawing() {
        guard registry.drawingInput(drawing.pointer.descriptor.id) != nil, phase == .recording || phase == .paused else { return }
        if nearby.approved { nearby.deactivate(); drawing.usePointer() }
        drawing.setInteractive(!drawing.enabled)
    }
    func saveAnnotations() {
        guard let package = annotationPackage else { return }
        annotationArchive.submit(package: package, snapshot: drawing.scene.snapshot, events: annotationEvents)
    }
    func setModulesEnabled(_ value: Bool) {
        modulesEnabled = value
        for module in registry.modules where module.id != exportAdapter.descriptor.id { registry.setEnabled(value, id: module.id) }
        if !value { nearby.deactivate(); drawing.hide() }
        else if let frame = targetFrame, active { drawing.show(frame: frame, interactive: false) }
        if !value { trimming = false }
        DiagnosticLog.shared.record(value ? .moduleEnabled : .moduleDisabled)
    }
    func synchronizeDevice() {
        guard nearby.approved else { return }
        remoteEpoch = drawing.scene.epoch
        let frame = targetFrame ?? CGRect(x: 0, y: 0, width: 16, height: 9)
        nearby.synchronize(RemoteCanvas(snapshot: drawing.scene.snapshot, aspectRatio: frame.width / max(1, frame.height), acceptsInput: phase == .recording && modulesEnabled))
    }
    func shareDevicePreview(_ value: Bool) {
        nearby.sharingPreview = value
        if !value, nearby.approved { try? nearby.link.send(.init(.preview)) }
        capture.preview = value ? { [weak self] data in Task { @MainActor in guard let self, self.phase == .recording else { return }; self.nearby.sendPreview(data) } } : nil
    }
    func diagnosticReport() {
        do {
            let dirty = Bundle.main.object(forInfoDictionaryKey: "ClipsSourceDirty") as? Bool ?? false
            let sha = dirty ? "local" : (Bundle.main.object(forInfoDictionaryKey: "ClipsSourceCommit") as? String ?? ProcessInfo.processInfo.environment["GITHUB_SHA"] ?? "local")
            let url = try DiagnosticLog.shared.createReport(sourceCommit: sha)
            NSWorkspace.shared.activateFileViewerSelecting([url]); notice = "Report saved for your local agent. No recording content is included."
        } catch { notice = error.localizedDescription }
    }
    func saveNotes() {
        guard let selected, notes.utf8.count <= 100_000 else { return }
        do { try notes.write(to: selected.package.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8); notice = "Notes saved locally." }
        catch { notice = error.localizedDescription }
    }
    func trash(_ clip: LibraryClip) {
        guard canRecord else { return }
        do {
            let folder = capture.root.deletingLastPathComponent().appendingPathComponent("Recently Deleted")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(clip.package.lastPathComponent)
            try FileManager.default.moveItem(at: clip.package, to: destination); lastTrashed = destination
            if selected?.id == clip.id { player.pause(); page = .library; selected = nil }
            refreshLibrary(); notice = "Moved to Recently Deleted. You can undo this move."
        } catch { notice = error.localizedDescription }
    }
    func restoreLastTrash() {
        guard let url = lastTrashed, canRecord else { return }
        do { try FileManager.default.moveItem(at: url, to: capture.root.appendingPathComponent(url.lastPathComponent)); lastTrashed = nil; refreshLibrary(); notice = "Recording restored." }
        catch { notice = error.localizedDescription }
    }
    func saveCopy() {
        guard let source = exportedURL, canRecord else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]; panel.nameFieldStringValue = "Clip-copy.mp4"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true
        job = Task {
            defer { busy = false; job = nil }
            do {
                let input = ArtifactReference(id: UUID(), sha256: try await RecordingStore.digestAsync(source), revision: 1)
                let request = JobRequest(adapter: folderDestination.descriptor, input: input)
                guard let adapter = registry.destination(folderDestination.descriptor.id) else { throw ModuleError.invalid("Folder delivery module is disabled.") }
                _ = try await adapter.deliver(source, request: request, to: destination)
                notice = "Verified copy saved."
            } catch { notice = error.localizedDescription }
        }
    }

    func importCaptions() {
        guard let selected, canRecord, let processor = registry.processor(captionProcessor.descriptor.id) else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText, UTType(filenameExtension: "vtt") ?? .plainText]
        panel.message = "Choose an SRT or WebVTT file. Caption text stays with this recording."
        guard panel.runModal() == .OK, let source = panel.url else { return }
        busy = true
        job = Task {
            defer { busy = false; job = nil }
            let output = selected.package.appendingPathComponent(".captions-\(UUID()).vtt")
            defer { try? FileManager.default.removeItem(at: output) }
            do {
                guard let bytes = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber, bytes.intValue <= 1_000_000 else { throw ModuleError.invalid("Use a caption file under 1 MB.") }
                let request = JobRequest(adapter: processor.descriptor, input: ArtifactReference(id: selected.id, sha256: try await RecordingStore.digestAsync(source), revision: 1))
                _ = try await processor.process(source, request: request, to: output)
                let cues = try Captions.parse(Data(contentsOf: output))
                guard cues.allSatisfy({ $0.end <= duration + 0.1 }) else { throw ModuleError.invalid("Caption timing extends beyond this recording.") }
                try JSONEncoder().encode(cues).write(to: selected.package.appendingPathComponent("captions.json"), options: .atomic)
                captions = cues; notice = "Captions imported. Exports include an aligned WebVTT file."
            } catch { notice = error.localizedDescription }
        }
    }
    func saveWatchFolder() {
        guard let source = exportedURL, canRecord, let adapter = registry.destination(watchDestination.descriptor.id) else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Clips Watch"
        panel.message = "Save a folder with a video and player page. Send the whole folder to your recipient."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true
        job = Task {
            defer { busy = false; job = nil }
            do {
                let request = JobRequest(adapter: adapter.descriptor, input: ArtifactReference(id: UUID(), sha256: try await RecordingStore.digestAsync(source), revision: 1))
                _ = try await adapter.deliver(source, request: request, to: destination)
                notice = "Watch folder saved. Send the whole folder; this does not create a hosted link."
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch { notice = error.localizedDescription }
        }
    }

    func seek(_ seconds: Double) { hasPlayed = true; player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) }
    func showFiles() {
        if let exportedURL, page == .review { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]); return }
        try? FileManager.default.createDirectory(at: capture.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(capture.root.deletingLastPathComponent())
    }
    func share() {
        guard let exportedURL, let view = NSApp.keyWindow?.contentView else { return }
        NSSharingServicePicker(items: [exportedURL]).show(relativeTo: NSRect(x: view.bounds.maxX - 180, y: view.bounds.maxY - 70, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
    static func trimTime(_ seconds: Double) -> String {
        let tenths = Int((max(0, seconds.isFinite ? seconds : 0) * 10).rounded())
        return String(format: "%02d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
    }
    static func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

