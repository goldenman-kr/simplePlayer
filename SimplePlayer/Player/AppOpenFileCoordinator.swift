import Foundation
import Combine

struct OpenFileRequest: Identifiable, Equatable {
    let id: Int
    let url: URL
}

final class AppOpenFileCoordinator: ObservableObject {
    static let shared = AppOpenFileCoordinator()

    @Published var lastRequest: OpenFileRequest?

    private let supportedExtensions: Set<String> = ["mp4", "mov", "mp3", "m4a"]
    private var nextID: Int = 1

    private init() {}

    func handleIncoming(url: URL) {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            print("SimplePlayer: Ignoring unsupported file type: \(url.path)")
            return
        }

        let request = OpenFileRequest(id: nextID, url: url)
        nextID += 1

        print("SimplePlayer: Coordinator publishing file URL: \(url.path) (id: \(request.id))")
        DispatchQueue.main.async {
            self.lastRequest = request
        }
    }
}

