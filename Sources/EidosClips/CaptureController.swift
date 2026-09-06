import AppKit
import AVFoundation
import ScreenCaptureKit
import ClipsCore
import ClipsMedia
import ClipsModules
import CoreImage

final class CaptureSink: NSObject, SCStreamOutput, SCStreamDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    let recorder: SegmentedRecorder
    let failed: (Error) -> Void
    let meter: (TrackKind, Double?) -> Void
    private let meterLock = NSLock()
    private var meterTime: [TrackKind: Double] = [:]
    private func measure(_ sample: CMSampleBuffer, kind: TrackKind) {
        let now = ProcessInfo.processInfo.systemUptime
        meterLock.lock()
        let previous = meterTime[kind]
        guard now - (previous ?? 0) >= 0.1 else { meterLock.unlock(); return }
        meterTime[kind] = now; meterLock.unlock()
        if previous == nil { DiagnosticLog.shared.record(.inputSummary, [kind == .microphone ? .microphone : .systemAudio: 1, .count: 1]) }
        meter(kind, AudioMeter.decibels(sample))
    }
    private var latestScreen: CMSampleBuffer?
    private var cadence: DispatchSourceTimer?
    private let previewLock = NSLock()
    private var previewCallback: ((Data) -> Void)?
    var preview: ((Data) -> Void)? {
        get { previewLock.lock(); defer { previewLock.unlock() }; return previewCallback }
        set { previewLock.lock(); previewCallback = newValue; previewLock.unlock() }
    }
    private let imageContext = CIContext()
    private var lastPreview = 0.0
    private var completeCount = 0
    private var incompleteCount = 0
    private var lastSummary = 0.0
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
    init(recorder: SegmentedRecorder, meter: @escaping (TrackKind, Double?) -> Void, failed: @escaping (Error) -> Void) { self.recorder = recorder; self.meter = meter; self.failed = failed }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .audio { measure(sample, kind: .systemAudio); recorder.append(sample, kind: .systemAudio); return }
        guard type == .screen, let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
              attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue else { incompleteCount += 1; return }
        completeCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastSummary >= 5 {
            DiagnosticLog.shared.record(.inputSummary, [.complete: Double(completeCount), .incomplete: Double(incompleteCount)])
            lastSummary = now; completeCount = 0; incompleteCount = 0
        }
        if let preview, now - lastPreview >= 0.3, let buffer = CMSampleBufferGetImageBuffer(sample) {
            lastPreview = now
            let image = CIImage(cvPixelBuffer: buffer)
            let scaled = image.transformed(by: CGAffineTransform(scaleX: min(1, 960 / image.extent.width), y: min(1, 960 / image.extent.width)))
            if let jpeg = imageContext.jpegRepresentation(of: scaled, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.5]) { preview(jpeg) }
        }
        // ScreenCaptureKit can stop producing complete frames on a static desktop.
        // Hold the last complete image on a host-clock cadence so duration still advances.
        latestScreen = sample
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { failed(error) }
    func captureOutput(_ output: AVCaptureOutput, didOutput sample: CMSampleBuffer, from connection: AVCaptureConnection) {
        measure(sample, kind: .microphone)
        recorder.append(sample, kind: .microphone)
    }
}

@MainActor
final class CaptureController {
    var root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Eidos Clips/Recordings")
    var state = SessionState()
    var changed: (() -> Void)?
    var report: ((String) -> Void)?
    var completed: ((URL) -> Void)?
    var audioLevel: ((TrackKind, Double?) -> Void)?
    var prepared: ((UInt32, CaptureRegion?) -> Void)?
    var packageReady: ((URL) -> Void)?
    var preview: ((Data) -> Void)? { didSet { sink?.preview = preview } }
    var displays: [SCDisplay] = []
    private var recorder: SegmentedRecorder?
    private var stream: SCStream?
    private var sink: CaptureSink?
    private var devices: AVCaptureSession?
    private var cameraWindow: NSWindow?
    private var stopTask: Task<URL?, Error>?
    private var clock: SessionClock?
    private var pendingFailure: Error?
    private var inputObservers: [NSObjectProtocol] = []
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

