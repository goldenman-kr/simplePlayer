import SwiftUI
import AVKit
import AppKit

struct MacVideoPlayerView: NSViewRepresentable {
    typealias NSViewType = AVPlayerView

    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = true
        playerView.videoGravity = .resizeAspect
        playerView.player = player
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
        nsView.controlsStyle = .none
        nsView.videoGravity = .resizeAspect
    }
}

