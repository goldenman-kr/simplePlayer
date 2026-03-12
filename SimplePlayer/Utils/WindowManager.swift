import AppKit

final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    weak var mainWindow: NSWindow?

    func register(window: NSWindow) {
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

