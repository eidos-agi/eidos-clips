import Foundation

public enum ClipsError: Error, LocalizedError {
    case invalidState(String), invalidPackage(String), media(String), storage(String)
    public var errorDescription: String? {
        switch self {
        case .invalidState(let text), .invalidPackage(let text), .media(let text), .storage(let text): return text
        }
    }
}

/// Maps capture timestamps on a monotonic host clock, including delayed buffers.
/// Every input uses the same history; pause is independent of video arrival.
public struct SessionClock {
    public let origin: Double
    private var pauses: [ClosedRange<Double>] = []
    private var pauseStart: Double?
    public var isPaused: Bool { pauseStart != nil }

    public init(origin: Double) { self.origin = origin }

    public mutating func pause(at time: Double) throws {
        guard time.isFinite, time >= origin, pauseStart == nil,
              time >= (pauses.last?.upperBound ?? origin) else {
            throw ClipsError.invalidState("Cannot pause at this time.")
        }
        pauseStart = time
    }

    public mutating func resume(at time: Double) throws {
        guard let start = pauseStart, time.isFinite, time >= start else {
            throw ClipsError.invalidState("Cannot resume at this time.")
        }
        pauses.append(start...time)
        pauseStart = nil
    }

    public func map(_ time: Double) -> Double? {
        guard time.isFinite, time >= origin else { return nil }
        if let start = pauseStart, time >= start { return nil }
        var offset = 0.0
        for pause in pauses {
            if time >= pause.lowerBound && time < pause.upperBound { return nil }
            if time >= pause.upperBound { offset += pause.upperBound - pause.lowerBound }
        }
        return time - origin - offset
    }

    public func elapsed(at time: Double) -> Double {
        let effective = pauseStart ?? time
        return max(0, effective - origin - pauses.reduce(0) { $0 + $1.upperBound - $1.lowerBound })
    }
}

public enum CaptureState: String, Hashable {
    case idle, preparing, recording, paused, finalizing
}

public struct SessionState {
    public private(set) var value: CaptureState = .idle
    public init() {}
    public mutating func transition(to next: CaptureState) throws {
        let allowed: [CaptureState: Set<CaptureState>] = [
            .idle: [.preparing], .preparing: [.recording, .idle, .finalizing],
            .recording: [.paused, .finalizing], .paused: [.recording, .finalizing],
            .finalizing: [.idle],
        ]
        guard allowed[value, default: []].contains(next) else {
            throw ClipsError.invalidState("Cannot change \(value.rawValue) to \(next.rawValue).")
        }
        value = next
    }
}
