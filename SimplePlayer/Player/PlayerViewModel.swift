import Foundation
import AVFoundation
import SwiftUI
import Combine
import AppKit

final class PlayerViewModel: ObservableObject {
    @Published var currentItem: MediaItem?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.8 {
        didSet {
            engine.volume = volume
        }
    }
    @Published var playbackRate: Float = 1.0 {
        didSet {
            if isPlaying {
                engine.rate = playbackRate
            }
        }
    }

    @Published var videoSize: CGSize = .zero
    @Published var isRepeatOneEnabled: Bool = false

    private let engine: PlayerEngine
    private var endObserver: Any?

    init(engine: PlayerEngine = PlayerEngine()) {
        self.engine = engine
        engine.volume = volume
        engine.rate = playbackRate

        engine.addPeriodicTimeObserver { [weak self] time in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentTime = time
                let newDuration = self.engine.duration
                if newDuration > 0 {
                    self.duration = newDuration
                }
                self.isPlaying = self.engine.isPlaying

                if let item = self.engine.player.currentItem {
                    let size = item.presentationSize
                    if size != .zero && size != self.videoSize {
                        self.videoSize = size
                    }
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let item = self.engine.player.currentItem,
                  notification.object as? AVPlayerItem === item else {
                return
            }

            if self.isRepeatOneEnabled {
                self.seek(to: 0)
                self.play()
            } else {
                self.isPlaying = false
            }
        }
    }

    var hasLoadedItem: Bool {
        currentItem != nil
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func setProgress(_ value: Double) {
        guard duration > 0 else { return }
        let clamped = max(0, min(1, value))
        let newTime = duration * clamped
        seek(to: newTime)
    }

    var player: AVPlayer {
        engine.player
    }

    func load(url: URL) {
        let supportedExtensions = ["mp4", "mov", "mp3", "m4a"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return
        }

        engine.load(url: url)
        currentItem = MediaItem(url: url)
        currentTime = 0
        duration = engine.duration
        isPlaying = false
    }

    func loadFromDrop(url: URL) {
        load(url: url)
        play()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        engine.play()
        engine.rate = playbackRate
        isPlaying = true
    }

    func pause() {
        engine.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let upperBound = duration > 0 ? duration : seconds
        let clamped = max(0, min(upperBound, seconds))
        engine.seek(to: clamped)
        currentTime = clamped
    }

    func seek(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func seekForward() {
        seek(by: 10)
    }

    func seekBackward() {
        seek(by: -10)
    }

    var hasVideo: Bool {
        videoSize != .zero
    }

    func volumeUp(step: Float = 0.1) {
        volume = min(1.0, volume + step)
    }

    func volumeDown(step: Float = 0.1) {
        volume = max(0.0, volume - step)
    }

    func scaleWindow(to factor: CGFloat) {
        guard hasVideo,
              !factor.isNaN,
              factor > 0,
              let window = NSApp.keyWindow,
              let contentView = window.contentView else {
            return
        }

        let video = videoSize
        var targetContentWidth = video.width * factor
        var targetContentHeight = video.height * factor + 120

        if let screen = window.screen {
            let visible = screen.visibleFrame
            let chromeWidth = window.frame.size.width - contentView.frame.size.width
            let chromeHeight = window.frame.size.height - contentView.frame.size.height

            let maxWidth = visible.width - chromeWidth - 40
            let maxHeight = visible.height - chromeHeight - 40

            let widthScale = maxWidth / targetContentWidth
            let heightScale = maxHeight / targetContentHeight
            let scale = min(1.0, widthScale, heightScale)

            targetContentWidth *= scale
            targetContentHeight *= scale
        }

        let chromeWidth = window.frame.size.width - contentView.frame.size.width
        let chromeHeight = window.frame.size.height - contentView.frame.size.height

        let newSize = CGSize(
            width: targetContentWidth + chromeWidth,
            height: targetContentHeight + chromeHeight
        )

        var frame = window.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        frame.size = newSize
        frame.origin = NSPoint(
            x: center.x - newSize.width / 2.0,
            y: center.y - newSize.height / 2.0
        )

        window.setFrame(frame, display: true, animate: true)
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

