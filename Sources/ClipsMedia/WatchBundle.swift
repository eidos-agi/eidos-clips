import Foundation
import ClipsCore
import ClipsModules

public struct LocalWatchDestination: DestinationAdapter {
    public let descriptor = ModuleDescriptor(id: "org.eidos.destination.watch-folder", name: "Portable watch folder", capabilities: [.destination])
    public init() {}
    public func deliver(_ source: URL, request: JobRequest, to destination: URL) async throws -> DestinationReceipt {
        guard request.adapterID == descriptor.id, request.adapterVersion == descriptor.version, request.deadline > Date(),
              try RecordingStore.digest(source) == request.input.sha256 else { throw ModuleError.invalid("Watch artifact changed.") }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ModuleError.invalid("Choose a new watch folder.") }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".watch-\(request.id)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        let movie = temporary.appendingPathComponent("clip.mp4")
        try FileManager.default.copyItem(at: source, to: movie)
        guard try RecordingStore.digest(movie) == request.input.sha256 else { throw ModuleError.invalid("Watch copy failed verification.") }
        let html = """
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; media-src 'self' file:; style-src 'unsafe-inline'">
        <title>A clip from Eidos</title><style>body{margin:0;background:#111214;color:#eee;font:16px system-ui}main{max-width:1100px;margin:8vh auto;padding:24px}h1{font-size:24px;font-weight:600}video{width:100%;max-height:75vh;border-radius:14px;background:#000}p{color:#999;font-size:13px}a{color:#ff6855}</style>
        <main><h1>A little show. A lot less tell.</h1><video controls playsinline preload="metadata" src="clip.mp4"></video><p>Recorded with Eidos Clips. <a href="clip.mp4" download>Download video</a></p></main></html>
        """
        try html.write(to: temporary.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try JSONEncoder().encode(request.input).write(to: temporary.appendingPathComponent("artifact.json"))
        try Task.checkCancellation(); try FileManager.default.moveItem(at: temporary, to: destination)
        return DestinationReceipt(operationID: request.id, artifact: request.input, location: destination)
    }
}
