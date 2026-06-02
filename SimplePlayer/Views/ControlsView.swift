import SwiftUI

struct ControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let isFullscreen: Bool

    private let playbackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private let windowScales: [(label: String, value: CGFloat)] = [
        ("0.5x", 0.5),
        ("1x", 1.0),
        ("2x", 2.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.setProgress($0) }
                ),
                in: 0...1
            )
            .disabled(!viewModel.hasLoadedItem)

            ViewThatFits(in: .horizontal) {
                wideControls
                compactControls
            }

            if let subtitleStatus = viewModel.subtitleStatusMessage {
                Text(subtitleStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Text(viewModel.currentItem?.title ?? "No file loaded")
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Text("\(TimeFormatter.string(from: viewModel.currentTime)) / \(TimeFormatter.string(from: viewModel.duration))")
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var wideControls: some View {
        HStack(spacing: 12) {
            transportControls

            Divider()
                .frame(height: 22)

            volumeControls
                .frame(width: 230)

            Divider()
                .frame(height: 22)

            speedPicker

            Divider()
                .frame(height: 22)

            subtitleMenu

            Divider()
                .frame(height: 22)

            windowScaleControls
        }
    }

    private var compactControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                transportControls
                volumeControls
                    .frame(width: 230)
                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                speedMenu
                subtitleMenu
                windowScaleMenu
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.seek(by: -10)
            }) {
                Image(systemName: "gobackward.10")
                    .frame(width: 18, height: 18)
            }
            .help("Back 10 seconds")
            .disabled(!viewModel.hasLoadedItem)

            Button(action: {
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 18, height: 18)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(viewModel.isPlaying ? "Pause" : "Play")
            .disabled(!viewModel.hasLoadedItem)

            Button(action: {
                viewModel.seek(by: 10)
            }) {
                Image(systemName: "goforward.10")
                    .frame(width: 18, height: 18)
            }
            .help("Forward 10 seconds")
            .disabled(!viewModel.hasLoadedItem)

            Button(action: {
                viewModel.isRepeatOneEnabled.toggle()
            }) {
                Image(systemName: "repeat.1")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRepeatOneEnabled ? .accentColor : .gray.opacity(0.4))
            .help("Repeat current file")
            .disabled(!viewModel.hasLoadedItem)
        }
        .fixedSize()
    }

    private var volumeControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(viewModel.volume) },
                    set: { viewModel.volume = Float($0) }
                ),
                in: 0...1
            )
            .frame(minWidth: 80)

            Toggle("Boost", isOn: $viewModel.isVolumeBoostEnabled)
                .toggleStyle(.checkbox)
                .fixedSize()

            Text("\(viewModel.displayedVolumePercentage)%")
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 44, alignment: .trailing)
        }
        .disabled(!viewModel.hasLoadedItem)
    }

    private var speedPicker: some View {
        HStack(spacing: 8) {
            Text("Speed")
                .frame(width: 46, alignment: .trailing)
                .fixedSize()

            Picker("", selection: $viewModel.playbackRate) {
                ForEach(playbackRates, id: \.self) { rate in
                    Text(String(format: "%.2gx", rate))
                        .tag(rate)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .fixedSize(horizontal: true, vertical: false)
        .disabled(!viewModel.hasLoadedItem)
    }

    private var speedMenu: some View {
        Menu {
            ForEach(playbackRates, id: \.self) { rate in
                Button {
                    viewModel.playbackRate = rate
                } label: {
                    HStack {
                        Text(String(format: "%.2gx", rate))
                        if viewModel.playbackRate == rate {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Speed \(String(format: "%.2gx", viewModel.playbackRate))", systemImage: "speedometer")
                .frame(minWidth: 104, alignment: .leading)
        }
        .help("Playback speed")
        .disabled(!viewModel.hasLoadedItem)
    }

    private var subtitleMenu: some View {
        Menu {
            Button {
                viewModel.presentSubtitleOpenPanel()
            } label: {
                Label("Open Subtitle...", systemImage: "folder")
            }
            .disabled(!viewModel.hasLoadedItem)

            Toggle("Show Subtitles", isOn: $viewModel.subtitlesEnabled)
                .disabled(viewModel.subtitleTrack == nil)

            Divider()

            Button {
                viewModel.adjustSubtitleDelay(by: -0.5)
            } label: {
                Label("-0.5s Delay", systemImage: "minus.circle")
            }
            .disabled(viewModel.subtitleTrack == nil)

            Button {
                viewModel.adjustSubtitleDelay(by: 0.5)
            } label: {
                Label("+0.5s Delay", systemImage: "plus.circle")
            }
            .disabled(viewModel.subtitleTrack == nil)

            Text(String(format: "Delay %.1fs", viewModel.subtitleDelay))

            Divider()

            Slider(value: $viewModel.subtitleFontScale, in: 0.8...1.6) {
                Text("Subtitle Size")
            }
            .disabled(viewModel.subtitleTrack == nil)

            Button(role: .destructive) {
                viewModel.clearSubtitle()
            } label: {
                Label("Clear Subtitle", systemImage: "xmark.circle")
            }
            .disabled(viewModel.subtitleTrack == nil)
        } label: {
            Label(subtitleLabel, systemImage: viewModel.subtitleTrack == nil ? "captions.bubble" : "captions.bubble.fill")
        }
        .help("Subtitles")
    }

    private var subtitleLabel: String {
        if viewModel.subtitleTrack == nil {
            return "Subtitles"
        }
        if viewModel.subtitleDelay == 0 {
            return viewModel.subtitlesEnabled ? "Subtitles" : "Subtitles Off"
        }
        return String(format: "Sub %.1fs", viewModel.subtitleDelay)
    }

    private var windowScaleControls: some View {
        HStack(spacing: 6) {
            ForEach(windowScales, id: \.value) { scale in
                Button(scale.label) {
                    viewModel.scaleWindow(to: scale.value)
                }
            }
        }
        .fixedSize()
        .disabled(!viewModel.hasVideo || isFullscreen)
    }

    private var windowScaleMenu: some View {
        Menu {
            ForEach(windowScales, id: \.value) { scale in
                Button(scale.label) {
                    viewModel.scaleWindow(to: scale.value)
                }
            }
        } label: {
            Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .help("Window scale")
        .disabled(!viewModel.hasVideo || isFullscreen)
    }
}
