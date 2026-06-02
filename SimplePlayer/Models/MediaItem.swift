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
        switch SupportedMedia.kind(for: url) {
        case .video:
            return .video
        case .audio:
            return .audio
        case .subtitle, .none:
            return .video
        }
    }
}
