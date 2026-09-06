import AppKit
import AVFoundation
import ScreenCaptureKit
import ClipsCore
import ClipsMedia

final class CaptureSink: NSObject, SCStreamOutput, SCStreamDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    let recorder: SegmentedRecorder
    let failed: (Error) -> Void
    private var latestScreen: CMSampleBuffer?
    private var cadence: DispatchSourceTimer?
    func startCadence(on queue: DispatchQueue) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, let sample = self.latestScreen else { return }
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
            var held: CMSampleBuffer?
            guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample,
                sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &held) == noErr,
                let held else { self.failed(ClipsError.media("Could not preserve the screen frame.")); return }
            self.recorder.append(held, kind: .video)
        }
        cadence = timer; timer.resume()
    }
    func stopCadence() { cadence?.cancel(); cadence = nil }
    deinit { cadence?.cancel() }
    init(recorder: SegmentedRecorder, failed: @escaping (Error) -> Void) { self.recorder = recorder; self.failed = failed }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .audio { recorder.append(sample, kind: .systemAudio); return }
        guard type == .screen, let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
              attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue else { return }
        // ScreenCaptureKit can stop producing complete frames on a static desktop.
        // Hold the last complete image on a host-clock cadence so duration still advances.
        latestScreen = sample
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { failed(error) }
    func captureOutput(_ output: AVCaptureOutput, didOutput sample: CMSampleBuffer, from connection: AVCaptureConnection) {
        recorder.append(sample, kind: .microphone)
    }
}

@MainActor
final class CaptureController {
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Eidos Clips/Recordings")
    var state = SessionState()
    var changed: (() -> Void)?
    var report: ((String) -> Void)?
    var completed: ((URL, URL) -> Void)?
    var displays: [SCDisplay] = []
    private var recorder: SegmentedRecorder?
    private var stream: SCStream?
    private var sink: CaptureSink?
    private var devices: AVCaptureSession?
    private var cameraWindow: NSWindow?
    private var stopTask: Task<URL?, Error>?
    private var clock: SessionClock?
    private var pendingFailure: Error?
    var elapsed: Double { clock?.elapsed(at: SegmentedRecorder.hostTime) ?? 0 }

