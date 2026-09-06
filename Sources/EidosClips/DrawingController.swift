import AppKit
import Combine
import ClipsModules

final class DrawingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
@MainActor final class DrawingController: ObservableObject {
    @Published var enabled = false
    @Published var tool: InkTool = .pen
    @Published var color: InkColor = .coral
    @Published var whiteboard = false { didSet { canvas?.needsDisplay = true } }
    @Published var status = "Mouse & trackpad"
    let pointer = PointerDrawingAdapter()
    private(set) var scene = AnnotationScene()
    private var panel: DrawingPanel?
    private var canvas: InkCanvas?
    private var laserTimer: Timer?
    var onSnapshot: ((AnnotationSnapshot) -> Void)?
    var onAccepted: ((InkOperation) -> Void)?
    var onExit: (() -> Void)?
    var inputAllowed = true
    init() {
        pointer.onOperation = { [weak self] in self?.accept($0) }
        pointer.activate(epoch: scene.epoch)
        laserTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scene.expireLasers(); self?.canvas?.needsDisplay = true }
        }
    }
    func show(frame: CGRect, interactive: Bool) {
        if panel == nil {
            let panel = DrawingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .floating; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let canvas = InkCanvas(frame: CGRect(origin: .zero, size: frame.size)); canvas.owner = self
            panel.contentView = canvas; self.panel = panel; self.canvas = canvas
        }
        panel?.setFrame(frame, display: true); panel?.ignoresMouseEvents = !interactive
        panel?.orderFrontRegardless(); enabled = interactive
        if interactive { panel?.makeKey(); panel?.makeFirstResponder(canvas) }
        canvas?.needsDisplay = true
    }
    func setInteractive(_ value: Bool) {
        enabled = value; panel?.ignoresMouseEvents = !value
        if value { panel?.makeKey(); panel?.makeFirstResponder(canvas) }
    }
    func usePointer() {
        scene.changeSource(); pointer.activate(epoch: scene.epoch); status = "Mouse & trackpad"
        onSnapshot?(scene.snapshot)
    }
    func useRemote() -> AnnotationSnapshot {
        pointer.deactivate(); scene.changeSource(); setInteractive(false); status = "Paired drawing device"; return scene.snapshot
    }
    func reset() { scene.reset(); pointer.activate(epoch: scene.epoch); canvas?.needsDisplay = true; onSnapshot?(scene.snapshot) }
    func hide() { panel?.orderOut(nil); enabled = false }
    func accept(_ operation: InkOperation) {
        guard inputAllowed else { return }
        do {
            if try scene.apply(operation) {
                canvas?.needsDisplay = true; onAccepted?(operation); onSnapshot?(scene.snapshot)
                // Aggregate at operation boundaries, never log coordinates or stroke payloads.
                if operation.kind != .append { DiagnosticLog.shared.record(.drawingAccepted, [.revision: Double(scene.revision)]) }
            }
        } catch { status = error.localizedDescription; DiagnosticLog.shared.record(.drawingRejected) }
    }
    func undo() { pointer.send(.undo) }
    func clear() { pointer.send(.clear) }
}

@MainActor final class InkCanvas: NSView {
    weak var owner: DrawingController?
    private var stroke: InkStroke?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let owner, let context = NSGraphicsContext.current?.cgContext else { return }
        if owner.whiteboard { NSColor(calibratedWhite: 0.08, alpha: 1).setFill(); bounds.fill() }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        for stroke in owner.scene.strokes {
            guard let first = stroke.points.first else { continue }
            context.saveGState()
            let colors: [InkColor: NSColor] = [.coral: .systemRed, .yellow: .systemYellow, .blue: .systemCyan, .white: .white]
            context.setStrokeColor((colors[stroke.color] ?? .white).cgColor)
            context.setAlpha(stroke.tool == .highlighter ? 0.35 : 1)
            if stroke.tool == .eraser { context.setBlendMode(.clear) }
            context.setLineWidth(max(2, bounds.width * stroke.width * (stroke.tool == .highlighter || stroke.tool == .eraser ? 5 : 1)))
            context.setLineCap(.round); context.setLineJoin(.round)
            context.move(to: CGPoint(x: first.x * bounds.width, y: first.y * bounds.height))
            if stroke.points.count == 1 { context.addLine(to: CGPoint(x: first.x * bounds.width + 0.1, y: first.y * bounds.height)) }
            for point in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: point.x * bounds.width, y: point.y * bounds.height)) }
            context.strokePath(); context.restoreGState()
        }
        context.endTransparencyLayer()
    }
    private func point(_ event: NSEvent) -> CanvasPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CanvasPoint(x: min(1, max(0, p.x / bounds.width)), y: min(1, max(0, p.y / bounds.height)), pressure: event.pressure > 0 ? Double(event.pressure) : 0.5)
    }
    override func mouseDown(with event: NSEvent) {
        guard let owner, owner.enabled else { return }
        let stroke = InkStroke(tool: owner.tool, color: owner.color, points: [point(event)])
        self.stroke = stroke; owner.pointer.send(.begin, stroke: stroke)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let stroke else { return }
        owner?.pointer.send(.append, stroke: InkStroke(id: stroke.id, tool: stroke.tool, color: stroke.color, width: stroke.width, points: [point(event)]))
    }
    override func mouseUp(with event: NSEvent) { if stroke != nil { owner?.pointer.send(.end); stroke = nil } }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { if stroke != nil { owner?.pointer.send(.end); stroke = nil }; owner?.setInteractive(false); owner?.onExit?() }
        else if event.charactersIgnoringModifiers == "z" && event.modifierFlags.contains(.command) { owner?.undo() }
        else { super.keyDown(with: event) }
    }
}
