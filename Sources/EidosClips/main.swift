import AppKit
import AVKit
import UniformTypeIdentifiers
import ClipsCore
import ClipsMedia

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let capture = CaptureController()
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let status = NSTextField(wrappingLabelWithString: "Choose a display, then record. Files stay in Movies → Eidos Clips.")
    let timer = NSTextField(labelWithString: "00:00")
    let screenPicker = NSPopUpButton()
    let mic = NSButton(checkboxWithTitle: "Microphone", target: nil, action: nil)
    let systemAudio = NSButton(checkboxWithTitle: "System audio", target: nil, action: nil)
    let camera = NSButton(checkboxWithTitle: "Camera bubble", target: nil, action: nil)
    let recent = NSPopUpButton()
    let titleField = NSTextField(string: "")
    let startField = NSTextField(string: "0")
    let endField = NSTextField(string: "")
    let player = AVPlayerView()
    var record: NSButton!
    var pause: NSButton!
    var stop: NSButton!
    var refresh: NSButton!
    var recover: NSButton!
    var trim: NSButton!
    var rename: NSButton!
    var share: NSButton!
    var open: NSButton!
    var packages: [URL] = []
    var selectedPackage: URL?
    var selectedExport: URL?
    var editing = false
    var uiTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = NSSize(width: 660, height: 740)
        window.title = "Eidos Clips"; window.isReleasedWhenClosed = false; window.center()
        let heading = NSTextField(labelWithString: "Eidos Clips")
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Record it. Keep it. Put it to work.")
        subtitle.textColor = .secondaryLabelColor
        timer.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        record = button("Record", #selector(start)); pause = button("Pause", #selector(togglePause))
        stop = button("Stop", #selector(stopRecording)); refresh = button("Choose display…", #selector(loadDisplays))
        recover = button("Recover / Open", #selector(openRecent)); trim = button("Export trim…", #selector(exportTrim))
        rename = button("Rename", #selector(renameClip)); share = button("Share…", #selector(shareClip))
        open = button("Show files", #selector(showFiles))
        record.keyEquivalent = "r"; record.keyEquivalentModifierMask = [.command, .shift]
        stop.keyEquivalent = "."; stop.keyEquivalentModifierMask = [.command]
        mic.state = .on; camera.state = .on
        screenPicker.addItem(withTitle: "Display selected after permission")
        titleField.placeholderString = "Recording title"
        startField.placeholderString = "Start seconds"; endField.placeholderString = "End seconds"
        startField.setAccessibilityLabel("Trim start in seconds"); endField.setAccessibilityLabel("Trim end in seconds")
        titleField.setAccessibilityLabel("Recording title"); recent.setAccessibilityLabel("Recent recordings")
        screenPicker.setAccessibilityLabel("Display to record")
        player.controlsStyle = .inline
        let rows: [NSView] = [heading, subtitle,
            row([screenPicker, refresh]), row([mic, systemAudio, camera]), row([timer, record, pause, stop]), status,
            row([NSTextField(labelWithString: "Your clips"), recent, recover]), player,
            row([titleField, rename]), row([NSTextField(labelWithString: "Trim (seconds)"), startField, endField, trim]),
            row([open, share])]
        let stack = NSStackView(views: rows); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            player.heightAnchor.constraint(equalToConstant: 200),
            titleField.widthAnchor.constraint(equalToConstant: 400),
            startField.widthAnchor.constraint(equalToConstant: 70),
            endField.widthAnchor.constraint(equalToConstant: 70),
            recent.widthAnchor.constraint(equalToConstant: 270),
            screenPicker.widthAnchor.constraint(equalToConstant: 320),
            player.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        capture.changed = { [weak self] in self?.updateState() }
        capture.report = { [weak self] text in self?.status.stringValue = text }
        capture.completed = { [weak self] package, export in self?.display(package: package, export: export) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Eidos Clips", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Pause / Resume", action: #selector(togglePause), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Stop recording", action: #selector(stopRecording), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        let main = NSMenu(); let item = NSMenuItem(); main.addItem(item); item.submenu = menu.copy() as? NSMenu
        NSApp.mainMenu = main
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateTimer() }
        }
        loadRecent(); updateState(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func button(_ name: String, _ action: Selector) -> NSButton {
        let value = NSButton(title: name, target: self, action: action); value.bezelStyle = .rounded; return value
    }
    func row(_ views: [NSView]) -> NSStackView {
        let view = NSStackView(views: views); view.orientation = .horizontal; view.spacing = 10; return view
    }
    func updateState() {
        let idle = capture.state.value == .idle && !editing
        record.isEnabled = idle; refresh.isEnabled = idle; recover.isEnabled = idle && !packages.isEmpty
        [mic, systemAudio, camera].forEach { $0.isEnabled = idle }
        screenPicker.isEnabled = idle; recent.isEnabled = idle
        pause.isEnabled = capture.state.value == .recording || capture.state.value == .paused
        stop.isEnabled = pause.isEnabled
        pause.title = capture.state.value == .paused ? "Resume" : "Pause"
        trim.isEnabled = idle && selectedPackage != nil; rename.isEnabled = trim.isEnabled
        share.isEnabled = idle && selectedExport != nil
        statusItem?.button?.title = capture.state.value == .recording ? "● Clips" : capture.state.value == .paused ? "Ⅱ Clips" : "Clips"
    }
    func updateTimer() {
        let seconds = Int(capture.elapsed); timer.stringValue = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func loadDisplays() {
        Task {
            do {
                try await capture.refreshDisplays()
                screenPicker.removeAllItems()
                for display in capture.displays { screenPicker.addItem(withTitle: "Display \(display.displayID) · \(display.width)×\(display.height)") }
                status.stringValue = "Display list updated. The entire selected display will be captured."
            } catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc func start() {
        player.player?.pause()
        Task { await capture.start(displayIndex: screenPicker.indexOfSelectedItem,
            microphone: mic.state == .on, systemAudio: systemAudio.state == .on, camera: camera.state == .on) }
    }
    @objc func togglePause() { capture.togglePause() }
    @objc func stopRecording() { Task { _ = try? await capture.stop(); loadRecent(); updateState() } }
    @objc func showFiles() {
        try? FileManager.default.createDirectory(at: capture.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(capture.root.deletingLastPathComponent())
    }
    func loadRecent() {
        packages = RecordingStore.recordings(in: capture.root)
        recent.removeAllItems()
        for url in packages {
            let store = try? RecordingStore(open: url)
            recent.addItem(withTitle: "\(store?.manifest.title ?? "Unreadable recording") · \(store?.manifest.status.rawValue ?? "error")")
        }
        if packages.isEmpty { recent.addItem(withTitle: "No recordings yet") }
    }
    func display(package: URL, export: URL) {
        selectedPackage = package; selectedExport = export
        player.player = AVPlayer(url: export)
        titleField.stringValue = (try? RecordingStore(open: package).manifest.title) ?? "Clip"
        startField.stringValue = "0"
        endField.stringValue = String(format: "%.2f", AVURLAsset(url: export).duration.seconds)
        loadRecent(); updateState(); showWindow()
    }
    @objc func openRecent() {
        let index = recent.indexOfSelectedItem
        guard packages.indices.contains(index) else { return }
        let package = packages[index]; editing = true; updateState(); status.stringValue = "Checking retained media and preparing playback…"
        Task {
            defer { editing = false; updateState() }
            do { let result = try await MediaExport.export(package: package, to: capture.exportURL(prefix: "Recovered")); display(package: package, export: result) }
            catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc func renameClip() {
        guard let package = selectedPackage else { return }
        do { try RecordingStore(open: package).rename(titleField.stringValue); loadRecent(); status.stringValue = "Title saved." }
        catch { status.stringValue = error.localizedDescription }
    }
    @objc func exportTrim() {
        guard let package = selectedPackage, let start = Double(startField.stringValue), let end = Double(endField.stringValue),
              start.isFinite, end.isFinite, end > start, start >= 0 else { status.stringValue = "Enter valid start and end times in seconds."; return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]; panel.nameFieldStringValue = "Clip-trimmed.mp4"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        editing = true; updateState(); status.stringValue = "Exporting trim. The original take is retained…"
        Task {
            defer { editing = false; updateState() }
            do { let result = try await MediaExport.export(package: package, to: url, trim: start...end)
                selectedExport = result; player.player = AVPlayer(url: result); status.stringValue = "Trim exported and checked."
            } catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc func shareClip() {
        guard let export = selectedExport else { return }
        NSSharingServicePicker(items: [export]).show(relativeTo: share.bounds, of: share, preferredEdge: .minY)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard capture.state.value != .idle else { return .terminateNow }
        if capture.state.value == .preparing { status.stringValue = "Wait for capture setup to finish, then quit."; return .terminateCancel }
        Task { _ = try? await capture.stop(interrupted: true); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
}

// AppKit starts on the process main thread; keep application setup on its actor.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
}
