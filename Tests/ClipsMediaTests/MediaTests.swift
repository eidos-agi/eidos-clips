import XCTest
import AVFoundation
import ClipsCore
import ClipsMedia
import ClipsFixtures

final class MediaTests: XCTestCase {
    func testRequestedAudioCannotSilentlyDisappear() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = try SegmentedRecorder(root: root, title: "Missing microphone", origin: 100,
                                          requiredTracks: [.video, .microphone])
        writer.append(try SyntheticSamples.video(frame: 0, time: 100), kind: .video)
        do {
            _ = try await writer.finish()
            XCTFail("Missing requested microphone must fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("microphone"))
        }
        let retained = try RecordingStore(open: writer.packageURL)
        XCTAssertEqual(retained.manifest.status, .failed)
        XCTAssertEqual(try retained.verifiedSegments().count, 1)
    }

    func testDecodedExportTrimAndFailedDestinationPreserveSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = try SegmentedRecorder(root: root, title: "Synthetic", origin: 100, segmentSeconds: 0.5)
        for frame in 0..<30 {
            writer.append(try SyntheticSamples.video(frame: frame, time: 100 + Double(frame) / 30), kind: .video)
            try await Task.sleep(nanoseconds: 33_333_333)
        }
        let package = try await writer.finish()
        let store = try RecordingStore(open: package)
        XCTAssertEqual(store.manifest.status, .ready)
        XCTAssertEqual(store.manifest.segments.count, 2)
        let before = try Data(contentsOf: package.appendingPathComponent(RecordingStore.manifestName))
        let full = try await MediaExport.export(package: package, to: root.appendingPathComponent("full.mp4"))
        XCTAssertEqual(try MediaExport.decodedSamples(at: full), 30)
        let trim = try await MediaExport.export(package: package, to: root.appendingPathComponent("trim.mp4"), trim: 0.2...0.7)
        XCTAssertEqual(AVURLAsset(url: trim).duration.seconds, 0.5, accuracy: 0.05)
        do {
            _ = try await MediaExport.export(package: package, to: full)
            XCTFail("Existing destination must not be overwritten")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: package.appendingPathComponent(RecordingStore.manifestName)), before)
        XCTAssertEqual(try store.verifiedSegments().count, 2)
    }
}
