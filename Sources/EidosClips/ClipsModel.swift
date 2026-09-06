import AppKit
import AVKit
import Combine
import UniformTypeIdentifiers
import ClipsCore
import ClipsMedia

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
    @Published var page: ClipsPage = .record
    @Published var phase: CaptureState = .idle
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
    @Published var title = ""
    @Published var duration = 0.0
    @Published var trimStart = 0.0
    @Published var trimEnd = 0.0
    @Published var trimming = false
    var showWindow: (() -> Void)?
    var stateChanged: (() -> Void)?
    private var timer: Timer?
    var active: Bool { phase != .idle }
    var canRecord: Bool { !active && !busy }
    var filteredClips: [LibraryClip] { clips.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    var displayName: String { displayNames.indices.contains(displayIndex) ? displayNames[displayIndex] : "Choose a display" }

    init() {
        capture.changed = { [weak self] in
            guard let self else { return }
            self.phase = self.capture.state.value
            self.stateChanged?()
        }
        capture.report = { [weak self] message in self?.notice = message }
        capture.completed = { [weak self] package, export in self?.openReview(package: package, export: export) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed = self?.capture.elapsed ?? 0 }
        }
        refreshLibrary()
    }

    func navigate(_ destination: ClipsPage) {
        guard !active, !busy else { return }
        player.pause(); notice = nil; page = destination
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
                displayIndex = min(displayIndex, max(0, displayNames.count - 1))
            } catch { notice = error.localizedDescription }
        }
    }

    func start() {
        guard canRecord else { return }
        player.pause(); page = .record; notice = nil
        Task { await capture.start(displayIndex: displayIndex, microphone: microphone, systemAudio: systemAudio, camera: camera) }
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
        guard let store = try? RecordingStore(open: url) else { return nil }
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
        busy = true; notice = clip.needsRecovery ? "Recovering the completed part of this recording…" : "Opening your clip…"
        Task {
            defer { busy = false }
            do {
                let result = try await ClipsMedia.MediaExport.export(package: clip.package, to: capture.exportURL(prefix: "Clip"))
                openReview(package: clip.package, export: result)
                notice = clip.needsRecovery ? "Recovered completed media. Review the ending before sharing." : nil
            } catch { notice = error.localizedDescription }
        }
    }

    func openReview(package: URL, export: URL) {
        guard let clip = readClip(package) else { return }
        selected = clip; title = clip.title; exportedURL = export; player = AVPlayer(url: export)
        duration = AVURLAsset(url: export).duration.seconds
        trimStart = 0; trimEnd = duration; trimming = false; page = .review
        refreshLibrary(); notice = nil; showWindow?()
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
        let range: ClosedRange<Double>? = trimming ? trimStart...trimEnd : nil
        busy = true; notice = "Exporting your clip…"
        Task {
            defer { busy = false }
            do {
                exportedURL = try await ClipsMedia.MediaExport.export(package: selected.package, to: url, trim: range)
                notice = "Exported. Your original recording is kept."
            } catch { notice = error.localizedDescription }
        }
    }

    func seek(_ seconds: Double) { player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) }
    func showFiles() {
        if let exportedURL, page == .review { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]); return }
        try? FileManager.default.createDirectory(at: capture.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(capture.root.deletingLastPathComponent())
    }
    func share() {
        guard let exportedURL, let view = NSApp.keyWindow?.contentView else { return }
        NSSharingServicePicker(items: [exportedURL]).show(relativeTo: NSRect(x: view.bounds.maxX - 180, y: view.bounds.maxY - 70, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
    static func time(_ seconds: Double) -> String {
        let value = Int(max(0, seconds.isFinite ? seconds : 0))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

