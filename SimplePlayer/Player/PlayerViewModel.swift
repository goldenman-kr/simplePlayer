import Foundation
import AVFoundation
import SwiftUI
import Combine
import AppKit
import IOKit.pwr_mgt
import VLCKit

enum PlaybackBackend {
    case avPlayer
    case vlc
}

final class PlayerViewModel: ObservableObject {
    private let boostMultiplier: Float = 4.0

    @Published var currentItem: MediaItem?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.8 {
        didSet {
            applyVolume()
        }
    }
    @Published var isVolumeBoostEnabled: Bool = false {
        didSet {
            applyVolume()
        }
    }
    @Published var playbackRate: Float = 1.0 {
        didSet {
            guard isPlaying else { return }
            switch playbackBackend {
            case .avPlayer:
                engine.rate = playbackRate
            case .vlc:
                vlcPlayer.rate = playbackRate
            }
        }
    }

    @Published var videoSize: CGSize = .zero
    @Published var isRepeatOneEnabled: Bool = false
    @Published var artworkImage: NSImage?
    @Published var playbackErrorMessage: String?
    @Published var externalPlaybackAppName: String?
    @Published var subtitleTrack: SubtitleTrack?
    @Published var subtitlesEnabled: Bool = true {
        didSet {
            refreshSubtitleText()
        }
    }
    @Published var subtitleDelay: Double = 0 {
        didSet {
            refreshSubtitleText()
        }
    }
    @Published var subtitleFontScale: Double = 1.0
    @Published var currentSubtitleText: String = ""
    @Published var subtitleStatusMessage: String?
    @Published var playbackBackend: PlaybackBackend = .avPlayer

    private let engine: PlayerEngine
    private let vlcPlayer = VLCMediaPlayer()
    private var endObserver: Any?
    private var failedToPlayObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var uiTimer: Timer?
    private var shouldResizeWindowToVideo = false
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var systemSleepAssertionID: IOPMAssertionID = 0

