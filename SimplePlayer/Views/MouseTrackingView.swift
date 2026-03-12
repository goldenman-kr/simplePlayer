import SwiftUI
import AppKit

struct MouseTrackingView: NSViewRepresentable {
    var onMove: () -> Void

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.onMove = onMove
        DispatchQueue.main.async {
            view.window?.acceptsMouseMovedEvents = true
        }
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.onMove = onMove
        nsView.window?.acceptsMouseMovedEvents = true
    }

    final class NSViewType: NSView {
        var onMove: (() -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .mouseMoved,
                .activeInKeyWindow,
                .inVisibleRect
            ]

            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            onMove?()
        }
    }
}

