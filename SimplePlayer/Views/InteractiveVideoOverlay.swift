import SwiftUI
import AppKit

struct InteractiveVideoOverlay: NSViewRepresentable {
    var isFullscreen: Bool
    var onMouseActivity: () -> Void
    var onToggleFullScreen: () -> Void
    var onOpenURL: (URL) -> Void
    var onScrollUp: () -> Void
    var onScrollDown: () -> Void

    func makeNSView(context: Context) -> NSViewType {
        let view = NSViewType()
        view.isFullscreen = isFullscreen
        view.onMouseActivity = onMouseActivity
        view.onToggleFullScreen = onToggleFullScreen
        view.onOpenURL = onOpenURL
        view.onScrollUp = onScrollUp
        view.onScrollDown = onScrollDown
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.isFullscreen = isFullscreen
        nsView.onMouseActivity = onMouseActivity
        nsView.onToggleFullScreen = onToggleFullScreen
        nsView.onOpenURL = onOpenURL
        nsView.onScrollUp = onScrollUp
        nsView.onScrollDown = onScrollDown
    }

    final class NSViewType: NSView {
        var isFullscreen: Bool = false
        var onMouseActivity: (() -> Void)?
        var onToggleFullScreen: (() -> Void)?
        var onOpenURL: ((URL) -> Void)?
        var onScrollUp: (() -> Void)?
        var onScrollDown: (() -> Void)?

        private var mouseDownEvent: NSEvent?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        private func commonInit() {
            registerForDraggedTypes([.fileURL, .URL])
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            let options: NSTrackingArea.Options = [
                .mouseMoved,
                .activeInKeyWindow,
                .inVisibleRect
            ]

            trackingAreas.forEach { removeTrackingArea($0) }
            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
        }

        override func mouseDown(with event: NSEvent) {
            onMouseActivity?()

            if event.clickCount == 2 {
                onToggleFullScreen?()
                mouseDownEvent = nil
                return
            }

            mouseDownEvent = event
        }

        override func mouseDragged(with event: NSEvent) {
            onMouseActivity?()

            guard !isFullscreen, let window = window, let downEvent = mouseDownEvent else {
                super.mouseDragged(with: event)
                return
            }

            window.performDrag(with: downEvent)
            mouseDownEvent = nil
        }

        override func mouseUp(with event: NSEvent) {
            onMouseActivity?()
            mouseDownEvent = nil
            super.mouseUp(with: event)
        }

        override func mouseMoved(with event: NSEvent) {
            onMouseActivity?()
            super.mouseMoved(with: event)
        }

        override func scrollWheel(with event: NSEvent) {
            onMouseActivity?()
            if event.scrollingDeltaY > 0 {
                onScrollUp?()
            } else if event.scrollingDeltaY < 0 {
                onScrollDown?()
            }
            super.scrollWheel(with: event)
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard canReadURL(from: sender) else {
                return []
            }
            return .copy
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard let url = readURL(from: sender) else {
                return false
            }
            onOpenURL?(url)
            return true
        }

        private func canReadURL(from draggingInfo: NSDraggingInfo) -> Bool {
            let pb = draggingInfo.draggingPasteboard
            return pb.canReadObject(forClasses: [NSURL.self], options: nil)
        }

        private func readURL(from draggingInfo: NSDraggingInfo) -> URL? {
            let pb = draggingInfo.draggingPasteboard
            guard let objects = pb.readObjects(forClasses: [NSURL.self], options: nil),
                  let url = objects.first as? URL else {
                return nil
            }
            return url
        }
    }
}

