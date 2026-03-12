import SwiftUI

struct ControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let isFullscreen: Bool

    private let playbackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.currentItem?.title ?? "No file loaded")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(TimeFormatter.string(from: viewModel.currentTime)) / \(TimeFormatter.string(from: viewModel.duration))")
                    .font(.system(size: 12, design: .monospaced))
            }

            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.setProgress($0) }
                ),
                in: 0...1
            )

            HStack(spacing: 16) {
                Button(action: {
                    viewModel.seek(by: -10)
                }) {
                    Image(systemName: "gobackward.10")
                }
                .disabled(!viewModel.hasLoadedItem)

                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(!viewModel.hasLoadedItem)

                Button(action: {
                    viewModel.seek(by: 10)
                }) {
                    Image(systemName: "goforward.10")
                }
                .disabled(!viewModel.hasLoadedItem)

                Button(action: {
                    viewModel.isRepeatOneEnabled.toggle()
                }) {
                    Image(systemName: "repeat.1")
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRepeatOneEnabled ? .accentColor : .gray.opacity(0.4))
                .disabled(!viewModel.hasLoadedItem)

                Divider()
                    .frame(height: 20)

                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.volume) },
                            set: { viewModel.volume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 120)
                    Image(systemName: "speaker.wave.3.fill")
                }

                Divider()
                    .frame(height: 20)

                Picker("Speed", selection: $viewModel.playbackRate) {
                    ForEach(playbackRates, id: \.self) { rate in
                        Text(String(format: "%.2gx", rate))
                            .tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Divider()
                    .frame(height: 20)

                HStack(spacing: 8) {
                    Button("x0.5") {
                        viewModel.scaleWindow(to: 0.5)
                    }
                    .disabled(!viewModel.hasVideo || isFullscreen)

                    Button("x1") {
                        viewModel.scaleWindow(to: 1.0)
                    }
                    .disabled(!viewModel.hasVideo || isFullscreen)

                    Button("x2") {
                        viewModel.scaleWindow(to: 2.0)
                    }
                    .disabled(!viewModel.hasVideo || isFullscreen)
                }
            }
        }
    }
}

