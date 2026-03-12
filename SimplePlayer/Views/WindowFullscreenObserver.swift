import SwiftUI
import AppKit

struct WindowFullscreenObserver: NSViewRepresentable {
    @Binding var isFullscreen: Bool

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.isFullscreenBinding = $isFullscreen
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.isFullscreenBinding = $isFullscreen
    }

    final class NSViewType: NSView {
        var isFullscreenBinding: Binding<Bool>?
        private var observersInstalled = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard let window = window, !observersInstalled else { return }
            observersInstalled = true

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidEnterFullScreen(_:)),
                name: NSWindow.didEnterFullScreenNotification,
                object: window
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidExitFullScreen(_:)),
                name: NSWindow.didExitFullScreenNotification,
                object: window
            )

            isFullscreenBinding?.wrappedValue = window.styleMask.contains(.fullScreen)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func windowDidEnterFullScreen(_ notification: Notification) {
            isFullscreenBinding?.wrappedValue = true
        }

        @objc private func windowDidExitFullScreen(_ notification: Notification) {
            isFullscreenBinding?.wrappedValue = false
        }
    }
}

