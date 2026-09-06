import Foundation

public enum ModuleError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
public enum ModuleCapability: String, Codable, CaseIterable, Hashable {
    case drawingInput, preview, editing, processing, destination, diagnostics
}
public struct ModuleDescriptor: Codable, Equatable, Identifiable {
    public let id: String
    public let version: Int
    public let name: String
    public let capabilities: Set<ModuleCapability>
    public init(id: String, version: Int = 1, name: String, capabilities: Set<ModuleCapability>) {
        self.id = id; self.version = version; self.name = name; self.capabilities = capabilities
    }
}
/// Explicit bundled registration. This is not an arbitrary native-code loader or a process sandbox.
@MainActor public final class ExtensionRegistry {
    public private(set) var modules: [ModuleDescriptor] = []
    private var disabled: Set<String> = []
    public init() {}
    public func register(_ module: ModuleDescriptor) throws {
        guard module.version > 0, !module.id.isEmpty, !modules.contains(where: { $0.id == module.id }) else {
            throw ModuleError.invalid("Invalid or duplicate module.")
        }
        modules.append(module)
    }
    public func setEnabled(_ enabled: Bool, id: String) { if enabled { disabled.remove(id) } else { disabled.insert(id) } }
    public func isEnabled(_ id: String, capability: ModuleCapability) -> Bool {
        !disabled.contains(id) && modules.contains { $0.id == id && $0.capabilities.contains(capability) }
    }
}

public struct ArtifactReference: Codable, Equatable {
    public let id: UUID
    public let sha256: String
    public let revision: Int
    public init(id: UUID, sha256: String, revision: Int) { self.id = id; self.sha256 = sha256; self.revision = revision }
}
public struct JobRequest: Codable, Equatable {
    public let id: UUID
    public let adapterID: String
    public let adapterVersion: Int
    public let input: ArtifactReference
    public let deadline: Date
    public init(adapter: ModuleDescriptor, input: ArtifactReference, timeout: TimeInterval = 3600) {
        id = UUID(); adapterID = adapter.id; adapterVersion = adapter.version; self.input = input
        deadline = Date().addingTimeInterval(timeout)
    }
}
public struct DestinationReceipt: Codable, Equatable {
    public let operationID: UUID
    public let artifact: ArtifactReference
    public let location: URL
    public init(operationID: UUID, artifact: ArtifactReference, location: URL) {
        self.operationID = operationID; self.artifact = artifact; self.location = location
    }
}
public protocol DestinationAdapter {
    var descriptor: ModuleDescriptor { get }
    func deliver(_ source: URL, request: JobRequest, to destination: URL) async throws -> DestinationReceipt
}
public protocol ArtifactProcessor {
    var descriptor: ModuleDescriptor { get }
    func process(_ source: URL, request: JobRequest, to destination: URL) async throws -> ArtifactReference
}
/// A generation gate prevents cancelled or old jobs from replacing the current selection.
@MainActor public final class JobGate {
    public private(set) var current: JobRequest?
    public init() {}
    public func begin(_ request: JobRequest) { current = request }
    public func cancel() { current = nil }
    public func accepts(_ request: JobRequest, input: ArtifactReference, now: Date = Date()) -> Bool {
        current == request && request.input == input && now < request.deadline
    }
    @discardableResult public func finish(_ request: JobRequest, input: ArtifactReference) -> Bool {
        guard accepts(request, input: input) else { return false }; current = nil; return true
    }
}
public struct EditRange: Codable, Equatable {
    public var start: Double
    public var end: Double
    public init(_ start: Double, _ end: Double) { self.start = start; self.end = end }
}
public struct EditRecipe: Codable, Equatable {
    public var schemaVersion = 1
    public var revision: Int
    public var ranges: [EditRange]
    public init(revision: Int = 1, ranges: [EditRange]) { self.revision = revision; self.ranges = ranges }
    public func validate(duration: Double) throws {
        guard schemaVersion == 1, revision > 0, duration.isFinite, duration > 0,
              !ranges.isEmpty, ranges.count <= 100 else { throw ModuleError.invalid("Invalid edit recipe.") }
        var end = 0.0
        for range in ranges {
            guard range.start.isFinite, range.end.isFinite, range.start >= end,
                  range.end > range.start, range.end <= duration + 0.05 else {
                throw ModuleError.invalid("Keep ranges must be ordered, nonoverlapping and inside the recording.")
            }
            end = range.end
        }
    }
}
public protocol EditProvider {
    var descriptor: ModuleDescriptor { get }
    func recipe(duration: Double, selection: EditRange, removeSelection: Bool) throws -> EditRecipe
}
public struct BasicEditProvider: EditProvider {
    public let descriptor = ModuleDescriptor(id: "org.eidos.edit.basic", name: "Trim & cut", capabilities: [.editing])
    public init() {}
    public func recipe(duration: Double, selection: EditRange, removeSelection: Bool) throws -> EditRecipe {
        let selected = EditRecipe(ranges: [selection]); try selected.validate(duration: duration)
        let result = removeSelection ? EditRecipe(ranges: [EditRange(0, selection.start), EditRange(selection.end, duration)].filter { $0.end - $0.start > 0.01 }) : selected
        try result.validate(duration: duration); return result
    }
}
