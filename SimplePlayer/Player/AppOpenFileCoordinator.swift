import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

struct OpenFileRequest: Identifiable, Equatable {
    let id: Int
    let url: URL
}

final class AppOpenFileCoordinator: ObservableObject {
    static let shared = AppOpenFileCoordinator()

    @Published var lastRequest: OpenFileRequest?

    let supportedExtensions: Set<String> = SupportedMedia.playableExtensionSet
    let supportedContentTypes: [UTType] = SupportedMedia.openPanelContentTypes
    private var nextID: Int = 1

    private init() {}

    func handleIncoming(url: URL) {
        guard SupportedMedia.isPlayable(url) else {
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

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedContentTypes
        panel.prompt = "Open"
        panel.message = "Choose a media file to play."

        if panel.runModal() == .OK, let url = panel.url {
            handleIncoming(url: url)
        }
    }
}
