import Foundation
import CryptoKit
import Darwin

public enum TrackKind: String, Codable, CaseIterable { case video, microphone, systemAudio }
public enum RecordingStatus: String, Codable { case recording, ready, interrupted, failed }

public struct Segment: Codable, Equatable {
    public let file: String
    public let kind: TrackKind
    public let start: Double
    public let duration: Double
    public let bytes: Int
    public let sha256: String
    public init(file: String, kind: TrackKind, start: Double, duration: Double, bytes: Int, sha256: String) {
        self.file = file; self.kind = kind; self.start = start; self.duration = duration
        self.bytes = bytes; self.sha256 = sha256
    }
}

public struct RecordingManifest: Codable {
    public var schemaVersion = 1
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var status: RecordingStatus
    public var segments: [Segment]
    public var error: String?
    public var duration: Double { segments.map { $0.start + $0.duration }.max() ?? 0 }
}

/// One serial media queue owns mutations. Readers load independent snapshots.
public final class RecordingStore {
    public let url: URL
    public private(set) var manifest: RecordingManifest
    public static let manifestName = "manifest.json"

    public init(root: URL, title: String) throws {
        let id = UUID()
        url = root.appendingPathComponent(id.uuidString + ".eidosclip", isDirectory: true)
        manifest = RecordingManifest(id: id, title: title, createdAt: Date(), status: .recording, segments: [])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
                                              attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: url.appendingPathComponent("segments"),
                                              withIntermediateDirectories: false,
                                              attributes: [.posixPermissions: 0o700])
        try persist()
    }

    public init(open url: URL) throws {
        self.url = url.standardizedFileURL
        try Self.requireType(self.url, .typeDirectory)
        let manifestURL = self.url.appendingPathComponent(Self.manifestName)
        try Self.requireType(manifestURL, .typeRegular)
        let attributes = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) < 8_000_000 else {
            throw ClipsError.invalidPackage("Recording manifest is too large.")
        }
        manifest = try JSONDecoder().decode(RecordingManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schemaVersion == 1 else { throw ClipsError.invalidPackage("Unsupported recording version.") }
        guard manifest.segments.count <= 30_000 else { throw ClipsError.invalidPackage("Too many media segments.") }
    }

    public static func digest(_ url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var hash = SHA256()
        while let data = try input.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public func segmentURL(_ relative: String) throws -> URL {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == "segments", parts[1].hasSuffix(".mov"),
              UUID(uuidString: String(parts[1].dropLast(4))) != nil else {
            throw ClipsError.invalidPackage("Invalid media path.")
        }
        let directory = url.appendingPathComponent("segments")
        try Self.requireType(directory, .typeDirectory)
        let file = url.appendingPathComponent(relative)
        try Self.requireType(file, .typeRegular)
        guard file.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/") else {
            throw ClipsError.invalidPackage("Media path escapes its recording.")
        }
        return file
    }

    public func commit(file: URL, kind: TrackKind, start: Double, duration: Double) throws {
        guard start.isFinite, start >= 0, duration.isFinite, duration > 0 else {
            throw ClipsError.invalidPackage("Invalid segment timing.")
        }
        let relative = "segments/" + file.lastPathComponent
        let safe = try segmentURL(relative)
        guard safe.standardizedFileURL == file.standardizedFileURL else {
            throw ClipsError.invalidPackage("Unexpected segment location.")
        }
        let handle = try FileHandle(forWritingTo: safe)
        try handle.synchronize(); try handle.close()
        let bytes = try FileManager.default.attributesOfItem(atPath: safe.path)[.size] as? NSNumber
        guard let count = bytes?.intValue, count > 0 else { throw ClipsError.media("Empty media segment.") }
        guard !manifest.segments.contains(where: { $0.file == relative }) else {
            throw ClipsError.invalidPackage("Segment already committed.")
        }
        let previous = manifest
        manifest.segments.append(Segment(file: relative, kind: kind, start: start,
                                         duration: duration, bytes: count, sha256: try Self.digest(safe)))
        manifest.segments.sort { $0.start < $1.start }
        do { try persist() } catch { manifest = previous; throw error }
    }

    public func verifiedSegments() throws -> [Segment] {
        var seen = Set<String>()
        for segment in manifest.segments {
            guard seen.insert(segment.file).inserted, segment.start.isFinite, segment.start >= 0,
                  segment.duration.isFinite, segment.duration > 0, segment.bytes > 0 else {
                throw ClipsError.invalidPackage("Invalid or duplicate segment metadata.")
            }
            let file = try segmentURL(segment.file)
            let bytes = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber
            guard bytes?.intValue == segment.bytes, try Self.digest(file) == segment.sha256 else {
                throw ClipsError.invalidPackage("Media integrity check failed: \(file.lastPathComponent)")
            }
        }
        return manifest.segments
    }

    public func finish(_ status: RecordingStatus, error: String? = nil) throws {
        guard status != .recording else { throw ClipsError.invalidState("Invalid finish state.") }
        if status == .ready && !manifest.segments.contains(where: { $0.kind == .video }) {
            throw ClipsError.media("No completed video was captured. The partial recording was retained.")
        }
        manifest.status = status; manifest.error = error
        try persist()
    }

    public func rename(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { throw ClipsError.invalidPackage("Use a title of 1–200 characters.") }
        manifest.title = trimmed
        try persist()
    }

    public static func recordings(in root: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "eidosclip" }
            .sorted {
                let left = (try? RecordingStore(open: $0).manifest.createdAt) ?? .distantPast
                let right = (try? RecordingStore(open: $1).manifest.createdAt) ?? .distantPast
                return left > right
            }
    }

    private static func requireType(_ url: URL, _ type: FileAttributeType) throws {
        guard try FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == type else {
            throw ClipsError.invalidPackage("Expected \(type.rawValue) at \(url.lastPathComponent); links are not accepted.")
        }
    }

    private func persist() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let temporary = url.appendingPathComponent(".manifest-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: temporary)
        try handle.synchronize(); try handle.close()
        guard Darwin.rename(temporary.path, url.appendingPathComponent(Self.manifestName).path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { Darwin.close(descriptor) }
        guard fsync(descriptor) == 0 else { throw POSIXError(.EIO) }
    }
}