    func start(displayID: UInt32?, region: CaptureRegion?, microphone: Bool, systemAudio: Bool, camera: Bool, microphoneID: String? = nil, cameraID: String? = nil) async {
        guard state.value == .idle else { return }
        pendingFailure = nil
        do {
            DiagnosticLog.shared.record(.capturePreparing)
            try state.transition(to: .preparing); changed?(); report?("Preparing capture…")
            try await refreshDisplays()
            guard !displays.isEmpty else { throw ClipsError.media("No display is available.") }
            guard let display = displayID == nil ? displays.first : displays.first(where: { $0.displayID == displayID }) else { throw ClipsError.media("The selected display disconnected. Choose a display again.") }
            if microphone {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                DiagnosticLog.shared.record(.permissionResult, [.microphone: 1, .success: granted ? 1 : 0])
                guard granted else {
                    throw ClipsError.media("Microphone access was denied. Allow it or turn microphone recording off before starting.")
                }
            }
            if camera {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                DiagnosticLog.shared.record(.permissionResult, [.camera: 1, .success: granted ? 1 : 0])
                guard granted else {
                    throw ClipsError.media("Camera access was denied. Allow it or turn the camera off before starting.")
                }
            }
            if let pendingFailure { throw pendingFailure }
            let origin = SegmentedRecorder.hostTime
            clock = SessionClock(origin: origin)
            var required: Set<TrackKind> = [.video]
            if microphone { required.insert(.microphone) }
            if systemAudio { required.insert(.systemAudio) }
            let writer = try SegmentedRecorder(root: root, title: "Clip \(Date().formatted(date: .abbreviated, time: .shortened))", origin: origin, requiredTracks: required) { [weak self] error in
                Task { @MainActor in await self?.interrupt(error) }
            }
            recorder = writer
            DiagnosticLog.shared.setSession(UUID(uuidString: writer.packageURL.deletingPathExtension().lastPathComponent))
            packageReady?(writer.packageURL)
            let callback = CaptureSink(recorder: writer, meter: { [weak self] kind, level in Task { @MainActor in self?.audioLevel?(kind, level) } }) { [weak self] error in
                Task { @MainActor in await self?.interrupt(error) }
            }
            sink = callback; callback.preview = preview
            let session = AVCaptureSession()
            session.beginConfiguration()
            if microphone {
                guard let mic = microphoneID == nil ? AVCaptureDevice.default(for: .audio) : AVCaptureDevice.devices(for: .audio).first(where: { $0.uniqueID == microphoneID }) else { throw ClipsError.media("No microphone is connected.") }
                let input = try AVCaptureDeviceInput(device: mic)
                guard session.canAddInput(input) else { throw ClipsError.media("Cannot use the selected microphone.") }
                session.addInput(input)
                let output = AVCaptureAudioDataOutput()
                output.setSampleBufferDelegate(callback, queue: DispatchQueue(label: "com.eidos.clips.microphone"))
                guard session.canAddOutput(output) else { throw ClipsError.media("Cannot capture microphone audio.") }
                session.addOutput(output)
            }
            if camera {
                guard let device = cameraID == nil ? AVCaptureDevice.default(for: .video) : AVCaptureDevice.devices(for: .video).first(where: { $0.uniqueID == cameraID }) else { throw ClipsError.media("No camera is connected.") }
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw ClipsError.media("Cannot use the camera.") }
                session.addInput(input)
                showCamera(session: session, display: display)
            }
            session.commitConfiguration()
            devices = session
            observeInputs(session: session, displayID: display.displayID)
            if microphone || camera { session.startRunning() }

            // Clips windows, camera and annotations are intentionally included in the recording.
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            let regionWidth = region?.width ?? 1, regionHeight = region?.height ?? 1
            if let region {
                config.sourceRect = CGRect(x: region.x * display.frame.width, y: region.y * display.frame.height,
                    width: region.width * display.frame.width, height: region.height * display.frame.height)
            }
            let width = Double(CGDisplayPixelsWide(display.displayID)) * regionWidth
            let height = Double(CGDisplayPixelsHigh(display.displayID)) * regionHeight
            let scale = min(1, 1920 / max(width, height))
            config.width = max(2, Int(width * scale) & ~1)
            config.height = max(2, Int(height * scale) & ~1)
            DiagnosticLog.shared.record(.captureConfiguration, [.width: Double(config.width), .height: Double(config.height),
                .region: region == nil ? 0 : 1, .microphone: microphone ? 1 : 0, .systemAudio: systemAudio ? 1 : 0, .camera: camera ? 1 : 0])
            prepared?(display.displayID, region)
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
            DiagnosticLog.shared.record(.captureStarted)
            report?("Recording display \(display.displayID). Completed segments are kept on this Mac.")
            changed?()
        } catch {
            if let stream { try? await stream.stopCapture() }
            stream = nil
            sink?.stopCadence()
            clearInputObservers()
            devices?.stopRunning(); devices = nil
            cameraWindow?.close(); cameraWindow = nil
            if let recorder { _ = try? await recorder.finish(interrupted: true) }
            recorder = nil; sink = nil; clock = nil
            state = SessionState()
            DiagnosticLog.shared.record(.captureFailed)
            report?(error.localizedDescription); changed?()
        }
    }

    func cancelPreparation() { if state.value == .preparing { pendingFailure = CancellationError() } }
    func togglePause() {
        let now = SegmentedRecorder.hostTime
        do {
            if state.value == .recording {
                try state.transition(to: .paused); try clock?.pause(at: now); DiagnosticLog.shared.record(.capturePaused); recorder?.pause(at: now)
                report?("Paused. Paused time will be removed from the recording.")
            } else if state.value == .paused {
                try state.transition(to: .recording); try clock?.resume(at: now); DiagnosticLog.shared.record(.captureResumed); recorder?.resume(at: now)
                report?("Recording resumed.")
            }
            changed?()
        } catch { report?(error.localizedDescription) }
    }

    func stop(interrupted: Bool = false) async throws -> URL? {
        if let stopTask { return try await stopTask.value }
        guard let writer = recorder, state.value != .idle else { return nil }
        if state.value == .recording {
            let end = SegmentedRecorder.hostTime
            try clock?.pause(at: end); writer.pause(at: end)
        }
        try state.transition(to: .finalizing); changed?(); report?("Finishing and checking the recording…")
        let task = Task<URL?, Error> {
            if let stream { try? await stream.stopCapture() }
            stream = nil
            sink?.stopCadence()
            clearInputObservers()
            devices?.stopRunning(); devices = nil
            cameraWindow?.close(); cameraWindow = nil
            let package = try await writer.finish(interrupted: interrupted)
            DiagnosticLog.shared.record(.captureStopped, [.durationMs: elapsed * 1000])
            completed?(package)
            report?(interrupted ? "Interrupted recording retained. Review completed media before use." : "Recording saved. Your original take is retained.")
            return package
        }
        stopTask = task
        defer {
            stopTask = nil; recorder = nil; sink = nil; clock = nil
            DiagnosticLog.shared.setSession(nil)
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
        DiagnosticLog.shared.record(.captureFailed)
        if state.value == .preparing { pendingFailure = error; return }
        guard state.value == .recording || state.value == .paused else { return }
        _ = try? await stop(interrupted: true)
        report?("Capture interrupted: \(error.localizedDescription). Completed segments were retained.")
    }

    private func clearInputObservers() {
        for observer in inputObservers { NotificationCenter.default.removeObserver(observer) }; inputObservers.removeAll()
    }
    private func observeInputs(session: AVCaptureSession, displayID: UInt32) {
        clearInputObservers()
        let devices = Set(session.inputs.compactMap { ($0 as? AVCaptureDeviceInput)?.device.uniqueID })
        let geometry = CGDisplayBounds(displayID)
        inputObservers.append(NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { [weak self] notification in
            guard let device = notification.object as? AVCaptureDevice, devices.contains(device.uniqueID) else { return }
            Task { @MainActor in await self?.interrupt(ClipsError.media("A requested microphone or camera disconnected.")) }
        })
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            inputObservers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.interrupt(ClipsError.media("A requested capture input was interrupted.")) }
            })
        }
        inputObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard CGDisplayIsOnline(displayID) == 0 || CGDisplayBounds(displayID) != geometry else { return }
            Task { @MainActor in await self?.interrupt(ClipsError.media("The selected display disconnected or changed its layout. Choose the recording area again.")) }
        })
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
