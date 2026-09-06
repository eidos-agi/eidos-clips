import XCTest
@testable import ClipsCore

final class CoreTests: XCTestCase {
    func testPauseRemovesTimeForEveryInputAndDelayedSamples() throws {
        var clock = SessionClock(origin: 100)
        try clock.pause(at: 102)
        XCTAssertNil(clock.map(103))
        XCTAssertEqual(clock.elapsed(at: 108), 2)
        try clock.resume(at: 105)
        XCTAssertEqual(clock.map(106), 3)
        XCTAssertEqual(clock.map(101.5), 1.5)
        XCTAssertNil(clock.map(104))
        XCTAssertEqual(clock.map(105), 2)
        try clock.pause(at: 110); try clock.resume(at: 112)
        XCTAssertEqual(clock.map(113), 8)
        XCTAssertNil(clock.map(.nan)); XCTAssertNil(clock.map(.infinity)); XCTAssertNil(clock.map(99))
        XCTAssertThrowsError(try clock.resume(at: 114))
        XCTAssertThrowsError(try clock.pause(at: 109))
    }

    func testStateRejectsDuplicateStartAndStop() throws {
        var state = SessionState()
        XCTAssertThrowsError(try state.transition(to: .recording))
        try state.transition(to: .preparing)
        XCTAssertThrowsError(try state.transition(to: .preparing))
        try state.transition(to: .recording); try state.transition(to: .paused)
        try state.transition(to: .finalizing)
        XCTAssertThrowsError(try state.transition(to: .finalizing))
        try state.transition(to: .idle)
    }

    func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testCommittedBytesAreVerifiedAndOriginalSurvivesEdits() throws {
        let store = try RecordingStore(root: temporary(), title: "First")
        let media = store.url.appendingPathComponent("segments/\(UUID().uuidString).mov")
        try Data([1, 2, 3, 4]).write(to: media)
        try store.commit(file: media, kind: .video, start: 0, duration: 2)
        XCTAssertThrowsError(try store.commit(file: media, kind: .video, start: 2, duration: 2))
        try store.finish(.ready); try store.rename("  Kept  ")
        let opened = try RecordingStore(open: store.url)
        XCTAssertEqual(opened.manifest.title, "Kept")
        XCTAssertEqual(try opened.verifiedSegments().count, 1)
        XCTAssertEqual(try Data(contentsOf: media), Data([1, 2, 3, 4]))
        try Data([4, 3, 2, 1]).write(to: media)
        XCTAssertThrowsError(try opened.verifiedSegments())
    }

    func testTraversalAndSymlinksAreRejected() throws {
        let root = try temporary()
        let store = try RecordingStore(root: root, title: "Test")
        for path in ["../outside.mov", "/tmp/outside.mov", "segments/../../outside.mov", "segments/random.mov"] {
            XCTAssertThrowsError(try store.segmentURL(path))
        }
        let outside = root.appendingPathComponent("outside.mov")
        try Data([1]).write(to: outside)
        let linked = store.url.appendingPathComponent("segments/\(UUID().uuidString).mov")
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
        XCTAssertThrowsError(try store.segmentURL("segments/" + linked.lastPathComponent))
        XCTAssertEqual(try Data(contentsOf: outside), Data([1]))
    }

    func testInvalidManifestAndEmptyRecordingCannotClaimSuccess() throws {
        let store = try RecordingStore(root: temporary(), title: "Empty")
        XCTAssertThrowsError(try store.finish(.ready))
        XCTAssertThrowsError(try store.rename("  "))
        let manifest = store.url.appendingPathComponent(RecordingStore.manifestName)
        var data = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: Any]
        data["schemaVersion"] = 999
        try JSONSerialization.data(withJSONObject: data).write(to: manifest)
        XCTAssertThrowsError(try RecordingStore(open: store.url))
        try Data("{broken".utf8).write(to: manifest)
        XCTAssertThrowsError(try RecordingStore(open: store.url))
    }
}
