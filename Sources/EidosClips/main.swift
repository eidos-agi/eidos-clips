import AppKit
import SwiftUI
import AVKit
import ClipsCore
import ClipsModules
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ClipsModel()
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var hud: NSPanel!
    var lastPhase: CaptureState = .idle
    let shortcuts = GlobalShortcuts()
    var drawingObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Eidos Clips"; window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.075, green: 0.078, blue: 0.086, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentMinSize = NSSize(width: 420, height: 440)
        window.contentView = NSHostingView(rootView: ClipsView(model: model))
        window.center()
        hud = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 390, height: 102), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hud.isReleasedWhenClosed = false; hud.isOpaque = false; hud.backgroundColor = .clear
        hud.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        hud.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; hud.isMovableByWindowBackground = true
        hud.contentView = NSHostingView(rootView: RecordingHUD(model: model, drawing: model.drawing))
        hud.center(); hud.setContentSize(NSSize(width: 390, height: 60))
        drawingObservation = model.drawing.$enabled.sink { [weak self] enabled in self?.hud.setContentSize(NSSize(width: 390, height: enabled ? 102 : 60)) }
        model.configureWindow = { [weak self] in self?.resizeWindow() }
        model.showWindow = { [weak self] in self?.showWindow() }
        model.stateChanged = { [weak self] in self?.updateStatus() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Clips", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Pause / Resume", action: #selector(pauseRecording), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Finish recording", action: #selector(stopRecording), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clips", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        let main = NSMenu(); let app = NSMenuItem(); main.addItem(app); app.submenu = menu.copy() as? NSMenu
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); main.addItem(edit)
        let editing = NSMenu(title: "Edit"); edit.submenu = editing
        editing.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editing.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editing.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editing.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
        shortcuts.action = { [weak self] id in
            guard let self else { return }
            if id == 2 { self.model.stop() }
            else if self.model.countdown > 0 || self.model.phase == .preparing { self.model.cancelPreparation() }
            else if self.model.active { self.model.pause() }
            else { self.model.start() }
        }
        shortcuts.install()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in if self?.model.active == true { _ = try? await self?.model.capture.stop(interrupted: true) } }
        }
        if !shortcuts.registered { model.notice = "Global shortcuts are unavailable. Use the recording strip or menu bar." }
        updateStatus(); showWindow()
        if CommandLine.arguments.contains("--ui-smoke") { Task { await runUISmoke() } }
    }
    @objc func showWindow() { resizeWindow(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func pauseRecording() { model.pause() }
    @objc func stopRecording() { model.stop() }
    func resizeWindow() {
        let compact = model.page == .record
        window.contentMinSize = compact ? NSSize(width: 420, height: 440) : NSSize(width: 880, height: 640)
        window.setContentSize(compact ? NSSize(width: 420, height: 440) : NSSize(width: 1040, height: 780))
    }
    func updateStatus() {
        if model.phase != lastPhase {
            if model.phase == .recording && lastPhase == .preparing { window.orderOut(nil); hud.orderFrontRegardless() }
            if model.phase == .idle { hud.orderOut(nil); if model.page == .record { showWindow() } }
            lastPhase = model.phase
        }
        statusItem.button?.title = model.phase == .recording ? "● Clips" : model.phase == .paused ? "Ⅱ Clips" : "Clips"
    }
    func applicationWillTerminate(_ notification: Notification) { shortcuts.uninstall(); model.annotationArchive.flush(); DiagnosticLog.shared.flush() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.busy { model.notice = "Wait for this export to finish, then quit."; return .terminateCancel }
        guard model.capture.state.value != .idle else { return .terminateNow }
        if model.capture.state.value == .preparing { model.notice = "Wait for capture setup to finish, then quit."; return .terminateCancel }
        Task { _ = try? await model.capture.stop(interrupted: true); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }

    // Renders the real native window using synthetic library media, without touching capture devices.
    func runUISmoke() async {
        do {
            guard CommandLine.arguments.count == 5 else { throw ClipsError.invalidState("UI smoke requires output, package and movie paths.") }
            let output = URL(fileURLWithPath: CommandLine.arguments[2])
            let package = URL(fileURLWithPath: CommandLine.arguments[3])
            let movie = URL(fileURLWithPath: CommandLine.arguments[4])
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try await Task.sleep(nanoseconds: 700_000_000)
            guard model.canRecord, model.phase == .idle, window.isVisible else { throw ClipsError.invalidState("App did not launch idle.") }
            try render(output.appendingPathComponent("ui-record.png"))
            guard let clip = model.readClip(package) else { throw ClipsError.invalidPackage("UI fixture was unreadable.") }
            model.clips = [clip]; model.page = .library; resizeWindow()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try render(output.appendingPathComponent("ui-library.png"))
            model.openReview(package: package, export: movie)
            model.trimming = true; model.trimStart = 0.2; model.trimEnd = max(0.3, model.duration - 0.2)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try render(output.appendingPathComponent("ui-review.png"))
            model.page = .record; resizeWindow()
            try await Task.sleep(nanoseconds: 500_000_000)
            try render(output.appendingPathComponent("ui-compact.png"))
            model.phase = .recording; hud.orderFrontRegardless()
            try await Task.sleep(nanoseconds: 500_000_000)
            try render(output.appendingPathComponent("ui-hud.png"), view: hud.contentView)
            model.phase = .idle; hud.orderOut(nil)
            model.drawing.inputAllowed = true
            model.drawing.show(frame: CGRect(x: 40, y: 40, width: 640, height: 360), interactive: false)
            model.drawing.whiteboard = true
            model.drawing.pointer.send(.begin, stroke: InkStroke(tool: .pen, color: .coral, points: [CanvasPoint(x: 0.2, y: 0.5), CanvasPoint(x: 0.4, y: 0.2), CanvasPoint(x: 0.7, y: 0.6)]))
            model.drawing.pointer.send(.end)
            guard model.drawing.scene.strokes.count == 1 else { throw ClipsError.invalidState("Registered pointer did not reach the annotation scene.") }
            try model.drawing.renderPNG().write(to: output.appendingPathComponent("ui-drawing.png"))
            model.setModulesEnabled(false)
            guard model.canRecord, model.registry.drawingInput(model.drawing.pointer.descriptor.id) == nil else { throw ClipsError.invalidState("Optional module disable path failed.") }
            model.setModulesEnabled(true); model.drawing.hide()
            let evidence: [String: Any] = ["uiLaunched": true, "hardwareValidated": false,
                "screens": ["record", "library", "review", "compact", "hud"], "globalShortcutsRegistered": shortcuts.registered, "localDrawingAdapterExercised": true, "optionalModulesOff": true,
                "sourceCommit": ProcessInfo.processInfo.environment["GITHUB_SHA"] ?? "local"]
            let data = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.appendingPathComponent("ui-smoke.json"))
            print(String(decoding: data, as: UTF8.self)); NSApp.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1)
        }
    }
    func render(_ destination: URL, view supplied: NSView? = nil) throws {
        guard let view = supplied ?? window.contentView else { throw ClipsError.invalidState("No native content view.") }
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ClipsError.invalidState("No window bitmap.") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]), png.count > 2_000 else {
            throw ClipsError.invalidState("The native window rendering was empty.")
        }
        try png.write(to: destination)
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { application.run() }
}
