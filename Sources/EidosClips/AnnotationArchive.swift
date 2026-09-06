import Foundation
import ClipsModules

/// Coalesces sidecar checkpoints. Optional drawing persistence never writes from the UI or capture callback.
final class AnnotationArchive {
    struct TimedInk: Codable { let elapsed: Double; let operation: InkOperation }
    private struct Pending { let package: URL; let snapshot: AnnotationSnapshot; let events: [TimedInk] }
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "org.eidos.clips.annotation-archive", qos: .utility)
    private var pending: Pending?
    private var scheduled = false
    var failed: (() -> Void)?
    func submit(package: URL, snapshot: AnnotationSnapshot, events: [TimedInk]) {
        lock.lock(); pending = Pending(package: package, snapshot: snapshot, events: events)
        let launch = !scheduled; scheduled = true; lock.unlock()
        if launch { queue.async { self.drain() } }
    }
    func flush() { queue.sync {} }
    private func drain() {
        while true {
            lock.lock(); let next = pending; pending = nil
            if next == nil { scheduled = false }; lock.unlock()
            guard let next else { return }
            do {
                try JSONEncoder().encode(next.snapshot).write(to: next.package.appendingPathComponent("annotations.json"), options: .atomic)
                try JSONEncoder().encode(next.events).write(to: next.package.appendingPathComponent("annotation-timeline.json"), options: .atomic)
            } catch { failed?() }
        }
    }
}