    init(engine: PlayerEngine = PlayerEngine()) {
        self.engine = engine
        applyVolume()
        engine.rate = playbackRate

        engine.addPeriodicTimeObserver { [weak self] time in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.playbackBackend == .avPlayer else { return }
                self.updateAVPlayerState(currentTime: time)

                if let item = self.engine.player.currentItem {
                    let size = item.presentationSize
                    if size != .zero && size != self.videoSize {
                        self.videoSize = size
                        self.resizeWindowToVideoIfNeeded()
                    }
                }
            }
        }

        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePlaybackStateFromActiveBackend()
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
                self.updateSleepPreventionIfNeeded()
            }
        }

        failedToPlayObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let item = self.engine.player.currentItem,
                  notification.object as? AVPlayerItem === item else {
                return
            }

            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self.handlePlaybackFailure(error: error)
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

    var vlcMediaPlayer: VLCMediaPlayer {
        vlcPlayer
    }

    func openFile(url: URL) {
        print("PlayerViewModel: openFile \(url.path)")
        if load(url: url) {
            play()
            print("PlayerViewModel: started playback")
        }
    }

    @discardableResult
    func load(url: URL) -> Bool {
        guard SupportedMedia.isPlayable(url) else {
            playbackErrorMessage = "Unsupported file type: .\(url.pathExtension.lowercased())"
            return false
        }

        let shouldUseVLC = url.pathExtension.lowercased() == "mkv"

        playbackErrorMessage = nil
        subtitleStatusMessage = nil
        currentSubtitleText = ""
        subtitleTrack = nil

        playbackBackend = shouldUseVLC ? .vlc : .avPlayer
        if shouldUseVLC {
            engine.pause()
            engine.player.replaceCurrentItem(with: nil)
            itemStatusObservation?.invalidate()
            loadWithVLC(url: url)
        } else {
            vlcPlayer.stop()
            let item = engine.load(url: url)
            observeStatus(of: item)
        }

        applyVolume()
        currentItem = MediaItem(url: url)
        currentTime = 0
        duration = shouldUseVLC ? 0 : engine.duration
        isPlaying = false
        videoSize = .zero
        releaseSleepAssertions()

        artworkImage = nil
        externalPlaybackAppName = preferredExternalPlaybackApp()?.name
        if currentItem?.mediaType == .audio {
            print("PlayerViewModel: Detected audio file, attempting to extract artwork")
            shouldResizeWindowToVideo = false
            extractArtwork(from: url)
        } else {
            print("PlayerViewModel: Video file, no artwork extraction")
            shouldResizeWindowToVideo = true
            discoverSubtitle(for: url)
        }

        return true
    }

    private func extractArtwork(from url: URL) {
        let asset = AVAsset(url: url)
        let metadata = asset.commonMetadata

        if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }) {
            if let dataValue = artworkItem.dataValue,
               let image = NSImage(data: dataValue) {
                print("PlayerViewModel: Extracted embedded artwork via dataValue")
                DispatchQueue.main.async {
                    self.artworkImage = image
                }
                return
            }

            if let value = artworkItem.value as? Data,
               let image = NSImage(data: value) {
                print("PlayerViewModel: Extracted embedded artwork via value Data")
                DispatchQueue.main.async {
                    self.artworkImage = image
                }
                return
            }
        }

        print("PlayerViewModel: No artwork found in metadata")
    }

    func loadFromDrop(url: URL) {
        if SupportedMedia.isSubtitle(url) {
            loadSubtitle(url: url)
        } else {
            openFile(url: url)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard hasLoadedItem, playbackErrorMessage == nil else { return }
        switch playbackBackend {
        case .avPlayer:
            engine.play()
            engine.rate = playbackRate
        case .vlc:
            vlcPlayer.play()
            vlcPlayer.rate = playbackRate
        }
        isPlaying = true
        updateSleepPreventionIfNeeded()
    }

    func pause() {
        switch playbackBackend {
        case .avPlayer:
            engine.pause()
        case .vlc:
            vlcPlayer.pause()
        }
        isPlaying = false
        updateSleepPreventionIfNeeded()
    }

    func seek(to seconds: Double) {
        let upperBound = duration > 0 ? duration : seconds
        let clamped = max(0, min(upperBound, seconds))
        switch playbackBackend {
        case .avPlayer:
            engine.seek(to: clamped)
        case .vlc:
            vlcPlayer.time = VLCTime(int: Int32(clamped * 1000))
        }
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

    var displayedVolumePercentage: Int {
        Int((effectiveVolumeMultiplier * 100).rounded())
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

    private func resizeWindowToVideoIfNeeded() {
        guard shouldResizeWindowToVideo,
              hasVideo,
              let window = NSApp.keyWindow,
              !window.styleMask.contains(.fullScreen) else {
            return
        }

        shouldResizeWindowToVideo = false
        scaleWindow(to: 1.0)
    }

    private var effectiveVolumeMultiplier: Float {
        isVolumeBoostEnabled ? volume * boostMultiplier : volume
    }

    private func loadWithVLC(url: URL) {
        let media = VLCMedia(url: url)
        vlcPlayer.media = media
    }

    private func updatePlaybackStateFromActiveBackend() {
        switch playbackBackend {
        case .avPlayer:
            updateAVPlayerState(currentTime: engine.currentTime)
        case .vlc:
            updateVLCPlayerState()
        }
    }

    private func updateAVPlayerState(currentTime: Double) {
        self.currentTime = currentTime
        let newDuration = engine.duration
        if newDuration > 0 {
            duration = newDuration
        }
        isPlaying = engine.isPlaying
        updateSleepPreventionIfNeeded()
        refreshSubtitleText()
    }

    private func updateVLCPlayerState() {
        let seconds = Double(vlcPlayer.time.intValue) / 1000.0
        if seconds.isFinite && seconds >= 0 {
            currentTime = seconds
        }

        if let length = vlcPlayer.media?.length.intValue, length > 0 {
            duration = Double(length) / 1000.0
        }

        updateVLCVideoSizeIfNeeded()
        isPlaying = vlcPlayer.isPlaying
        if vlcPlayer.state == .error {
            playbackErrorMessage = "This MKV file could not be played by the VLC backend."
        }
        updateSleepPreventionIfNeeded()
        refreshSubtitleText()
    }

    private func updateVLCVideoSizeIfNeeded() {
        let playerSize = vlcPlayer.videoSize
        if playerSize.width > 0, playerSize.height > 0 {
            setVideoSizeIfNeeded(playerSize)
            return
        }

        guard let tracks = vlcPlayer.media?.tracksInformation as? [[String: Any]] else {
            return
        }

        for track in tracks where track[VLCMediaTracksInformationType] as? String == VLCMediaTracksInformationTypeVideo {
            if let width = numberValue(track[VLCMediaTracksInformationVideoWidth]),
               let height = numberValue(track[VLCMediaTracksInformationVideoHeight]),
               width > 0,
               height > 0 {
                setVideoSizeIfNeeded(CGSize(width: width, height: height))
                return
            }
        }
    }

    private func numberValue(_ value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        return nil
    }

    private func setVideoSizeIfNeeded(_ size: CGSize) {
        guard size != .zero, size != videoSize else { return }
        videoSize = size
        resizeWindowToVideoIfNeeded()
    }

    func presentSubtitleOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = SupportedMedia.subtitleContentTypes
        panel.prompt = "Open"
        panel.message = "Choose an SRT or SMI subtitle file."

        if panel.runModal() == .OK, let url = panel.url {
            loadSubtitle(url: url)
        }
    }

    func openInExternalPlaybackApp() {
        guard let url = currentItem?.url,
              let app = preferredExternalPlaybackApp() else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open([url], withApplicationAt: app.url, configuration: configuration) { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.playbackErrorMessage = "Could not open \(app.name): \(error.localizedDescription)"
                }
            }
        }
    }

    private func preferredExternalPlaybackApp() -> (name: String, url: URL)? {
        let candidates = [
            ("IINA", "/Applications/IINA.app"),
            ("VLC", "/Applications/VLC.app")
        ]

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.1)
            if FileManager.default.fileExists(atPath: url.path) {
                return (candidate.0, url)
            }
        }

        return nil
    }

    func clearSubtitle() {
        subtitleTrack = nil
        currentSubtitleText = ""
        subtitleStatusMessage = nil
    }

    func adjustSubtitleDelay(by delta: Double) {
        subtitleDelay = ((subtitleDelay + delta) * 10).rounded() / 10
    }

    func loadSubtitle(url: URL) {
        guard SupportedMedia.isSubtitle(url) else {
            subtitleStatusMessage = "Unsupported subtitle file: .\(url.pathExtension.lowercased())"
            return
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            subtitleTrack = try SubtitleParser.parse(url: url)
            subtitlesEnabled = true
            subtitleStatusMessage = "Subtitle: \(url.lastPathComponent)"
            refreshSubtitleText()
        } catch {
            subtitleTrack = nil
            currentSubtitleText = ""
            subtitleStatusMessage = "Could not load subtitle: \(error.localizedDescription)"
        }
    }

    private func discoverSubtitle(for videoURL: URL) {
        let baseURL = videoURL.deletingPathExtension()
        for ext in SupportedMedia.subtitleExtensions {
            let candidate = baseURL.appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) {
                loadSubtitle(url: candidate)
                return
            }
        }
    }

    private func refreshSubtitleText() {
        guard subtitlesEnabled,
              let subtitleTrack,
              currentItem?.mediaType == .video else {
            currentSubtitleText = ""
            return
        }

        let subtitleTime = max(0, currentTime + subtitleDelay)
        currentSubtitleText = subtitleTrack.cue(at: subtitleTime)?.text ?? ""
    }

    private func observeStatus(of item: AVPlayerItem) {
        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleStatusChange(item)
            }
        }
    }

    private func handleStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            playbackErrorMessage = nil
        case .failed:
            handlePlaybackFailure(error: item.error)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handlePlaybackFailure(error: Error?) {
        pause()
        let ext = currentItem?.url.pathExtension.lowercased() ?? "file"
        if ext == "mkv" {
            playbackErrorMessage = "This MKV file could not be played by the current AVPlayer backend. The container or one of its codecs may be unsupported."
        } else {
            playbackErrorMessage = "Playback failed for this media file."
        }

        if let error {
            print("SimplePlayer playback failed: \(error.localizedDescription)")
        }
    }

    private func applyVolume() {
        switch playbackBackend {
        case .avPlayer:
            if isVolumeBoostEnabled {
                engine.volume = 1.0
                engine.setAudioMixVolume(effectiveVolumeMultiplier)
            } else {
                engine.setAudioMixVolume(nil)
                engine.volume = volume
            }
        case .vlc:
            vlcPlayer.audio?.volume = Int32(max(0, effectiveVolumeMultiplier * 100))
        }
    }

    private func updateSleepPreventionIfNeeded() {
        guard currentItem?.mediaType == .video, isPlaying else {
            releaseSleepAssertions()
            return
        }

        acquireAssertion(
            id: &displaySleepAssertionID,
            type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            name: "SimplePlayer video playback" as CFString
        )
        acquireAssertion(
            id: &systemSleepAssertionID,
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            name: "SimplePlayer video playback" as CFString
        )
    }

    private func acquireAssertion(id: inout IOPMAssertionID, type: CFString, name: CFString) {
        guard id == 0 else { return }

        let result = IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), name, &id)
        if result != kIOReturnSuccess {
            id = 0
        }
    }

    private func releaseSleepAssertions() {
        releaseAssertion(&displaySleepAssertionID)
        releaseAssertion(&systemSleepAssertionID)
    }

    private func releaseAssertion(_ id: inout IOPMAssertionID) {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }

    deinit {
        releaseSleepAssertions()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failedToPlayObserver {
            NotificationCenter.default.removeObserver(failedToPlayObserver)
        }
        itemStatusObservation?.invalidate()
        uiTimer?.invalidate()
        vlcPlayer.stop()
    }
}
