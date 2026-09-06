import Foundation
import AVFoundation
import ClipsCore
import ClipsModules

public enum MediaExport {
    /// Decode the entire segment. Metadata alone is insufficient evidence of a good file.
    public static func decodedSamples(at url: URL, kind: TrackKind = .video) throws -> Int {
        let asset = AVURLAsset(url: url)
        let type: AVMediaType = kind == .video ? .video : .audio
        guard let track = asset.tracks(withMediaType: type).first else { throw ClipsError.media("Expected media track is absent.") }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = kind == .video
            ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            : [AVFormatIDKey: kAudioFormatLinearPCM]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ClipsError.media("Cannot read this media track.") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ClipsError.media("Could not decode media.") }
        var count = 0
        while let buffer = output.copyNextSampleBuffer() { count += CMSampleBufferGetNumSamples(buffer) }
        guard reader.status == .completed else { throw reader.error ?? ClipsError.media("Media decoding failed.") }
        return count
    }

    /// Exports only manifest-committed, integrity-checked media. Originals are untouched.
    public static func export(package: URL, to destination: URL, trim: ClosedRange<Double>? = nil, recipe: EditRecipe? = nil, progress: @escaping (Double) -> Void = { _ in }) async throws -> URL {
        let began = ProcessInfo.processInfo.systemUptime
        DiagnosticLog.shared.record(.exportStarted)
        try Task.checkCancellation()
        let store = try RecordingStore(open: package)
        let segments = try store.verifiedSegments()
        guard segments.contains(where: { $0.kind == .video }) else {
            throw ClipsError.media("No finalized video segment is available yet. The original is retained.")
        }
        let composition = AVMutableComposition()
        let first = segments.map(\.start).min() ?? 0
        var mixes: [AVAudioMixInputParameters] = []
        for kind in TrackKind.allCases {
            let parts = segments.filter { $0.kind == kind }.sorted { $0.start < $1.start }
            guard !parts.isEmpty else { continue }
            let type: AVMediaType = kind == .video ? .video : .audio
            guard let target = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ClipsError.media("Could not create the export track.")
            }
            var end = 0.0
            for part in parts {
                try Task.checkCancellation()
                let url = try store.segmentURL(part.file)
                guard try decodedSamples(at: url, kind: kind) > 0 else { throw ClipsError.media("Empty segment.") }
                let asset = AVURLAsset(url: url)
                guard let source = asset.tracks(withMediaType: type).first else { throw ClipsError.media("Missing source track.") }
                let start = max(0, part.start - first)
                // AAC priming and rounding can extend track metadata a little. Clip to captured duration.
                let length = min(part.duration, source.timeRange.duration.seconds)
                guard length.isFinite, length > 0, start + 0.01 >= end else {
                    throw ClipsError.media("Media segments have an inconsistent timeline.")
                }
                try target.insertTimeRange(CMTimeRange(start: source.timeRange.start,
                    duration: CMTime(seconds: length, preferredTimescale: 60_000)), of: source,
                    at: CMTime(seconds: max(start, end), preferredTimescale: 60_000))
                end = max(start, end) + length
            }
            if kind != .video {
                let mix = AVMutableAudioMixInputParameters(track: target)
                mixes.append(mix)
            }
        }
        if let recipe {
            try recipe.validate(duration: composition.duration.seconds)
            var end = composition.duration.seconds
            for range in recipe.ranges.reversed() {
                if end > range.end { composition.removeTimeRange(CMTimeRange(start: CMTime(seconds: range.end, preferredTimescale: 60_000), duration: CMTime(seconds: end - range.end, preferredTimescale: 60_000))) }
                end = range.start
            }
            if end > 0 { composition.removeTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: end, preferredTimescale: 60_000))) }
        }
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ClipsError.media("MP4 export is unavailable.")
        }
        let fullDuration = composition.duration.seconds
        let range = trim ?? 0...fullDuration
        guard range.lowerBound.isFinite, range.upperBound.isFinite, range.lowerBound >= 0,
              range.upperBound <= fullDuration + 0.05, range.upperBound > range.lowerBound else {
            throw ClipsError.media("Trim bounds must be inside the recording.")
        }
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ClipsError.storage("A file already exists there. Choose a new filename.")
        }
        let temporary = folder.appendingPathComponent(".export-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        exporter.outputURL = temporary
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        exporter.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 60_000),
                                        duration: CMTime(seconds: range.upperBound - range.lowerBound, preferredTimescale: 60_000))
        if !mixes.isEmpty {
            for parameters in mixes {
                (parameters as? AVMutableAudioMixInputParameters)?.setVolume(1 / Float(mixes.count), at: .zero)
            }
            let mix = AVMutableAudioMix(); mix.inputParameters = mixes; exporter.audioMix = mix
        }
        let monitor = Task {
            while !Task.isCancelled {
                progress(Double(exporter.progress))
                do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
            }
        }
        defer { monitor.cancel() }
        try await withTaskCancellationHandler(operation: { try Task.checkCancellation(); await exporter.export() }, onCancel: { exporter.cancelExport() })
        try Task.checkCancellation()
        guard exporter.status == .completed else { throw exporter.error ?? ClipsError.media("Export did not complete.") }
        guard try decodedSamples(at: temporary) > 0 else { throw ClipsError.media("Export contains no video.") }
        if !mixes.isEmpty { _ = try decodedSamples(at: temporary, kind: .microphone) }
        let handle = try FileHandle(forWritingTo: temporary); try handle.synchronize(); try handle.close()
        try FileManager.default.moveItem(at: temporary, to: destination)
        progress(1)
        DiagnosticLog.shared.record(.exportCompleted, [.durationMs: (ProcessInfo.processInfo.systemUptime - began) * 1000])
        return destination
    }
}
