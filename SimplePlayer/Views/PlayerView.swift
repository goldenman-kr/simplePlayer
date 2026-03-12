import SwiftUI
import AVKit
import UniformTypeIdentifiers
import AppKit

struct PlayerView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @State private var isTargeted: Bool = false
    @State private var isFullscreen: Bool = false
    @State private var showControls: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem?

    private let dropTypes: [UTType] = [
        .fileURL,
        .movie,
        .audio
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    if viewModel.currentItem != nil {
                        MacVideoPlayerView(player: viewModel.player)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    } else {
                        Text("Drop a media file here (mp4, mov, mp3, m4a)")
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }

                    InteractiveVideoOverlay(
                        isFullscreen: isFullscreen,
                        onMouseActivity: {
                            handleUserInteraction()
                        },
                        onToggleFullScreen: {
                            toggleFullScreen()
                        },
                        onOpenURL: { url in
                            DispatchQueue.main.async {
                                viewModel.loadFromDrop(url: url)
                            }
                        },
                        onScrollUp: {
                            viewModel.volumeUp(step: 0.05)
                        },
                        onScrollDown: {
                            viewModel.volumeDown(step: 0.05)
                        }
                    )
                    .allowsHitTesting(true)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
                        .padding(8)
                )
                .background(
                    WindowFullscreenObserver(isFullscreen: $isFullscreen)
                )

                if !isFullscreen {
                    ControlsView(viewModel: viewModel, isFullscreen: isFullscreen)
                        .padding()
                        .background(Material.regular)
                }
            }

            if isFullscreen && showControls {
                VStack {
                    Spacer()
                    ControlsView(viewModel: viewModel, isFullscreen: isFullscreen)
                        .padding()
                        .background(Material.regular)
                        .onHover { _ in
                            handleUserInteraction()
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            KeyCaptureView { event in
                switch event.keyCode {
                case 49: // Space
                    viewModel.togglePlayPause()
                case 123: // Left arrow
                    viewModel.seekBackward()
                case 124: // Right arrow
                    viewModel.seekForward()
                case 126: // Up arrow
                    viewModel.volumeUp()
                case 125: // Down arrow
                    viewModel.volumeDown()
                case 53: // Escape
                    if isFullscreen {
                        toggleFullScreen()
                    }
                case 18: // 1 key
                    if event.modifierFlags.contains(.command) {
                        viewModel.scaleWindow(to: 0.5)
                    }
                case 19: // 2 key
                    if event.modifierFlags.contains(.command) {
                        viewModel.scaleWindow(to: 1.0)
                    }
                case 20: // 3 key
                    if event.modifierFlags.contains(.command) {
                        viewModel.scaleWindow(to: 2.0)
                    }
                default:
                    break
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: isFullscreen) { newValue in
            hideControlsWorkItem?.cancel()
            if newValue {
                showControls = false
            } else {
                showControls = true
            }
        }
    }

    private func handleUserInteraction() {
        guard isFullscreen else {
            showControls = true
            return
        }

        withAnimation {
            showControls = true
        }

        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            withAnimation {
                showControls = false
            }
        }

        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func toggleFullScreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}

