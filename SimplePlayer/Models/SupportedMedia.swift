import Foundation
import UniformTypeIdentifiers

enum MediaKind {
    case audio
    case video
    case subtitle
}

enum SupportedMedia {
    static let videoExtensions: [String] = ["mp4", "mov", "mkv"]
    static let audioExtensions: [String] = ["mp3", "m4a"]
    static let subtitleExtensions: [String] = ["srt", "smi"]

    static var playableExtensions: [String] {
        videoExtensions + audioExtensions
    }

    static var displayedPlayableExtensions: String {
        playableExtensions.joined(separator: ", ")
    }

    static var playableExtensionSet: Set<String> {
        Set(playableExtensions)
    }

    static var subtitleExtensionSet: Set<String> {
        Set(subtitleExtensions)
    }

    static var openPanelContentTypes: [UTType] {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .mp3]
        for ext in ["m4a", "mkv"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }

    static var subtitleContentTypes: [UTType] {
        subtitleExtensions.compactMap { UTType(filenameExtension: $0) }
    }

    static func kind(for url: URL) -> MediaKind? {
        kind(forExtension: url.pathExtension)
    }

    static func kind(forExtension ext: String) -> MediaKind? {
        let normalized = ext.lowercased()
        if videoExtensions.contains(normalized) {
            return .video
        }
        if audioExtensions.contains(normalized) {
            return .audio
        }
        if subtitleExtensions.contains(normalized) {
            return .subtitle
        }
        return nil
    }

    static func isPlayable(_ url: URL) -> Bool {
        playableExtensionSet.contains(url.pathExtension.lowercased())
    }

    static func isSubtitle(_ url: URL) -> Bool {
        subtitleExtensionSet.contains(url.pathExtension.lowercased())
    }
}
