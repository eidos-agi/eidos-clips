import XCTest
import AVFoundation
import ClipsCore
import ClipsMedia
import ClipsFixtures
import ClipsModules

final class MediaTests: XCTestCase {
    func testSyntheticAudioMeterIsFiniteAndVideoIsUnavailable() throws {
        let sample = try SyntheticSamples.audio(frame: 0, time: 100, channels: 2, frequency: 440)
        let level = try XCTUnwrap(AudioMeter.decibels(sample))
        XCTAssertGreaterThan(level, -50); XCTAssertLessThan(level, 0)
        XCTAssertNil(AudioMeter.decibels(try SyntheticSamples.video(frame: 0, time: 100)))
    }
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
        let cancelledDecode = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try MediaExport.decodedSamples(at: full)
        }
        do { _ = try await cancelledDecode.value; XCTFail("Cancelled validation must stop decoding") }
        catch is CancellationError {} catch { XCTFail("Unexpected cancellation result: \(error)") }
        let trim = try await MediaExport.export(package: package, to: root.appendingPathComponent("trim.mp4"), trim: 0.2...0.7)
        XCTAssertEqual(AVURLAsset(url: trim).duration.seconds, 0.5, accuracy: 0.05)
        let cut = try await MediaExport.export(package: package, to: root.appendingPathComponent("cut.mp4"), recipe: EditRecipe(ranges: [EditRange(0, 0.3), EditRange(0.7, 1)]))
        XCTAssertEqual(try MediaExport.decodedSamples(at: cut), 18)
        XCTAssertEqual(AVURLAsset(url: cut).duration.seconds, 0.6, accuracy: 0.05)
        let destination = LocalFolderDestination()
        let reference = ArtifactReference(id: store.manifest.id, sha256: try RecordingStore.digest(cut), revision: 1)
        let request = JobRequest(adapter: destination.descriptor, input: reference)
        let copy = root.appendingPathComponent("copy.mp4")
        let firstReceipt = try await destination.deliver(cut, request: request, to: copy)
        let retryReceipt = try await destination.deliver(cut, request: request, to: copy)
        XCTAssertEqual(firstReceipt, retryReceipt)
        do {
            _ = try await destination.deliver(full, request: request, to: copy)
            XCTFail("Wrong artifact must not be delivered")
        } catch {}
        do {
            _ = try await MediaExport.export(package: package, to: full)
            XCTFail("Existing destination must not be overwritten")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: package.appendingPathComponent(RecordingStore.manifestName)), before)
        XCTAssertEqual(try store.verifiedSegments().count, 2)
    }
}
