import SwiftUI
import UIKit

@main struct ClipsDrawApp: App {
    @StateObject private var model = TabletModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabletView(model: model).preferredColorScheme(.dark)
                .onChange(of: phase) { _, value in if value != .active { model.link.stop() } }
        }
    }
}
@MainActor final class TabletModel: ObservableObject {
    let link = PeerLink()
    @Published var status = "Open Connect drawing device in Clips on your Mac."
    @Published var code: String?
    @Published var approved = false
    @Published var confirmed = false
    @Published var canvas: RemoteCanvas?
    @Published var preview: UIImage?
    @Published var tool: InkTool = .pen
    @Published var color: InkColor = .coral
    @Published var fingerDrawing = false
    private var sequence = 0
    init() {
        link.changed = { [weak self] in
            guard let self else { return }
            self.status = self.link.status; self.code = self.link.comparisonCode
            self.approved = self.link.approved; self.confirmed = self.link.localApproved
            if !self.approved { self.canvas = nil; self.preview = nil; self.sequence = 0 }
        }
        link.received = { [weak self] message in
            guard let self else { return }
            switch message.kind {
            case .canvas:
                guard let canvas = try? JSONDecoder().decode(RemoteCanvas.self, from: message.payload),
                      canvas.snapshot.schemaVersion == 1, canvas.aspectRatio.isFinite, (0.1...10).contains(canvas.aspectRatio),
                      canvas.snapshot.strokes.count <= 2000 else { self.link.stop(); return }
                if self.canvas?.snapshot.epoch != canvas.snapshot.epoch { self.sequence = 0 }
                self.canvas = canvas
                if !canvas.acceptsInput { self.preview = nil }
            case .preview:
                self.preview = self.canvas?.acceptsInput == true && message.payload.count <= 240_000 ? UIImage(data: message.payload) : nil
                try? self.link.send(.init(.previewAck))
            default: break
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-smoke-drawing") {
            var scene = AnnotationScene()
            let stroke = InkStroke(tool: .pen, color: .coral, points: [CanvasPoint(x: 0.2, y: 0.5), CanvasPoint(x: 0.4, y: 0.2), CanvasPoint(x: 0.75, y: 0.6)])
            try? scene.apply(InkOperation(epoch: scene.epoch, sequence: 1, kind: .begin, stroke: stroke))
            try? scene.apply(InkOperation(epoch: scene.epoch, sequence: 2, kind: .end))
            approved = true; status = "Synthetic drawing fixture"
            canvas = RemoteCanvas(snapshot: scene.snapshot, aspectRatio: 16 / 9, acceptsInput: true)
        }
    }
    func send(_ kind: InkOperation.Kind, stroke: InkStroke? = nil) {
        guard let canvas, canvas.acceptsInput, approved else { return }
        sequence += 1
        let operation = InkOperation(epoch: canvas.snapshot.epoch, sequence: sequence, kind: kind, stroke: stroke)
        do { try link.send(.init(.ink, payload: JSONEncoder().encode(operation))) }
        catch { link.stop() }
    }
}
struct TabletView: View {
    @ObservedObject var model: TabletModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Label("Clips Draw", systemImage: "pencil.tip.crop.circle").font(.title3.bold())
                Spacer()
                if model.approved {
                    Picker("Tool", selection: $model.tool) { ForEach(InkTool.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.frame(width: 150)
                    Picker("Color", selection: $model.color) { ForEach(InkColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.frame(width: 120)
                    Button { model.send(.undo) } label: { Image(systemName: "arrow.uturn.backward") }.accessibilityLabel("Undo stroke")
                    Button { model.send(.clear) } label: { Image(systemName: "trash") }.accessibilityLabel("Clear drawing")
                    Menu {
                        Toggle("Draw with finger", isOn: $model.fingerDrawing)
                        Button("Disconnect") { model.link.stop() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }.padding(22).background(Color(white: 0.10))
            if model.approved {
                GeometryReader { geometry in
                    let ratio = model.canvas?.aspectRatio ?? 16 / 9
                    let width = min(geometry.size.width, geometry.size.height * ratio)
                    PencilSurface(model: model).frame(width: width, height: width / ratio)
                        .background(Color(white: 0.14)).clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.padding(20)
                Text(model.canvas?.acceptsInput == true ? "Draw with Apple Pencil. Your marks appear on the Mac and in the recording." : "Connected. Start or resume recording on your Mac to draw.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 16)
            } else {
                Spacer()
                Image(systemName: "ipad.and.arrow.forward").font(.system(size: 55)).foregroundStyle(.orange).padding()
                Text("Your screen. Your Pencil.").font(.largeTitle.bold())
                Text(model.status).foregroundStyle(.secondary).padding()
                if let code = model.code {
                    Text(code).font(.system(size: 54, weight: .semibold, design: .monospaced)).padding()
                    Text("Check that both screens show this code.")
                    Button("Codes match — connect") { model.link.approve() }.buttonStyle(.borderedProminent).disabled(model.confirmed).padding()
                    Button("Cancel") { model.link.stop() }
                } else {
                    Button("Find my Mac") { model.link.start(host: false) }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                Spacer()
                Text("Nearby connection · No account needed · Recording stays on your Mac").font(.footnote).foregroundStyle(.secondary).padding()
            }
        }.tint(.orange).background(Color(white: 0.055))
    }
}
struct PencilSurface: UIViewRepresentable {
    @ObservedObject var model: TabletModel
    func makeUIView(context: Context) -> PencilView { let view = PencilView(); view.model = model; view.isMultipleTouchEnabled = false; view.backgroundColor = .clear; return view }
    func updateUIView(_ view: PencilView, context: Context) { view.sync(); view.setNeedsDisplay() }
}
@MainActor final class PencilView: UIView {
    weak var model: TabletModel?
    private var stroke: InkStroke?
    private var epoch: UUID?
    private var revision = -1
    private var localStrokes: [InkStroke] = []
    func sync() {
        if epoch != model?.canvas?.snapshot.epoch {
            epoch = model?.canvas?.snapshot.epoch; stroke = nil; localStrokes = model?.canvas?.snapshot.strokes ?? []
        }
        if model?.canvas?.acceptsInput != true { stroke = nil }
        if revision != model?.canvas?.snapshot.revision, stroke == nil {
            revision = model?.canvas?.snapshot.revision ?? -1; localStrokes = model?.canvas?.snapshot.strokes ?? []
        }
    }
    override func draw(_ rect: CGRect) {
        guard let model, let context = UIGraphicsGetCurrentContext() else { return }
        // Preview already contains accepted Mac ink. Don't paint that ink a second time.
        model.preview?.draw(in: bounds)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        let strokes = model.preview == nil ? localStrokes : (stroke.map { [$0] } ?? [])
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            context.saveGState()
            let colors: [InkColor: UIColor] = [.coral: .systemRed, .yellow: .systemYellow, .blue: .systemCyan, .white: .white]
            context.setStrokeColor((colors[stroke.color] ?? .white).cgColor)
            context.setAlpha(stroke.tool == .highlighter ? 0.35 : 1)
            if stroke.tool == .eraser { context.setBlendMode(.clear) }
            context.setLineWidth(max(2, bounds.width * stroke.width * (stroke.tool == .highlighter || stroke.tool == .eraser ? 5 : 1)))
            context.setLineCap(.round); context.setLineJoin(.round)
            context.move(to: CGPoint(x: first.x * bounds.width, y: first.y * bounds.height))
            for point in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: point.x * bounds.width, y: point.y * bounds.height)) }
            context.strokePath(); context.restoreGState()
        }
        context.endTransparencyLayer()
    }
    private func point(_ touch: UITouch) -> CanvasPoint {
        let p = touch.location(in: self)
        return CanvasPoint(x: max(0, min(1, p.x / bounds.width)), y: max(0, min(1, p.y / bounds.height)),
            pressure: touch.maximumPossibleForce > 0 ? max(0, min(1, touch.force / touch.maximumPossibleForce)) : 0.5)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sync()
        guard let model, model.canvas?.acceptsInput == true, let touch = touches.first,
              touch.type == .pencil || model.fingerDrawing else { return }
        let stroke = InkStroke(tool: model.tool, color: model.color, points: [point(touch)])
        self.stroke = stroke; localStrokes.append(stroke); model.send(.begin, stroke: stroke); setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var stroke, let touch = touches.first else { return }
        let points = (event?.coalescedTouches(for: touch) ?? [touch]).map(point)
        for offset in stride(from: 0, to: points.count, by: 64) {
            let batch = Array(points[offset..<min(points.count, offset + 64)])
            model?.send(.append, stroke: InkStroke(id: stroke.id, tool: stroke.tool, color: stroke.color, width: stroke.width, points: batch))
        }
        guard stroke.points.count + points.count <= 100_000, localStrokes.count <= 2000 else { model?.link.stop(); return }
        stroke.points.append(contentsOf: points); self.stroke = stroke
        if let index = localStrokes.indices.last { localStrokes[index] = stroke }; setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { if stroke != nil { model?.send(.end); stroke = nil; setNeedsDisplay() } }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
}
