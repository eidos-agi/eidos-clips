import Foundation

public struct CanvasPoint: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let pressure: Double
    public init(x: Double, y: Double, pressure: Double = 0.5) { self.x = x; self.y = y; self.pressure = pressure }
    public var isValid: Bool { x.isFinite && y.isFinite && pressure.isFinite && (0...1).contains(x) && (0...1).contains(y) && (0...1).contains(pressure) }
}
public enum InkTool: String, Codable, CaseIterable { case pen, highlighter, laser, eraser }
public enum InkColor: String, Codable, CaseIterable { case coral, yellow, blue, white }
public struct InkStroke: Codable, Equatable, Identifiable {
    public let id: UUID
    public let tool: InkTool
    public let color: InkColor
    public let width: Double
    public var points: [CanvasPoint]
    public init(id: UUID = UUID(), tool: InkTool, color: InkColor, width: Double = 0.004, points: [CanvasPoint]) {
        self.id = id; self.tool = tool; self.color = color; self.width = width; self.points = points
    }
}
public struct InkOperation: Codable, Equatable {
    public enum Kind: String, Codable { case begin, append, end, undo, clear }
    public let epoch: UUID
    public let sequence: Int
    public let kind: Kind
    public let stroke: InkStroke?
    public init(epoch: UUID, sequence: Int, kind: Kind, stroke: InkStroke? = nil) {
        self.epoch = epoch; self.sequence = sequence; self.kind = kind; self.stroke = stroke
    }
}
public struct AnnotationSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let epoch: UUID
    public let revision: Int
    public let strokes: [InkStroke]
}
/// Device-neutral canonical state. Input is bounded, ordered and scoped to a target epoch.
public struct AnnotationScene {
    public private(set) var epoch = UUID()
    public private(set) var revision = 0
    public private(set) var strokes: [InkStroke] = []
    private var lastSequence = 0
    private var activeID: UUID?
    private var pointCount = 0
    public init() {}
    public var snapshot: AnnotationSnapshot { AnnotationSnapshot(schemaVersion: 1, epoch: epoch, revision: revision, strokes: strokes) }
    public mutating func reset() { self = AnnotationScene() }
    public mutating func changeSource() { epoch = UUID(); lastSequence = 0; activeID = nil; revision += 1 }
    @discardableResult public mutating func apply(_ operation: InkOperation) throws -> Bool {
        guard operation.epoch == epoch else { throw ModuleError.invalid("Drawing target has changed.") }
        if operation.sequence <= lastSequence { return false }
        guard operation.sequence == lastSequence + 1 else { throw ModuleError.invalid("Drawing sequence is incomplete. Reconnect to synchronize.") }
        if let stroke = operation.stroke {
            guard stroke.width.isFinite, (0.001...0.05).contains(stroke.width), stroke.points.count <= 256,
                  stroke.points.allSatisfy(\.isValid) else { throw ModuleError.invalid("Invalid drawing points.") }
        }
        switch operation.kind {
        case .begin:
            guard let stroke = operation.stroke, activeID == nil, !stroke.points.isEmpty,
                  !strokes.contains(where: { $0.id == stroke.id }), strokes.count < 2000,
                  pointCount + stroke.points.count <= 100_000 else { throw ModuleError.invalid("Drawing limit reached or stroke is already active.") }
            strokes.append(stroke); activeID = stroke.id; pointCount += stroke.points.count
        case .append:
            guard let stroke = operation.stroke, activeID == stroke.id, let index = strokes.indices.last,
                  !stroke.points.isEmpty, pointCount + stroke.points.count <= 100_000 else { throw ModuleError.invalid("No matching stroke or drawing limit reached.") }
            strokes[index].points.append(contentsOf: stroke.points); pointCount += stroke.points.count
        case .end:
            guard activeID != nil else { throw ModuleError.invalid("No active stroke.") }; activeID = nil
        case .undo:
            if let stroke = strokes.popLast() { pointCount -= stroke.points.count }; activeID = nil
        case .clear:
            strokes.removeAll(); pointCount = 0; activeID = nil
        }
        lastSequence = operation.sequence; revision += 1; return true
    }
    public mutating func expireLasers() {
        strokes.removeAll { $0.tool == .laser && $0.id != activeID }
        pointCount = strokes.reduce(0) { $0 + $1.points.count }
    }
}
@MainActor public protocol DrawingInputAdapter: AnyObject {
    var descriptor: ModuleDescriptor { get }
    var onOperation: ((InkOperation) -> Void)? { get set }
    func activate(epoch: UUID)
    func deactivate()
}
@MainActor public final class PointerDrawingAdapter: DrawingInputAdapter {
    public let descriptor = ModuleDescriptor(id: "org.eidos.drawing.pointer", name: "Mouse & trackpad", capabilities: [.drawingInput])
    public var onOperation: ((InkOperation) -> Void)?
    private var epoch: UUID?
    private var sequence = 0
    public init() {}
    public func activate(epoch: UUID) { self.epoch = epoch; sequence = 0 }
    public func deactivate() { epoch = nil }
    public func send(_ kind: InkOperation.Kind, stroke: InkStroke? = nil) {
        guard let epoch else { return }; sequence += 1
        onOperation?(InkOperation(epoch: epoch, sequence: sequence, kind: kind, stroke: stroke))
    }
}
/// Top-left normalized rectangle, independent of screen scale and global desktop origin.
public struct CaptureRegion: Codable, Equatable {
    public let x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) throws {
        guard [x,y,width,height].allSatisfy(\.isFinite), x >= 0, y >= 0, width > 0, height > 0,
              x + width <= 1.000001, y + height <= 1.000001 else { throw ModuleError.invalid("Select an area inside one display.") }
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}