    func refreshDisplays() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw ClipsError.media("Allow Screen Recording for Eidos Clips in System Settings, then reopen the app.")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        displays = content.displays
        changed?()
    }

    func start(displayIndex: Int, microphone: Bool, systemAudio: Bool, camera: Bool) async {
        guard state.value == .idle else { return }
        pendingFailure = nil
        do {
            try state.transition(to: .preparing); changed?(); report?("Preparing capture…")
            try await refreshDisplays()
            guard !displays.isEmpty else { throw ClipsError.media("No display is available.") }
            let display = displays[min(max(displayIndex, 0), displays.count - 1)]
            if microphone {
                guard await AVCaptureDevice.requestAccess(for: .audio) else {
                    throw ClipsError.media("Microphone access was denied. Allow it or turn microphone recording off before starting.")
                }
            }
            if camera {
                guard await AVCaptureDevice.requestAccess(for: .video) else {
                    throw ClipsError.media("Camera access was denied. Allow it or turn the camera off before starting.")
                }
            }
            let origin = SegmentedRecorder.hostTime
            clock = SessionClock(origin: origin)
            var required: Set<TrackKind> = [.video]
            if microphone { required.insert(.microphone) }
            if systemAudio { required.insert(.systemAudio) }
            let writer = try SegmentedRecorder(root: root, title: "Clip \(Date().formatted(date: .abbreviated, time: .shortened))", origin: origin, requiredTracks: required) { [weak self] error in
                Task { @MainActor in await self?.interrupt(error) }
            }
            recorder = writer
            let callback = CaptureSink(recorder: writer) { [weak self] error in
                Task { @MainActor in await self?.interrupt(error) }
            }
            sink = callback
            let session = AVCaptureSession()
            session.beginConfiguration()
            if microphone {
                guard let mic = AVCaptureDevice.default(for: .audio) else { throw ClipsError.media("No microphone is connected.") }
                let input = try AVCaptureDeviceInput(device: mic)
                guard session.canAddInput(input) else { throw ClipsError.media("Cannot use the selected microphone.") }
                session.addInput(input)
                let output = AVCaptureAudioDataOutput()
                output.setSampleBufferDelegate(callback, queue: DispatchQueue(label: "com.eidos.clips.microphone"))
                guard session.canAddOutput(output) else { throw ClipsError.media("Cannot capture microphone audio.") }
                session.addOutput(output)
            }
            if camera {
                guard let device = AVCaptureDevice.default(for: .video) else { throw ClipsError.media("No camera is connected.") }
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw ClipsError.media("Cannot use the camera.") }
                session.addInput(input)
                showCamera(session: session, display: display)
            }
            session.commitConfiguration()
            devices = session
            if microphone || camera { session.startRunning() }

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let cameraID = cameraWindow.flatMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil }
            let included = content.windows.filter { cameraID == $0.windowID }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: included)
            let config = SCStreamConfiguration()
            let width = Int(display.width), height = Int(display.height)
            let scale = min(1, 1920.0 / Double(width))
            config.width = max(2, Int(Double(width) * scale) & ~1)
            config.height = max(2, Int(Double(height) * scale) & ~1)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.queueDepth = 4; config.showsCursor = true
            config.capturesAudio = systemAudio; config.excludesCurrentProcessAudio = true
            config.sampleRate = 48_000; config.channelCount = 2
            let capture = SCStream(filter: filter, configuration: config, delegate: callback)
            let delivery = DispatchQueue(label: "com.eidos.clips.screen")
            try capture.addStreamOutput(callback, type: .screen, sampleHandlerQueue: delivery)
            if systemAudio { try capture.addStreamOutput(callback, type: .audio, sampleHandlerQueue: delivery) }
            stream = capture
            callback.startCadence(on: delivery)
            try await capture.startCapture()
            if let pendingFailure { throw pendingFailure }
            try state.transition(to: .recording)
            report?("Recording display \(display.displayID). Completed segments are kept on this Mac.")
            changed?()
        } catch {
            if let stream { try? await stream.stopCapture() }
            stream = nil
            sink?.stopCadence()
            devices?.stopRunning(); devices = nil
            cameraWindow?.close(); cameraWindow = nil
            if let recorder { _ = try? await recorder.finish(interrupted: true) }
            recorder = nil; sink = nil; clock = nil
            state = SessionState()
            report?(error.localizedDescription); changed?()
        }
    }

    func togglePause() {
        let now = SegmentedRecorder.hostTime
        do {
            if state.value == .recording {
                try state.transition(to: .paused); try clock?.pause(at: now); recorder?.pause(at: now)
                report?("Paused. Paused time will be removed from the recording.")
            } else if state.value == .paused {
                try state.transition(to: .recording); try clock?.resume(at: now); recorder?.resume(at: now)
                report?("Recording resumed.")
            }
            changed?()
        } catch { report?(error.localizedDescription) }
    }

    func stop(interrupted: Bool = false) async throws -> URL? {
        if let stopTask { return try await stopTask.value }
        guard let writer = recorder, state.value != .idle else { return nil }
        try state.transition(to: .finalizing); changed?(); report?("Finishing and checking the recording…")
        let task = Task<URL?, Error> {
            if let stream { try? await stream.stopCapture() }
            stream = nil
            sink?.stopCadence()
            devices?.stopRunning(); devices = nil
            cameraWindow?.close(); cameraWindow = nil
            let package = try await writer.finish(interrupted: interrupted)
            let export = try await MediaExport.export(package: package, to: exportURL(prefix: interrupted ? "Recovered" : "Clip"))
            completed?(package, export)
            report?(interrupted ? "Interrupted recording retained and exported. Review it before use." : "Saved and checked. Your original take is retained.")
            return export
        }
        stopTask = task
        defer {
            stopTask = nil; recorder = nil; sink = nil; clock = nil
            state = SessionState(); changed?()
        }
        do { return try await task.value } catch {
            report?("\(error.localizedDescription) Use Recover to inspect the retained recording.")
            throw error
        }
    }

    func exportURL(prefix: String) -> URL {
        root.deletingLastPathComponent().appendingPathComponent("Exports/\(prefix)-\(UUID().uuidString).mp4")
    }

    private func interrupt(_ error: Error) async {
        if state.value == .preparing { pendingFailure = error; return }
        guard state.value == .recording || state.value == .paused else { return }
        _ = try? await stop(interrupted: true)
        report?("Capture interrupted: \(error.localizedDescription). Completed segments were retained.")
    }

    private func showCamera(session: AVCaptureSession, display: SCDisplay) {
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID } ?? NSScreen.main!
        let side: CGFloat = 200
        let window = NSWindow(contentRect: NSRect(x: screen.frame.maxX - side - 30, y: screen.frame.minY + 40, width: side, height: side),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.isOpaque = false; window.backgroundColor = .clear
        window.level = .floating; window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = DraggableView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        view.wantsLayer = true; view.layer?.cornerRadius = side / 2; view.layer?.masksToBounds = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds; preview.videoGravity = .resizeAspectFill
        view.layer?.addSublayer(preview)
        window.contentView = view; window.orderFrontRegardless(); cameraWindow = window
    }
}

final class DraggableView: NSView { override var mouseDownCanMoveWindow: Bool { true } }
