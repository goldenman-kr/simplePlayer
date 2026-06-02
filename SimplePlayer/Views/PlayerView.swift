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
    @State private var fullscreenControlsHeight: CGFloat = 0
    @State private var isFullscreenControlsPinned: Bool = false

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
                            switch viewModel.playbackBackend {
                            case .avPlayer:
                                MacVideoPlayerView(player: viewModel.player)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .vlc:
                                VLCVideoPlayerView(player: viewModel.vlcMediaPlayer)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            SubtitleOverlayView(
                                text: viewModel.currentSubtitleText,
                                fontScale: viewModel.subtitleFontScale,
                                isFullscreen: isFullscreen,
                                controlsHeight: isFullscreen && showControls ? fullscreenControlsHeight : 0
                            )
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
                        Button(action: openFilePicker) {
                            VStack(spacing: 10) {
                                Text("Drop a media file here")
                                    .font(.headline)
                                Text("or click to browse (\(SupportedMedia.displayedPlayableExtensions))")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(24)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    InteractiveVideoOverlay(
                        isFullscreen: isFullscreen,
                        shouldOpenFilePickerOnClick: viewModel.currentItem == nil,
                        onMouseActivity: {
                            handleUserInteraction()
                        },
                        onToggleFullScreen: {
                            toggleFullScreen()
                        },
                        onOpenFilePicker: {
                            openFilePicker()
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

                    if let error = viewModel.playbackErrorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                            Text(error)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                            if let appName = viewModel.externalPlaybackAppName {
                                Button {
                                    viewModel.openInExternalPlaybackApp()
                                } label: {
                                    Label("Open in \(appName)", systemImage: "play.rectangle")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                    }
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
                    ControlsView(
                        viewModel: viewModel,
                        isFullscreen: isFullscreen,
                        onSubtitleSettingsPresentedChange: handleSubtitleSettingsPresentationChange
                    )
                        .padding()
                        .background(Material.regular)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: ControlsHeightPreferenceKey.self, value: proxy.size.height)
                            }
                        )
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
                isFullscreenControlsPinned = false
                showControls = false
                setCursorHidden(true)
            } else {
                isFullscreenControlsPinned = false
                showControls = true
                setCursorHidden(false)
            }
        }
        .onPreferenceChange(ControlsHeightPreferenceKey.self) { height in
            fullscreenControlsHeight = height
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
        guard !isFullscreenControlsPinned else { return }

        let workItem = DispatchWorkItem {
            guard !isFullscreenControlsPinned else { return }
            withAnimation {
                showControls = false
            }
            setCursorHidden(true)
        }

        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func handleSubtitleSettingsPresentationChange(_ isPresented: Bool) {
        guard isFullscreen else { return }

        isFullscreenControlsPinned = isPresented
        hideControlsWorkItem?.cancel()

        if isPresented {
            withAnimation {
                showControls = true
            }
            setCursorHidden(false)
        } else {
            handleUserInteraction()
        }
    }

    private func toggleFullScreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
    }

    private func openFilePicker() {
        openFileCoordinator.presentOpenPanel()
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

private struct ControlsHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
