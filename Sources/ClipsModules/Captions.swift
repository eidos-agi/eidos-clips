import Foundation
import CryptoKit

public struct CaptionCue: Codable, Equatable {
    public let start: Double
    public let end: Double
    public let text: String
    public init(start: Double, end: Double, text: String) { self.start = start; self.end = end; self.text = text }
}
public enum Captions {
    public static func parse(_ data: Data) throws -> [CaptionCue] {
        guard data.count <= 1_000_000, var text = String(data: data, encoding: .utf8) else { throw ModuleError.invalid("Use an SRT or WebVTT text file under 1 MB.") }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var result: [CaptionCue] = []
        for block in text.components(separatedBy: "\n\n") {
            let lines = block.components(separatedBy: "\n")
            if block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lines.first?.hasPrefix("WEBVTT") == true { continue }
            guard let index = lines.firstIndex(where: { $0.contains(" --> ") }), index <= 1 else { throw ModuleError.invalid("Caption blocks must contain a timing line and text.") }
            let times = lines[index].components(separatedBy: " --> ")
            guard times.count == 2, let start = time(times[0]), let end = time(times[1]), end > start,
                  start >= (result.last?.start ?? 0) else { throw ModuleError.invalid("Caption timing is invalid or out of order.") }
            let content = lines.dropFirst(index + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
            guard !content.isEmpty, content.utf8.count <= 4000, result.count < 5000 else { throw ModuleError.invalid("Caption text exceeds the limit.") }
            result.append(CaptionCue(start: start, end: end, text: content))
        }
        guard !result.isEmpty else { throw ModuleError.invalid("No caption cues were found.") }; return result
    }
    private static func time(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let values = parts.compactMap { Double($0) }
        guard values.count == parts.count, values.allSatisfy({ $0.isFinite && $0 >= 0 }), let seconds = values.last, seconds < 60, values[values.count - 2] < 60 else { return nil }
        return values.reversed().enumerated().reduce(0) { $0 + $1.element * pow(60, Double($1.offset)) }
    }
    public static func remap(_ cues: [CaptionCue], through recipe: EditRecipe) -> [CaptionCue] {
        var offset = 0.0, output: [CaptionCue] = []
        for range in recipe.ranges {
            for cue in cues {
                let start = max(cue.start, range.start), end = min(cue.end, range.end)
                if end > start { output.append(CaptionCue(start: offset + start - range.start, end: offset + end - range.start, text: cue.text)) }
            }
            offset += range.end - range.start
        }
        return output
    }
    private static func timestamp(_ seconds: Double) -> String {
        let ms = Int((seconds * 1000).rounded()); return String(format: "%02d:%02d:%02d.%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
    }
    public static func webVTT(_ cues: [CaptionCue]) -> Data {
        let content = cues.map { cue in
            let escaped = cue.text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            return "\(timestamp(cue.start)) --> \(timestamp(cue.end))\n\(escaped)"
        }.joined(separator: "\n\n")
        return Data(("WEBVTT\n\n" + content + "\n").utf8)
    }
}
public struct SubtitleImportProcessor: ArtifactProcessor {
    public let descriptor = ModuleDescriptor(id: "org.eidos.processor.captions", name: "SRT & WebVTT captions", capabilities: [.processing])
    public init() {}
    public func process(_ source: URL, request: JobRequest, to destination: URL) async throws -> ArtifactReference {
        try Task.checkCancellation()
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 1_000_000 else { throw ModuleError.invalid("Use a regular caption file under 1 MB.") }
        let data = try Data(contentsOf: source)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard request.adapterID == descriptor.id, request.adapterVersion == descriptor.version, request.deadline > Date(), request.input.sha256 == digest else { throw ModuleError.invalid("Caption input changed.") }
        let output = Captions.webVTT(try Captions.parse(data))
        try Task.checkCancellation(); try output.write(to: destination, options: .withoutOverwriting)
        return ArtifactReference(id: request.input.id, sha256: SHA256.hash(data: output).map { String(format: "%02x", $0) }.joined(), revision: request.input.revision)
    }
}
