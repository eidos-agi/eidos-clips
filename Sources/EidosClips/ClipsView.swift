import SwiftUI
import AVKit
import ClipsCore

enum ClipsStyle {
    static let canvas = Color(red: 0.075, green: 0.078, blue: 0.086)
    static let sidebar = Color(red: 0.055, green: 0.058, blue: 0.065)
    static let surface = Color(red: 0.11, green: 0.115, blue: 0.125)
    static let raised = Color(red: 0.145, green: 0.15, blue: 0.165)
    static let muted = Color(red: 0.61, green: 0.63, blue: 0.67)
    static let accent = Color(red: 1, green: 0.40, blue: 0.33)
    static let line = Color.white.opacity(0.075)
}

struct ClipsView: View {
    @ObservedObject var model: ClipsModel
    var body: some View {
        Group { if model.page == .record { CapturePanel(model: model) } else { studio } }
    }
    private var studio: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 196)
            Rectangle().fill(ClipsStyle.line).frame(width: 1)
            VStack(spacing: 0) {
                header
                Rectangle().fill(ClipsStyle.line).frame(height: 1)
                ScrollView {
                    Group {
                        switch model.page {
                        case .record: recordPage
                        case .library: libraryPage
                        case .review: reviewPage
                        }
                    }.padding(24).frame(maxWidth: .infinity, alignment: .topLeading)
                }
                if model.page == .record {
                    recordActions.padding(.horizontal, 24).padding(.vertical, 20)
                        .background(ClipsStyle.canvas)
                        .overlay(alignment: .top) { Rectangle().fill(ClipsStyle.line).frame(height: 1) }
                }
                if model.page == .review {
                    reviewActions.padding(.horizontal, 24).padding(.vertical, 20)
                        .background(ClipsStyle.canvas)
                        .overlay(alignment: .top) { Rectangle().fill(ClipsStyle.line).frame(height: 1) }
                }
                if let notice = model.notice {
                    HStack(spacing: 10) {
                        if model.busy || model.phase == .finalizing || model.phase == .preparing { ProgressView().controlSize(.small) }
                        else { Image(systemName: "info.circle").foregroundStyle(ClipsStyle.muted) }
                        Text(notice).font(.system(size: 12)).textSelection(.enabled)
                        if model.busy { ProgressView(value: model.jobProgress).frame(width: 70); Button("Cancel") { model.cancelJob() } }
                        if model.lastTrashed != nil { Button("Undo move") { model.restoreLastTrash() } }
                        Spacer(minLength: 10)
                        Button { model.notice = nil } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                            .buttonStyle(.plain).accessibilityLabel("Dismiss message")
                    }.padding(.horizontal, 24).padding(.vertical, 14).background(ClipsStyle.raised)
                }
            }
        }
        .background(ClipsStyle.canvas).foregroundStyle(.white)
        .tint(ClipsStyle.accent).preferredColorScheme(.dark)
        .frame(minWidth: 880, minHeight: 640)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(ClipsStyle.accent).frame(width: 34, height: 34)
                    Image(systemName: "play.rectangle.fill").font(.system(size: 19, weight: .bold)).foregroundStyle(ClipsStyle.sidebar)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clips").font(.system(size: 22, weight: .semibold))
                    Text("BY EIDOS").font(.system(size: 8, weight: .semibold)).tracking(2).foregroundStyle(ClipsStyle.muted)
                }
            }.padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 34)
            navigation("New recording", symbol: "record.circle", page: .record)
            navigation("Your clips", symbol: "square.grid.2x2", page: .library, count: model.clips.count)
            Spacer()
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 0.46, green: 0.72, blue: 0.57)).frame(width: 5, height: 5)
                    Text("Made here. Kept here.").font(.system(size: 11, weight: .medium))
                }
                Text("Your recordings stay on this Mac.").font(.system(size: 11)).foregroundStyle(ClipsStyle.muted).lineSpacing(4)
                Button("Save diagnostic report") { model.diagnosticReport() }.font(.system(size: 11)).buttonStyle(.plain)
                Button { model.showFiles() } label: {
                    Label("Open recordings folder", systemImage: "folder").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(ClipsStyle.muted)
            }.padding(22)
        }.background(ClipsStyle.sidebar)
    }

    private func navigation(_ title: String, symbol: String, page: ClipsPage, count: Int? = nil) -> some View {
        Button { model.navigate(page) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 15))
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                if let count, count > 0 { Text("\(count)").font(.system(size: 10)).foregroundStyle(ClipsStyle.muted) }
            }
            .foregroundStyle(model.page == page ? Color.white : ClipsStyle.muted)
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(model.page == page ? ClipsStyle.raised : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 4).disabled(model.active || model.busy)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(model.page == .record ? "New recording" : model.page == .library ? "Your clips" : "Review clip")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            if model.page == .review {
                Button { model.share() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(QuietButton()).disabled(model.busy)
            }
            Image(systemName: "internaldrive").font(.system(size: 12)).foregroundStyle(ClipsStyle.muted)
            Text("On this Mac").font(.system(size: 11)).foregroundStyle(ClipsStyle.muted)
        }.padding(.horizontal, 24).frame(height: 64)
    }

    private var recordPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.active ? "Make your point." : "A little show. A lot less tell.")
                    .font(.system(size: 28, weight: .semibold)).tracking(-0.8)
                Text(model.active ? "Take your time. You can pause whenever you need." : "Turn what's on your screen into something worth sharing.")
                    .font(.system(size: 13)).foregroundStyle(ClipsStyle.muted)
            }
            recordCanvas
            HStack(spacing: 12) {
                inputCard("Microphone", detail: "Your voice", symbol: "mic", value: $model.microphone)
                inputCard("Camera", detail: "Your face, in a bubble", symbol: "video", value: $model.camera)
                inputCard("System audio", detail: "Sound from your Mac", symbol: "speaker.wave.2", value: $model.systemAudio)
            }

        }
    }

    private var recordActions: some View {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.phase == .paused ? "PAUSED" : model.active ? "RECORDING" : "READY WHEN YOU ARE")
                        .font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(ClipsStyle.muted)
                    Text(model.active ? ClipsModel.time(model.elapsed) : "Your original is always kept.")
                        .font(.system(size: model.active ? 23 : 12, weight: model.active ? .medium : .regular, design: model.active ? .monospaced : .default))
                }
                Spacer()
                if model.phase == .recording || model.phase == .paused {
                    Button { model.pause() } label: { Label(model.phase == .paused ? "Resume" : "Pause", systemImage: model.phase == .paused ? "play.fill" : "pause.fill") }
                        .buttonStyle(QuietButton())
                    Button { model.stop() } label: { Label("Finish recording", systemImage: "stop.fill") }
                        .buttonStyle(PrimaryButton()).keyboardShortcut(".", modifiers: .command)
                } else {
                    Button { model.start() } label: {
                        HStack(spacing: 12) {
                            Circle().fill(.white).frame(width: 8, height: 8)
                            Text(model.phase == .preparing ? "Getting ready…" : model.phase == .finalizing ? "Finishing…" : "Start recording")
                        }
                    }.buttonStyle(PrimaryButton()).disabled(!model.canRecord).keyboardShortcut("r", modifiers: [.command, .shift])
                }
            }.padding(.top, 2)
    }

    private var recordCanvas: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [ClipsStyle.raised, ClipsStyle.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(ClipsStyle.canvas.opacity(0.65)).frame(width: 92, height: 72)
                        Image(systemName: model.phase == .paused ? "pause.rectangle" : "display")
                            .font(.system(size: 38, weight: .ultraLight)).foregroundStyle(model.active ? ClipsStyle.accent : Color.white.opacity(0.75))
                    }
                    Text(model.active ? (model.phase == .paused ? "Take a breath." : "You're rolling.") : "Start with your screen")
                        .font(.system(size: 17, weight: .medium))
                    Text(model.active ? "Use the menu bar to pause or finish." : "The whole display. Just the story you want to tell.")
                        .font(.system(size: 12)).foregroundStyle(ClipsStyle.muted)
                }
                VStack {
                    HStack {
                        Label("FULL DISPLAY", systemImage: "rectangle.on.rectangle")
                            .font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(ClipsStyle.muted)
                        Spacer()
                        if model.active { Circle().fill(ClipsStyle.accent).frame(width: 7, height: 7) }
                    }
                    Spacer()
                }.padding(20)
            }.frame(height: 178)
            HStack(spacing: 10) {
                Image(systemName: "display").foregroundStyle(ClipsStyle.muted)
                if model.displayNames.isEmpty {
                    Button("Choose a display…") { model.chooseDisplay() }.buttonStyle(.plain)
                } else {
                    Picker("Display", selection: $model.displayIndex) {
                        ForEach(model.displayNames.indices, id: \.self) { i in Text(model.displayNames[i]).tag(i) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
                Spacer()
                Text("30 fps · MP4").font(.system(size: 10)).foregroundStyle(ClipsStyle.muted)
                Button { model.chooseDisplay() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).accessibilityLabel("Refresh displays")
            }.font(.system(size: 12)).padding(16).disabled(!model.canRecord)
        }.background(ClipsStyle.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ClipsStyle.line, lineWidth: 1))
    }

    private func inputCard(_ title: String, detail: String, symbol: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(value.wrappedValue ? .white : ClipsStyle.muted)
                Spacer()
                Toggle(title, isOn: value).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(ClipsStyle.muted)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(ClipsStyle.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ClipsStyle.line, lineWidth: 1)).disabled(!model.canRecord)
    }

    private var libraryPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Good things, kept.").font(.system(size: 28, weight: .semibold)).tracking(-0.8)
                    Text("\(model.clips.count) \(model.clips.count == 1 ? "recording" : "recordings") · Yours to come back to")
                        .font(.system(size: 12)).foregroundStyle(ClipsStyle.muted)
                }
                Spacer()
                if !model.clips.isEmpty {
                    HStack { Image(systemName: "magnifyingglass"); TextField("Find a clip", text: $model.search).textFieldStyle(.plain) }
                        .font(.system(size: 12)).padding(10).frame(width: 170).background(ClipsStyle.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if model.clips.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(ClipsStyle.muted)
                    Text("Your first clip starts here.").font(.system(size: 20, weight: .medium))
                    Text("Record a quick thought. Keep a useful explanation.").font(.system(size: 12)).foregroundStyle(ClipsStyle.muted)
                    Button("Make a recording") { model.navigate(.record) }.buttonStyle(PrimaryButton()).padding(.top, 8)
                }.frame(maxWidth: .infinity).frame(height: 390)
            } else if model.filteredClips.isEmpty {
                Text("No clips match “\(model.search)”.").foregroundStyle(ClipsStyle.muted).padding(.top, 50)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 18)], alignment: .leading, spacing: 24) {
                    ForEach(model.filteredClips) { clip in ClipTile(clip: clip, model: model) }
                }.disabled(model.busy)
            }
        }
    }

    private var reviewPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    TextField("Give your clip a name", text: $model.title).textFieldStyle(.plain)
                        .font(.system(size: 25, weight: .semibold)).onSubmit { model.saveTitle() }
                        .accessibilityLabel("Clip title")
                    Text("\(ClipsModel.time(model.duration)) · Original recording kept on your Mac")
                        .font(.system(size: 11)).foregroundStyle(ClipsStyle.muted)
                }
                Button("Save name") { model.saveTitle() }.buttonStyle(QuietButton()).disabled(model.busy)
            }
            ZStack {
                PlayerSurface(player: model.player)
                if !model.captionText.isEmpty { VStack { Spacer(); Text(model.captionText).font(.system(size: 15, weight: .medium)).multilineTextAlignment(.center).padding(8).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 5)).padding(.bottom, 45) }.allowsHitTesting(false) }
                if let poster = model.poster, !model.hasPlayed {
                    Image(nsImage: poster).resizable().scaledToFit().padding(.bottom, 40).allowsHitTesting(false)
                }
            }.frame(height: model.trimming ? 220 : 270).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ClipsStyle.line))
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Trim & cut", systemImage: "scissors").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Toggle("Trim", isOn: $model.trimming).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(model.busy || !model.modulesEnabled)
                }
                if model.trimming && model.duration > 0.1 {
                    Picker("Selection", selection: $model.removeSelection) { Text("Keep selection").tag(false); Text("Remove selection").tag(true) }.pickerStyle(.segmented)
                    HStack(spacing: 22) {
                        VStack(alignment: .leading) {
                            Text("START  \(ClipsModel.trimTime(model.trimStart))").font(.system(size: 10, weight: .medium, design: .monospaced))
                            Slider(value: $model.trimStart, in: 0...max(0.001, model.trimEnd - 0.1)) { editing in if !editing { model.seek(model.trimStart) } }
                                .accessibilityLabel("Trim start")
                        }
                        VStack(alignment: .leading) {
                            Text("END  \(ClipsModel.trimTime(model.trimEnd))").font(.system(size: 10, weight: .medium, design: .monospaced))
                            Slider(value: $model.trimEnd, in: min(model.duration - 0.001, model.trimStart + 0.1)...model.duration) { editing in if !editing { model.seek(model.trimEnd) } }
                                .accessibilityLabel("Trim end")
                        }
                    }.disabled(model.busy)
                    Text("Exporting \(ClipsModel.trimTime(model.removeSelection ? model.duration - (model.trimEnd - model.trimStart) : model.trimEnd - model.trimStart)). Your full recording stays untouched.")
                        .font(.system(size: 11)).foregroundStyle(ClipsStyle.muted)
                } else {
                    Text("Keep the good part. Your original stays exactly as it is.").font(.system(size: 11)).foregroundStyle(ClipsStyle.muted)
                }
            }.padding(18).background(ClipsStyle.surface, in: RoundedRectangle(cornerRadius: 10))

            TextField("Notes for this clip", text: $model.notes, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            HStack { Button("Save notes") { model.saveNotes() }; Button("Save verified copy…") { model.saveCopy() }; Menu("More") { Button("Import captions…") { model.importCaptions() }; Button("Save watch folder…") { model.saveWatchFolder() } } }.buttonStyle(QuietButton()).disabled(model.busy)
        }
    }
    private var reviewActions: some View {
            HStack {
                Button { model.showFiles() } label: { Label("Show in Finder", systemImage: "folder") }.buttonStyle(QuietButton())
                Spacer()
                Button("Record another") { model.navigate(.record) }.buttonStyle(QuietButton()).disabled(model.busy)
                Button { model.export() } label: { Label(model.trimming ? "Export trim" : "Export clip", systemImage: "arrow.down.to.line") }
                    .buttonStyle(PrimaryButton()).disabled(model.busy)
            }
    }

}

