import AppKit
import ClipsModules

@MainActor final class RegionPicker {
    private var panels: [DrawingPanel] = []
    private var completion: ((UInt32, CaptureRegion?) -> Void)?
    func begin(_ completion: @escaping (UInt32, CaptureRegion?) -> Void) {
        cancel(); self.completion = completion
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
            let panel = DrawingPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.level = .screenSaver; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.finished = { [weak self] region in self?.finish(id: id, region: region) }
            panel.contentView = view; panels.append(panel); panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(view)
        }
    }
    func cancel() { panels.forEach { $0.close() }; panels.removeAll(); completion = nil }
    private func finish(id: UInt32, region: CaptureRegion?) { let callback = completion; cancel(); callback?(id, region) }
}
@MainActor final class RegionSelectionView: NSView {
    var finished: ((CaptureRegion?) -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.45).setFill(); bounds.fill()
        if !selection.isEmpty {
            NSColor.clear.setFill(); selection.fill(using: .copy)
            NSColor.systemRed.setStroke(); let path = NSBezierPath(rect: selection); path.lineWidth = 2; path.stroke()
        }
        let text = "Drag an area to record · Esc to cancel"
        (text as NSString).draw(at: CGPoint(x: 28, y: 30), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 20, weight: .medium)])
    }
    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }; let p = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(start.x - p.x), height: abs(start.y - p.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        guard selection.width >= 32, selection.height >= 32 else { return }
        finished?(try? CaptureRegion(x: selection.minX / bounds.width, y: selection.minY / bounds.height, width: selection.width / bounds.width, height: selection.height / bounds.height))
    }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { finished?(nil) } else { super.keyDown(with: event) } }
}
