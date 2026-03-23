import SwiftUI
import AVKit
import UniformTypeIdentifiers
import AppKit

struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var openFileCoordinator: AppOpenFileCoordinator
    @State private var isTargeted: Bool = false
    @State private var isFullscreen: Bool = false
    @State private var showControls: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var isCursorHidden: Bool = false

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

                    if let item = viewModel.currentItem {
                        switch item.mediaType {
                        case .video:
                            MacVideoPlayerView(player: viewModel.player)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .audio:
                            if let artwork = viewModel.artworkImage {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .shadow(radius: 16)
                                    .padding(40)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "music.note.list")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(item.title)
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                }
                                .padding()
                            }
                        }
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
        .onAppear {
            DispatchQueue.main.async {
                if let window = NSApp.keyWindow {
                    WindowManager.shared.register(window: window, viewModel: viewModel)
                }
            }
        }
        .onChange(of: openFileCoordinator.lastRequest) { request in
            guard let request else { return }
            print("PlayerView: received file URL from coordinator: \(request.url.path) (id: \(request.id))")
            viewModel.openFile(url: request.url)
        }
        .onChange(of: isFullscreen) { newValue in
            hideControlsWorkItem?.cancel()
            if newValue {
                showControls = false
                setCursorHidden(true)
            } else {
                showControls = true
                setCursorHidden(false)
            }
        }
    }

    private func handleUserInteraction() {
        guard isFullscreen else {
            showControls = true
            setCursorHidden(false)
            return
        }

        withAnimation {
            showControls = true
        }
        setCursorHidden(false)

        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            withAnimation {
                showControls = false
            }
            setCursorHidden(true)
        }

        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func toggleFullScreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
    }

    private func setCursorHidden(_ hidden: Bool) {
        guard hidden != isCursorHidden else { return }

        if hidden {
            NSCursor.hide()
        } else {
            NSCursor.unhide()
        }

        isCursorHidden = hidden
    }
}
