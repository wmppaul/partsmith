import AppKit
import SwiftUI

/// A document-owned, nonmodal window: the score stays usable while setting up parts.
@MainActor
final class ScoreExtractionWindowController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isPresented = false
    private var extractionWindow: NSWindow?
    private weak var sourceWindow: NSWindow?
    private weak var document: PartsmithDocument?

    func attach(to window: NSWindow?) {
        guard sourceWindow !== window else { return }
        if let sourceWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: sourceWindow)
        }
        sourceWindow = window
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(sourceWillClose),
                name: NSWindow.willCloseNotification, object: window)
        }
    }

    func show(document: PartsmithDocument) {
        if let extractionWindow {
            extractionWindow.deminiaturize(nil)
            extractionWindow.makeKeyAndOrderFront(nil)
            return
        }
        self.document = document
        let view = ScoreExtractionView(document: document,
            onClose: { [weak self] in self?.close() },
            onShowScore: { [weak self] in self?.showScore() })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Auto Extract Parts"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.contentMinSize = NSSize(width: 800, height: 580)
        window.delegate = self
        extractionWindow = window
        isPresented = true
        if !window.setFrameUsingName("AutoExtractParts") {
            // Hosting can initially resize a new window to the view's minimum.
            // Give the score a useful opening size after installing its view.
            window.setContentSize(NSSize(width: 1200, height: 820))
            window.center()
        }
        // Restore on the source screen if a saved position belongs to a disconnected display.
        if let screen = sourceWindow?.screen ?? NSScreen.main {
            var frame = window.frame
            let visible = screen.visibleFrame
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
            frame.origin.y = max(visible.minY, min(frame.minY, visible.maxY - frame.height))
            window.setFrame(frame, display: false)
        }
        window.setFrameAutosaveName("AutoExtractParts")
        window.makeKeyAndOrderFront(nil)
    }

    private func showScore() {
        document?.canvasMode = .source
        sourceWindow?.deminiaturize(nil)
        sourceWindow?.makeKeyAndOrderFront(nil)
    }

    func close() {
        extractionWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        document?.cancelScoreDetection()
        document?.cancelInstrumentNamePicking()
        extractionWindow?.contentViewController = nil
        extractionWindow = nil
        isPresented = false
        document = nil
    }

    @objc private func sourceWillClose(_ notification: Notification) { close() }

    deinit { NotificationCenter.default.removeObserver(self) }
}

/// Capture this document's actual window, rather than whichever app window has focus.
struct ScoreExtractionWindowAnchor: NSViewRepresentable {
    let controller: ScoreExtractionWindowController

    func makeNSView(context: Context) -> WindowAnchorView {
        let view = WindowAnchorView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: WindowAnchorView, context: Context) {
        nsView.controller = controller
        controller.attach(to: nsView.window)
    }

    final class WindowAnchorView: NSView {
        weak var controller: ScoreExtractionWindowController?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            controller?.attach(to: window)
        }
    }
}
