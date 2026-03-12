import Foundation

enum MediaType {
    case audio
    case video
}

struct MediaItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var title: String {
        url.lastPathComponent
    }

    var mediaType: MediaType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov":
            return .video
        case "mp3", "m4a":
            return .audio
        default:
            return .video
        }
    }
}

