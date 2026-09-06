import Foundation
import AVFoundation
import CoreMedia
import ClipsCore

/// Finalized, independently readable track segments. All writer work is serialized.
/// The callback-facing enqueue is bounded and never blocks an audio callback.
public final class SegmentedRecorder: @unchecked Sendable {
    public let packageURL: URL
    private let store: RecordingStore
    private let queue = DispatchQueue(label: "com.eidos.clips.media", qos: .userInitiated)
    private let capacity = DispatchSemaphore(value: 64)
    private let ingressLock = NSLock()
    private var overloadReported = false
    private var lastSpaceCheck = -Double.infinity
    private var clock: SessionClock
    private var active: [TrackKind: Part] = [:]
    private var failure: Error?
    private var finishing = false
    private let segmentSeconds: Double
    private let onFailure: (Error) -> Void
    private let requiredTracks: Set<TrackKind>

    private final class Part {
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        let url: URL
        let kind: TrackKind
        let start: Double
        var lastPresentation = -Double.infinity
        var end: Double
        var samples = 0
        init(writer: AVAssetWriter, input: AVAssetWriterInput, url: URL, kind: TrackKind, start: Double) {
            self.writer = writer; self.input = input; self.url = url; self.kind = kind
            self.start = start; self.end = start
        }
    }

    public init(root: URL, title: String, origin: Double, segmentSeconds: Double = 2,
                requiredTracks: Set<TrackKind> = [.video], onFailure: @escaping (Error) -> Void = { _ in }) throws {
        guard segmentSeconds.isFinite, segmentSeconds > 0 else { throw ClipsError.media("Invalid segment length.") }
        store = try RecordingStore(root: root, title: title)
        packageURL = store.url
        clock = SessionClock(origin: origin)
        self.segmentSeconds = segmentSeconds
        self.onFailure = onFailure
        self.requiredTracks = requiredTracks.union([.video])
    }

    public static var hostTime: Double { CMClockGetTime(CMClockGetHostTimeClock()).seconds }

    public func append(_ sample: CMSampleBuffer, kind: TrackKind) {
        guard capacity.wait(timeout: .now()) == .success else {
            ingressLock.lock()
            let report = !overloadReported
            overloadReported = true
            ingressLock.unlock()
            if report { queue.async { self.fail(ClipsError.media("Capture could not keep up. Completed media was retained.")) } }
            return
        }
        queue.async {
            defer { self.capacity.signal() }
            guard !self.finishing, self.failure == nil else { return }
            do { try self.write(sample, kind: kind) } catch { self.fail(error) }
        }
    }

    public func pause(at time: Double) { queue.async { do { try self.clock.pause(at: time) } catch { self.fail(error) } } }
    public func resume(at time: Double) { queue.async { do { try self.clock.resume(at: time) } catch { self.fail(error) } } }

