import Foundation
import AVFoundation

final class PlayerEngine {
    let player: AVPlayer
    private var timeObserverToken: Any?

    init() {
        self.player = AVPlayer()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(by delta: Double) {
        let current = currentTime
        seek(to: current + delta)
    }

    var currentTime: Double {
        let value = player.currentTime().seconds
        return value.isFinite ? value : 0
    }

    var duration: Double {
        guard let item = player.currentItem else {
            return 0
        }
        let seconds = item.duration.seconds
        return seconds.isFinite ? seconds : 0
    }

    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = max(0, min(1, newValue)) }
    }

    var rate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }

    func addPeriodicTimeObserver(
        interval: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600),
        queue: DispatchQueue = .main,
        handler: @escaping (_ currentTime: Double) -> Void
    ) {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: queue) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            let safeSeconds = seconds.isFinite ? seconds : 0
            handler(safeSeconds)

            _ = self.duration
        }
    }
}

