import Foundation
import CoreFoundation

public enum DiagnosticEvent: String, Codable, CaseIterable {
    case appLaunch, commandAccepted, commandRejected, capturePreparing, captureStarted, capturePaused, captureResumed, captureStopped, captureFailed
    case permissionResult, captureConfiguration, inputSummary, encoderWait, queueOverload, segmentCommitted, exportStarted, exportCompleted, exportFailed
    case moduleEnabled, moduleDisabled, drawingAccepted, drawingRejected, deviceConnected, deviceDisconnected, pairingRejected, reportCreated, eventsDropped
}
public enum DiagnosticMetric: String, Codable, CaseIterable {
    case durationMs, count, width, height, microphone, systemAudio, camera, region, complete, incomplete, queueDepth, waitMs, bytes, revision, success
}
public struct DiagnosticRecord: Codable, Equatable {
    public let event: DiagnosticEvent
    public let sequence: Int
    public let elapsedMs: Int
    public let operationID: UUID?
    public let metrics: [String: Double]
}
public struct DiagnosticPacket: Codable {
    public let schemaVersion: Int
    public let reportID: UUID
    public let runID: UUID
    public let sourceCommit: String
    public let hardwareValidated: Bool
    public let records: [DiagnosticRecord]
    public static func validate(_ data: Data) throws -> DiagnosticPacket {
        guard data.count <= 5_000_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["schemaVersion", "reportID", "runID", "sourceCommit", "hardwareValidated", "records"]),
              let rows = object["records"] as? [[String: Any]], rows.count <= 4096 else {
            throw ModuleError.invalid("Invalid diagnostic report envelope.")
        }
        for row in rows {
            guard Set(row.keys).isSubset(of: ["event", "sequence", "elapsedMs", "operationID", "metrics"]),
                  let metrics = row["metrics"] as? [String: Any],
                  metrics.keys.allSatisfy({ DiagnosticMetric(rawValue: $0) != nil }),
                  metrics.values.allSatisfy({ value in
                      guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
                      return number.doubleValue.isFinite && abs(number.doubleValue) <= 1e15
                  }) else { throw ModuleError.invalid("Diagnostic report contains unapproved fields.") }
        }
        let packet = try JSONDecoder().decode(Self.self, from: data)
        guard packet.schemaVersion == 1, packet.hardwareValidated == false,
              packet.sourceCommit == "local" || (packet.sourceCommit.count == 40 && packet.sourceCommit.allSatisfy({ $0.isHexDigit })),
              packet.records.allSatisfy({ $0.sequence > 0 && $0.elapsedMs >= 0 }) else { throw ModuleError.invalid("Unsupported diagnostic report.") }
        return packet
    }
}

/// Bounded in-memory ingress; disk I/O happens on one utility queue, never a media callback.
/// There is deliberately no free-form message, path, device name, media or network credential API.
public final class DiagnosticLog {
    #if os(macOS)
    public static let shared = DiagnosticLog(root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Eidos Clips/Logs"))
    #else
    public static let shared = DiagnosticLog(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Clips/Logs"))
    #endif
    public let root: URL
    public let runID = UUID()
    private let lock = NSLock()
    private let disk = DispatchQueue(label: "org.eidos.clips.diagnostics", qos: .utility)
    private let origin = ProcessInfo.processInfo.systemUptime
    private var sequence = 0
    private var pending: [DiagnosticRecord] = []
    private var recent: [DiagnosticRecord] = []
    private var dropped = 0
    private var timer: DispatchSourceTimer?
    public init(root: URL) {
        self.root = root
        let timer = DispatchSource.makeTimerSource(queue: disk)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.writePending() }
        self.timer = timer; timer.resume()
    }
    deinit { timer?.cancel() }
    public func record(_ event: DiagnosticEvent, operationID: UUID? = nil, _ metrics: [DiagnosticMetric: Double] = [:]) {
        lock.lock(); defer { lock.unlock() }
        guard pending.count < 2048 else { dropped += 1; return }
        sequence += 1
        let safe = Dictionary(uniqueKeysWithValues: metrics.filter { $0.value.isFinite && abs($0.value) <= 1e15 }.map { ($0.key.rawValue, $0.value) })
        let row = DiagnosticRecord(event: event, sequence: sequence, elapsedMs: Int(max(0, ProcessInfo.processInfo.systemUptime - origin) * 1000), operationID: operationID, metrics: safe)
        pending.append(row); recent.append(row)
        if recent.count > 2048 { recent.removeFirst(recent.count - 2048) }
    }
    public func flush() { disk.sync { writePending() } }
    private func writePending() {
        lock.lock(); let rows = pending; pending.removeAll(keepingCapacity: true); let lost = dropped; dropped = 0; lock.unlock()
        if lost > 0 { record(.eventsDropped, [.count: Double(lost)]) }
        guard !rows.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
                .filter { $0.pathExtension == "jsonl" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            var total = 0
            for file in files.reversed() {
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                total += values.fileSize ?? 0
                if total > 90_000_000 || (values.contentModificationDate ?? .distantPast) < Date().addingTimeInterval(-7 * 86400) { try? FileManager.default.removeItem(at: file) }
            }
            let url = root.appendingPathComponent("\(runID.uuidString).jsonl")
            if ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0) > 10_000_000 { try FileManager.default.removeItem(at: url) }
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
            let file = try FileHandle(forWritingTo: url); defer { try? file.close() }; try file.seekToEnd()
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for row in rows { try file.write(contentsOf: encoder.encode(row)); try file.write(contentsOf: Data([10])) }
            try file.synchronize()
        } catch { /* Logging failure cannot stop capture. Recent records remain available for the outbox. */ }
    }
    public func createReport(sourceCommit: String) throws -> URL {
        flush(); lock.lock(); let records = recent; lock.unlock()
        let sha = sourceCommit.count == 40 && sourceCommit.allSatisfy(\.isHexDigit) ? sourceCommit : "local"
        let packet = DiagnosticPacket(schemaVersion: 1, reportID: UUID(), runID: runID, sourceCommit: sha, hardwareValidated: false, records: records)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(packet); _ = try DiagnosticPacket.validate(data)
        let outbox = root.deletingLastPathComponent().appendingPathComponent("Diagnostic Outbox", isDirectory: true)
        try FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard ((try? FileManager.default.contentsOfDirectory(atPath: outbox.path)) ?? []).filter({ $0.hasSuffix(".json") }).count < 20 else { throw ModuleError.invalid("Diagnostic outbox is full. Archive previously sent reports first.") }
        let result = outbox.appendingPathComponent(packet.reportID.uuidString + ".json")
        try data.write(to: result, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: result.path)
        record(.reportCreated); return result
    }
}
