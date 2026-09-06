import SwiftUI
import ClipsCore
import ClipsModules

struct CapturePanel: View {
    @ObservedObject var model: ClipsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "record.circle.fill").foregroundStyle(ClipsStyle.accent).font(.system(size: 24))
                    Text("Clips").font(.system(size: 23, weight: .semibold))
                }
                Spacer()
                Button { model.navigate(.library) } label: { Image(systemName: "square.grid.2x2").font(.system(size: 16)) }
                    .buttonStyle(.plain).help("Your clips").disabled(model.active)
                Menu {
                    Toggle("Drawing & editing modules", isOn: Binding(get: { model.modulesEnabled }, set: { model.setModulesEnabled($0) }))
                    Button("Save diagnostic report") { model.diagnosticReport() }
                    Button("Open recordings folder") { model.showFiles() }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 16)) }.menuStyle(.borderlessButton).frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(model.active ? "You're recording." : "Show what you mean.")
                    .font(.system(size: 25, weight: .semibold)).tracking(-0.6)
                Text(model.active ? "Pause, draw, or finish from the floating controls." : "A quick recording. A clearer explanation.")
                    .font(.system(size: 12)).foregroundStyle(ClipsStyle.muted)
            }
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Image(systemName: model.region == nil ? "display" : "crop").font(.system(size: 19)).foregroundStyle(ClipsStyle.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.region == nil ? "Full display" : "Selected area").font(.system(size: 12, weight: .medium))
                        if model.displayNames.isEmpty {
                            Button("Choose display") { model.chooseDisplay() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(ClipsStyle.muted)
                        } else {
                            Picker("Display", selection: Binding(get: { model.displayIndex }, set: { model.selectDisplay($0) })) {
                                ForEach(model.displayNames.indices, id: \.self) { Text(model.displayNames[$0]).tag($0) }
                            }.labelsHidden().controlSize(.small).frame(maxWidth: 240)
                        }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button("Select area…") { model.chooseRegion() }
                        Button("Full display") { model.region = nil }
                        Button("Refresh displays") { model.chooseDisplay() }
                    } label: { Image(systemName: "chevron.down") }.menuStyle(.borderlessButton).frame(width: 18)
                }.padding(15)
                Divider().overlay(ClipsStyle.line)
                HStack(spacing: 0) {
                    input("Mic", symbol: "mic", value: $model.microphone)
                    input("Mac audio", symbol: "speaker.wave.2", value: $model.systemAudio)
                    input("Camera", symbol: "video", value: $model.camera)
                }.padding(.vertical, 14)
            }.background(ClipsStyle.surface, in: RoundedRectangle(cornerRadius: 12)).disabled(model.active || model.busy)
            if model.active {
                HStack {
                    Text(ClipsModel.time(model.elapsed)).font(.system(size: 24, weight: .medium, design: .monospaced))
                    Spacer()
                    Button(model.phase == .paused ? "Resume" : "Pause") { model.pause() }.buttonStyle(QuietButton())
                    Button("Finish") { model.stop() }.buttonStyle(PrimaryButton())
                }.disabled(model.phase == .preparing || model.phase == .finalizing)
            } else {
                Button { model.start() } label: {
                    HStack { Spacer(); Image(systemName: "record.circle"); Text("Start recording"); Spacer(); Text("⌘⇧R").opacity(0.65) }
                }.buttonStyle(PrimaryButton()).keyboardShortcut("r", modifiers: [.command, .shift]).disabled(!model.canRecord)
            }
            if let notice = model.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(ClipsStyle.muted).fixedSize(horizontal: false, vertical: true).lineLimit(4)
            } else {
                Text("Saved on this Mac · Clips controls are included in your take")
                    .font(.system(size: 10)).foregroundStyle(ClipsStyle.muted)
            }
        }.padding(26).frame(width: 420).frame(minHeight: 380)
            .background(ClipsStyle.canvas).foregroundStyle(.white).tint(ClipsStyle.accent).preferredColorScheme(.dark)
    }
    private func input(_ name: String, symbol: String, value: Binding<Bool>) -> some View {
        Button { value.wrappedValue.toggle() } label: {
            VStack(spacing: 7) {
                Image(systemName: value.wrappedValue ? symbol + ".fill" : symbol + ".slash").font(.system(size: 18))
                    .foregroundStyle(value.wrappedValue ? Color.white : ClipsStyle.muted)
                Text(name).font(.system(size: 10)).foregroundStyle(ClipsStyle.muted)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).accessibilityLabel(name).accessibilityValue(value.wrappedValue ? "On" : "Off")
    }
}
struct RecordingHUD: View {
    @ObservedObject var model: ClipsModel
    @ObservedObject var drawing: DrawingController
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Circle().fill(model.phase == .paused ? .yellow : ClipsStyle.accent).frame(width: 8, height: 8)
                Text(ClipsModel.time(model.elapsed)).font(.system(size: 16, weight: .medium, design: .monospaced)).frame(width: 65)
                Button { model.toggleDrawing() } label: { Image(systemName: drawing.enabled ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") }
                    .help("Draw on screen · Esc to return to clicking").disabled(!model.modulesEnabled)
                Button { model.pause() } label: { Image(systemName: model.phase == .paused ? "play.fill" : "pause.fill") }
                    .help(model.phase == .paused ? "Resume" : "Pause")
                Button { model.stop() } label: { Label("Finish", systemImage: "stop.fill").font(.system(size: 12, weight: .semibold)) }
                    .padding(.horizontal, 12).padding(.vertical, 9).background(ClipsStyle.accent, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).padding(.horizontal, 18).frame(height: 60)
                .disabled(model.phase == .preparing || model.phase == .finalizing)
            if model.modulesEnabled {
                Divider().overlay(ClipsStyle.line)
                HStack(spacing: 12) {
                    Picker("Tool", selection: $drawing.tool) {
                        ForEach(InkTool.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.labelsHidden().frame(width: 104)
                    Picker("Color", selection: $drawing.color) {
                        ForEach(InkColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.labelsHidden().frame(width: 86)
                    Button { drawing.undo() } label: { Image(systemName: "arrow.uturn.backward") }.help("Undo stroke")
                    Button { drawing.clear() } label: { Image(systemName: "trash") }.help("Clear drawings")
                    Toggle("Board", isOn: $drawing.whiteboard).toggleStyle(.checkbox)
                }.font(.system(size: 10)).buttonStyle(.plain).padding(.horizontal, 12).frame(height: 42)
            }
        }.background(ClipsStyle.surface).foregroundStyle(.white).preferredColorScheme(.dark).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
