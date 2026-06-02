import SwiftUI
import AppKit
import VLCKit

struct VLCVideoPlayerView: NSViewRepresentable {
    typealias NSViewType = VLCVideoView

    let player: VLCMediaPlayer

    func makeNSView(context: Context) -> VLCVideoView {
        let videoView = VLCVideoView()
        videoView.backColor = .black
        videoView.fillScreen = false
        player.drawable = videoView
        return videoView
    }

    func updateNSView(_ nsView: VLCVideoView, context: Context) {
        nsView.backColor = .black
        nsView.fillScreen = false
        if player.drawable as AnyObject !== nsView {
            player.drawable = nsView
        }
    }
}
