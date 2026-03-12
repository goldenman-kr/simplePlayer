import SwiftUI
import AppKit

struct KeyCaptureView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.onKeyDown = onKeyDown
        if nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class NSViewType: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}

