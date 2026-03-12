import AppKit

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    weak var playerViewModel: PlayerViewModel?

    func windowWillClose(_ notification: Notification) {
        print("MainWindowDelegate: Main window will close, stopping playback")
        playerViewModel?.pause()
    }
}

final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    weak var mainWindow: NSWindow?
    private var mainWindowDelegate = MainWindowDelegate()

    func register(window: NSWindow, viewModel: PlayerViewModel) {
        if let existing = mainWindow {
            if existing === window {
                print("WindowManager: Main window already registered")
                return
            }

            print("WindowManager: Closing extra window and reusing main window")
            window.close()
            bringMainWindowToFront()
        } else {
            print("WindowManager: Registering main window")
            mainWindow = window
            mainWindowDelegate.playerViewModel = viewModel
            window.delegate = mainWindowDelegate
        }
    }

    func bringMainWindowToFront() {
        guard let window = mainWindow else {
            print("WindowManager: No main window to bring to front")
            return
        }

        DispatchQueue.main.async {
            print("WindowManager: Activating existing window")
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

