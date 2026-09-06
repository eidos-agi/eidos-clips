import Foundation
import ClipsCore
import ClipsModules

public struct NativeExportAdapter {
    public let descriptor = ModuleDescriptor(id: "org.eidos.export.mp4", name: "MP4 export", capabilities: [.processing])
    public init() {}
    public func run(package: URL, request: JobRequest, to destination: URL, recipe: EditRecipe? = nil,
                    progress: @escaping (Double) -> Void = { _ in }) async throws -> URL {
        guard request.adapterID == descriptor.id, request.adapterVersion == descriptor.version,
              request.deadline > Date(), try RecordingStore.digest(package.appendingPathComponent(RecordingStore.manifestName)) == request.input.sha256 else {
            throw ModuleError.invalid("The recording or export request changed. Start the export again.")
        }
        return try await MediaExport.export(package: package, to: destination, recipe: recipe, progress: progress)
    }
}
public struct LocalFolderDestination: DestinationAdapter {
    public let descriptor = ModuleDescriptor(id: "org.eidos.destination.folder", name: "Save to folder", capabilities: [.destination])
    public init() {}
    public func deliver(_ source: URL, request: JobRequest, to destination: URL) async throws -> DestinationReceipt {
        try Task.checkCancellation()
        guard request.adapterID == descriptor.id, request.adapterVersion == descriptor.version, request.deadline > Date(),
              try RecordingStore.digest(source) == request.input.sha256 else { throw ModuleError.invalid("The shared artifact changed.") }
        let receipt = DestinationReceipt(operationID: request.id, artifact: request.input, location: destination)
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try RecordingStore.digest(destination) == request.input.sha256 else { throw ModuleError.invalid("A different file already exists at that destination.") }
            return receipt
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".delivery-\(request.id).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.copyItem(at: source, to: temporary)
        try Task.checkCancellation()
        guard try RecordingStore.digest(temporary) == request.input.sha256 else { throw ModuleError.invalid("Destination copy failed verification.") }
        try FileManager.default.moveItem(at: temporary, to: destination)
        return receipt
    }
}
