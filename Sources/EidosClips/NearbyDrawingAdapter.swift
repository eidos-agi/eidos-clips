import Foundation
import Combine
import ClipsModules

@MainActor final class NearbyDrawingAdapter: ObservableObject, DrawingInputAdapter {
    let descriptor = ModuleDescriptor(id: "org.eidos.drawing.nearby", name: "Nearby tablet", capabilities: [.drawingInput, .preview])
    let link = PeerLink()
    var onOperation: ((InkOperation) -> Void)?
    var onConnection: ((Bool) -> Void)?
    @Published var status = "Connect iPad"
    @Published var comparisonCode: String?
    @Published var approved = false
    @Published var localApproved = false
    @Published var sharingPreview = false
    private var epoch: UUID?
    private var awaitingPreview = false
    init() {
        link.changed = { [weak self] in
            guard let self else { return }
            let previous = self.approved
            self.status = self.link.status; self.comparisonCode = self.link.comparisonCode
            self.approved = self.link.approved; self.localApproved = self.link.localApproved
            if previous != self.approved {
                self.awaitingPreview = false
                if !self.approved { self.sharingPreview = false }
                self.onConnection?(self.approved)
            }
        }
        link.received = { [weak self] message in
            guard let self else { return }
            if message.kind == .previewAck { self.awaitingPreview = false; return }
            guard message.kind == .ink, message.payload.count < 64_000,
                  let operation = try? JSONDecoder().decode(InkOperation.self, from: message.payload), operation.epoch == self.epoch else { return }
            self.onOperation?(operation)
        }
    }
    func activate(epoch: UUID) { self.epoch = epoch }
    func deactivate() { epoch = nil; sharingPreview = false; link.stop() }
    func connect() { sharingPreview = false; link.start(host: true) }
    func synchronize(_ canvas: RemoteCanvas) {
        activate(epoch: canvas.snapshot.epoch)
        guard approved, let data = try? JSONEncoder().encode(canvas), data.count <= 250_000 else { return }
        try? link.send(.init(.canvas, payload: data))
    }
    func sendPreview(_ data: Data) {
        guard approved, sharingPreview, !awaitingPreview, data.count <= 240_000 else { return }
        do { try link.send(.init(.preview, payload: data)); awaitingPreview = true }
        catch { deactivate() }
    }
}