struct ClipTile: View {
    let clip: LibraryClip
    @ObservedObject var model: ClipsModel
    @State private var image: NSImage?
    var body: some View {
        Button { model.open(clip) } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10).fill(ClipsStyle.raised)
                    if let image { Image(nsImage: image).resizable().scaledToFill() }
                    else { Image(systemName: "play.rectangle").font(.system(size: 30, weight: .light)).foregroundStyle(ClipsStyle.muted).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    Text(ClipsModel.time(clip.duration)).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 7).padding(.vertical, 4).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4)).padding(10)
                }.frame(height: 145).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                Text(clip.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack {
                    Text(clip.date == .distantPast ? "Details unavailable" : clip.date.formatted(date: .abbreviated, time: .omitted))
                    Spacer()
                    if clip.needsRecovery { Label("Recover", systemImage: "arrow.counterclockwise").foregroundStyle(ClipsStyle.accent) }
                    else { Text("On this Mac") }
                }.font(.system(size: 10)).foregroundStyle(ClipsStyle.muted)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).contextMenu { Button("Move to Recently Deleted") { model.trash(clip) }; Button("Show original") { NSWorkspace.shared.activateFileViewerSelecting([clip.package]) } }.task(id: clip.id) { image = await model.loadThumbnail(clip) }
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white)
            .padding(.horizontal, 20).frame(height: 42)
            .background(ClipsStyle.accent.opacity(!enabled ? 0.3 : configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct QuietButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium)).foregroundStyle(enabled ? Color.white : ClipsStyle.muted)
            .padding(.horizontal, 13).frame(height: 36)
            .background(ClipsStyle.raised.opacity(configuration.isPressed ? 0.5 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// Reference AVPlayerView directly so the native AVKit class is linked in SwiftPM executables.
struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.controlsStyle = .inline; view.player = player
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