    public func finish(interrupted: Bool = false) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard !self.finishing else {
                    continuation.resume(throwing: ClipsError.invalidState("This recording has already stopped.")); return
                }
                self.finishing = true
                for part in self.active.values {
                    do { try self.seal(part) } catch { if self.failure == nil { self.failure = error } }
                }
                self.active.removeAll()
                let present = Set(self.store.manifest.segments.map(\.kind))
                let missing = self.requiredTracks.subtracting(present)
                if self.failure == nil && !missing.isEmpty {
                    self.failure = ClipsError.media("No completed media from: \(missing.map(\.rawValue).sorted().joined(separator: ", ")). The partial take was retained.")
                }
                do {
                    if let error = self.failure {
                        try self.store.finish(.failed, error: error.localizedDescription)
                        continuation.resume(throwing: error)
                    } else {
                        try self.store.finish(interrupted ? .interrupted : .ready)
                        continuation.resume(returning: self.packageURL)
                    }
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func fail(_ error: Error) {
        guard failure == nil else { return }
        failure = error
        onFailure(error)
    }

    private func write(_ sample: CMSampleBuffer, kind: TrackKind) throws {
        guard CMSampleBufferDataIsReady(sample),
              let mapped = clock.map(CMSampleBufferGetPresentationTimeStamp(sample).seconds) else { return }
        var part = active[kind]
        if let current = part, mapped - current.start >= segmentSeconds {
            // Finish is bounded. Captured callbacks queue through the bounded ingress above.
            try seal(current)
            active[kind] = nil
            part = nil
        }
        if part == nil {
            let made = try makePart(sample: sample, kind: kind, start: mapped)
            active[kind] = made; part = made
        }
        guard let current = part else { throw ClipsError.media("Missing media writer.") }
        guard mapped >= current.lastPresentation else {
            throw ClipsError.media("A media input delivered backwards timestamps. The partial take was retained.")
        }
        if mapped - lastSpaceCheck >= 1 {
            let available = try FileManager.default.attributesOfFileSystem(forPath: store.url.path)[.systemFreeSize] as? NSNumber
            guard let bytes = available?.int64Value, bytes > 128 * 1_048_576 else {
                throw ClipsError.storage("Less than 128 MB remains. Recording stopped to preserve completed media.")
            }
            lastSpaceCheck = mapped
        }
        let deadline = Date().addingTimeInterval(0.15)
        while !current.input.isReadyForMoreMediaData && current.writer.status == .writing && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        guard current.input.isReadyForMoreMediaData else {
            throw current.writer.error ?? ClipsError.media("The encoder could not keep up.")
        }
        let adjusted = try retime(sample, presentation: mapped)
        guard current.input.append(adjusted) else {
            throw current.writer.error ?? ClipsError.media("A media write failed.")
        }
        let duration = CMSampleBufferGetDuration(sample).seconds
        current.end = mapped + (duration.isFinite && duration > 0 ? duration : (kind == .video ? 1.0 / 30 : 0))
        current.lastPresentation = mapped
        current.samples += 1
    }

    private func makePart(sample: CMSampleBuffer, kind: TrackKind, start: Double) throws -> Part {
        let url = store.url.appendingPathComponent("segments/\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any]
        let mediaType: AVMediaType
        if kind == .video {
            guard let pixel = CMSampleBufferGetImageBuffer(sample) else { throw ClipsError.media("No video image.") }
            mediaType = .video
            settings = [AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: CVPixelBufferGetWidth(pixel), AVVideoHeightKey: CVPixelBufferGetHeight(pixel),
                        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000,
                                                           AVVideoMaxKeyFrameIntervalKey: 60]]
        } else {
            mediaType = .audio
            settings = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
                        AVNumberOfChannelsKey: kind == .microphone ? 1 : 2, AVEncoderBitRateKey: 128_000]
        }
        let input = AVAssetWriterInput(mediaType: mediaType, outputSettings: settings,
                                      sourceFormatHint: CMSampleBufferGetFormatDescription(sample))
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw ClipsError.media("Unsupported media format.") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ClipsError.media("Could not start the encoder.") }
        writer.startSession(atSourceTime: CMTime(seconds: start, preferredTimescale: 60_000))
        return Part(writer: writer, input: input, url: url, kind: kind, start: start)
    }

    private func seal(_ part: Part) throws {
        guard part.samples > 0 else { part.writer.cancelWriting(); return }
        guard part.writer.status == .writing else { throw part.writer.error ?? ClipsError.media("Writer is not active.") }
        part.writer.endSession(atSourceTime: CMTime(seconds: part.end, preferredTimescale: 60_000))
        part.input.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        part.writer.finishWriting { finished.signal() }
        guard finished.wait(timeout: .now() + 10) == .success else {
            throw ClipsError.media("Finalizing media timed out. The partial file was retained.")
        }
        guard part.writer.status == .completed else { throw part.writer.error ?? ClipsError.media("Media finalization failed.") }
        guard try MediaExport.decodedSamples(at: part.url, kind: part.kind) > 0 else {
            throw ClipsError.media("The saved segment cannot be decoded.")
        }
        try store.commit(file: part.url, kind: part.kind, start: part.start, duration: part.end - part.start)
    }

    private func retime(_ sample: CMSampleBuffer, presentation: Double) throws -> CMSampleBuffer {
        var count = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr,
              count > 0 else { throw ClipsError.media("Missing sample timing.") }
        var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &timing, entriesNeededOut: &count)
        let delta = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sample),
                                   CMTime(seconds: presentation, preferredTimescale: 60_000))
        for index in timing.indices {
            timing[index].presentationTimeStamp = CMTimeSubtract(timing[index].presentationTimeStamp, delta)
            if timing[index].decodeTimeStamp.isValid { timing[index].decodeTimeStamp = CMTimeSubtract(timing[index].decodeTimeStamp, delta) }
        }
        var result: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sample,
                sampleTimingEntryCount: count, sampleTimingArray: &timing, sampleBufferOut: &result) == noErr,
              let result else { throw ClipsError.media("Could not retime a sample.") }
        return result
    }
}
