import XCTest
@testable import ClipsModules

final class ModuleTests: XCTestCase {
    func testPairingAuthenticatesTranscriptAndRejectsReplayOrTampering() throws {
        let host = PairingChannel(isHost: true), device = PairingChannel(isHost: false)
        try host.accept(device.hello); try device.accept(host.hello)
        XCTAssertEqual(host.comparisonCode, device.comparisonCode)
        let sealed = try host.seal(PeerMessage(.canvas, payload: Data("fixture".utf8)))
        XCTAssertEqual(try device.open(sealed).payload, Data("fixture".utf8))
        XCTAssertThrowsError(try device.open(sealed))
        let response = try device.seal(PeerMessage(.approved))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        json["sequence"] = 100
        XCTAssertThrowsError(try host.open(JSONSerialization.data(withJSONObject: json)))
        XCTAssertEqual(try host.open(response).kind, .approved)
        let impostor = PairingChannel(isHost: false); try impostor.accept(host.hello)
        XCTAssertThrowsError(try impostor.open(sealed))
    }
    func testDrawingRejectsStaleTargetAndReorderingAndDeduplicates() throws {
        var scene = AnnotationScene()
        let stroke = InkStroke(tool: .pen, color: .coral, points: [CanvasPoint(x: 0.2, y: 0.8)])
        let begin = InkOperation(epoch: scene.epoch, sequence: 1, kind: .begin, stroke: stroke)
        XCTAssertTrue(try scene.apply(begin)); XCTAssertFalse(try scene.apply(begin))
        XCTAssertThrowsError(try scene.apply(InkOperation(epoch: scene.epoch, sequence: 3, kind: .end)))
        XCTAssertEqual(scene.strokes.count, 1)
        scene.changeSource()
        XCTAssertThrowsError(try scene.apply(begin)); XCTAssertEqual(scene.strokes.count, 1)
        XCTAssertTrue(try scene.apply(InkOperation(epoch: scene.epoch, sequence: 1, kind: .clear)))
        XCTAssertTrue(scene.strokes.isEmpty)
    }
    func testDrawingRejectsUnboundedOrInvalidCoordinates() throws {
        var scene = AnnotationScene()
        let bad = InkStroke(tool: .pen, color: .blue, points: [CanvasPoint(x: .nan, y: 0)])
        XCTAssertThrowsError(try scene.apply(InkOperation(epoch: scene.epoch, sequence: 1, kind: .begin, stroke: bad)))
        XCTAssertEqual(scene.revision, 0)
        XCTAssertThrowsError(try CaptureRegion(x: 0.8, y: 0, width: 0.4, height: 1))
        XCTAssertNoThrow(try CaptureRegion(x: 0.2, y: 0.3, width: 0.4, height: 0.5))
    }
    func testEditCutPreservesTwoRangesAndRejectsRemovingEverything() throws {
        let provider = BasicEditProvider()
        XCTAssertEqual(try provider.recipe(duration: 10, selection: EditRange(3, 5), removeSelection: true).ranges, [EditRange(0, 3), EditRange(5, 10)])
        XCTAssertThrowsError(try provider.recipe(duration: 10, selection: EditRange(0, 10), removeSelection: true))
        XCTAssertThrowsError(try EditRecipe(ranges: [EditRange(3, 6), EditRange(5, 9)]).validate(duration: 10))
    }
    @MainActor func testOptionalModulesOffAndCancelledJobCannotPublish() throws {
        let registry = ExtensionRegistry(), adapter = BasicEditProvider().descriptor
        try registry.register(adapter); XCTAssertThrowsError(try registry.register(adapter))
        registry.setEnabled(false, id: adapter.id); XCTAssertFalse(registry.isEnabled(adapter.id, capability: .editing))
        let input = ArtifactReference(id: UUID(), sha256: "fixture", revision: 1)
        let request = JobRequest(adapter: adapter, input: input), gate = JobGate()
        gate.begin(request); XCTAssertTrue(gate.accepts(request, input: input)); gate.cancel()
        XCTAssertFalse(gate.finish(request, input: input))
        gate.begin(request); XCTAssertFalse(gate.accepts(request, input: ArtifactReference(id: input.id, sha256: "changed", revision: 2)))
        XCTAssertFalse(gate.accepts(request, input: input, now: .distantFuture))
    }
    func testDiagnosticPacketRejectsUnknownFieldsAndContent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Logs")
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let log = DiagnosticLog(root: root); log.record(.captureStarted, [.width: 1920, .height: 1080])
        let url = try log.createReport(sourceCommit: "sensitive/path")
        let data = try Data(contentsOf: url), packet = try DiagnosticPacket.validate(data)
        XCTAssertEqual(packet.sourceCommit, "local"); XCTAssertFalse(packet.hardwareValidated)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["transcript"] = "private"; XCTAssertThrowsError(try DiagnosticPacket.validate(JSONSerialization.data(withJSONObject: json)))
        json.removeValue(forKey: "transcript")
        var rows = try XCTUnwrap(json["records"] as? [[String: Any]])
        rows[0]["metrics"] = ["windowTitle": "private"]; json["records"] = rows
        XCTAssertThrowsError(try DiagnosticPacket.validate(JSONSerialization.data(withJSONObject: json)))
    }
}
