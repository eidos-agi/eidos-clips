import Foundation
import AVFoundation
import Darwin
import ClipsCore
import ClipsMedia
import ClipsFixtures

@main
struct Probe {
    static func emit(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        FileHandle.standardOutput.write(data + Data([10]))
    }

    static func describe(_ url: URL) throws {
        let asset = AVURLAsset(url: url)
        try emit(["file": url.path, "videoFrames": try MediaExport.decodedSamples(at: url),
                  "audioSamples": asset.tracks(withMediaType: .audio).isEmpty ? 0 : try MediaExport.decodedSamples(at: url, kind: .microphone),
                  "duration": asset.duration.seconds, "hardwareValidated": false])
    }

    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard let command = args.first else { throw ClipsError.invalidState("Use record ROOT SECONDS [pause], recover PACKAGE MP4 [START END], or inspect MP4.") }
            switch command {
            case "record":
                guard args.count >= 3, let seconds = Double(args[2]), seconds > 0, seconds <= 3600 else {
                    throw ClipsError.invalidState("Use record ROOT SECONDS [pause].")
                }
                let recorder = try SegmentedRecorder(root: URL(fileURLWithPath: args[1]), title: "Synthetic fixture", origin: 100)
                try emit(["package": recorder.packageURL.path, "synthetic": true])
                for frame in 0..<Int(seconds * 30) {
                    let time = 100 + Double(frame) / 30
                    if args.contains("pause") && frame == 60 { recorder.pause(at: time) }
                    if args.contains("pause") && frame == 90 { recorder.resume(at: time) }
                    recorder.append(try SyntheticSamples.video(frame: frame, time: time), kind: .video)
                    recorder.append(try SyntheticSamples.audio(frame: frame, time: time, channels: 1, frequency: 440), kind: .microphone)
                    recorder.append(try SyntheticSamples.audio(frame: frame, time: time, channels: 2, frequency: 880), kind: .systemAudio)
                    try await Task.sleep(nanoseconds: 33_333_333)
                }
                let package = try await recorder.finish()
                let store = try RecordingStore(open: package)
                try emit(["status": store.manifest.status.rawValue, "segments": store.manifest.segments.count,
                          "duration": store.manifest.duration, "package": package.path])
            case "recover":
                guard args.count == 3 || args.count == 5 else { throw ClipsError.invalidState("Use recover PACKAGE MP4 [START END].") }
                var trim: ClosedRange<Double>?
                if args.count == 5 {
                    guard let start = Double(args[3]), let end = Double(args[4]), start.isFinite, end.isFinite, start <= end else {
                        throw ClipsError.invalidState("Invalid trim bounds.")
                    }
                    trim = start...end
                }
                let result = try await MediaExport.export(package: URL(fileURLWithPath: args[1]),
                    to: URL(fileURLWithPath: args[2]), trim: trim)
                try describe(result)
            case "inspect":
                guard args.count == 2 else { throw ClipsError.invalidState("Use inspect MP4.") }
                try describe(URL(fileURLWithPath: args[1]))
            default: throw ClipsError.invalidState("Unknown probe command.")
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
