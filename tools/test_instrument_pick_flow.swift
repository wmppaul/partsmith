import AppKit
import PDFKit
import SwiftUI
import ObjectiveC

@MainActor private enum FocusRequests { static weak var last: NSWindow? }

extension NSWindow {
    @objc fileprivate dynamic func instrumentFlowMakeKeyAndOrderFront(_ sender: Any?) {
        FocusRequests.last = self
        // Calls AppKit's original implementation after the in-process exchange.
        instrumentFlowMakeKeyAndOrderFront(sender)
    }
}

/// Private, offscreen application process. Calls production accessibility actions,
/// document OCR and window-controller actions; never opens a user's document.
@main @MainActor enum InstrumentPickFlowTests {
    static var checks: [String] = []
    static let output = URL(fileURLWithPath: ".build/selected-page-picking-2026-10-04")

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks.append(message)
        print("PASS: \(message)")
    }

    static func pump(_ seconds: Double = 0.25) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }

    static func value(_ object: NSObject, _ name: String) -> AnyObject? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }

    static func elements(_ root: NSObject) -> [NSObject] {
        var queue: [Any] = [root], result: [NSObject] = [], seen = Set<ObjectIdentifier>()
        while !queue.isEmpty {
            let object = queue.removeFirst() as AnyObject
            guard seen.insert(ObjectIdentifier(object)).inserted, let element = object as? NSObject else { continue }
            result.append(element)
            queue += value(element, "accessibilityChildren") as? [Any] ?? []
        }
        return result
    }

    static func find(_ root: NSObject, _ identifier: String) -> NSObject? {
        let names = ["selectInstrumentNames": ["Select Instrument Names on Score", "Add Names from Score"],
            "finishInstrumentNamePicking": ["Done — Back to Auto Extract"],
            "instrumentNamePickingBar": ["Select instrument names"]]
        return elements(root).first { value($0, "accessibilityIdentifier") as? String == identifier
            || (names[identifier] ?? []).contains(label($0)) }
    }

    static func label(_ object: NSObject) -> String {
        (value(object, "accessibilityLabel") as? String)
            ?? (value(object, "accessibilityTitle") as? String) ?? ""
    }

    static func fields(_ root: NSObject) -> [String] {
        elements(root).filter { value($0, "accessibilityRole") as? String == "AXTextField" }
            .compactMap { value($0, "accessibilityValue") as? String }
    }

    static func press(_ object: NSObject) -> Bool {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        guard object.responds(to: selector) else { return false }
        typealias Press = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(object.method(for: selector), to: Press.self)(object, selector)
    }

    static func labeled(_ root: NSObject, _ text: String) -> NSObject? {
        elements(root).first { label($0) == text }
    }

    static func setText(_ object: NSObject, _ text: String) -> Bool {
        let selector = NSSelectorFromString("setAccessibilityValue:")
        guard object.responds(to: selector) else { return false }
        typealias SetValue = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        unsafeBitCast(object.method(for: selector), to: SetValue.self)(object, selector, text as NSString)
        if let field = (object as? NSTextField) ?? ((object as? NSCell)?.controlView as? NSTextField) {
            // An offscreen AX value assignment does not run the field editor's
            // change notification. Deliver the same native control event so
            // SwiftUI receives the edit through its production delegate.
            field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        }
        return true
    }

    static func selectSegment(_ text: String, in root: NSView) -> Bool {
        var queue = [root]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let control = view as? NSSegmentedControl,
               let index = (0..<control.segmentCount).first(where: { control.label(forSegment: $0) == text }) {
                // NSAccessibilitySegment does not implement Press in the
                // inactive test window; deliver the owning native action.
                control.setSelected(true, forSegment: index)
                return control.sendAction(control.action, to: control.target)
            }
            queue += view.subviews
        }
        return false
    }

    static func pickingRoundTrip(_ document: PartsmithDocument, source: NSWindow, auto: NSWindow,
        expectedPage: Int, description: String) {
        guard press(find(auto.contentView!, "selectInstrumentNames")!) else { fatalError("Cannot start \(description)") }
        pump()
        check(document.currentPageIndex == expectedPage && document.isPickingInstrumentNames
            && FocusRequests.last === source, description)
        guard press(find(source.contentView!, "finishInstrumentNamePicking")!) else { fatalError("Cannot finish \(description)") }
        pump()
        check(!document.isPickingInstrumentNames && FocusRequests.last === auto,
            "Done returns to the owning Auto setup after: \(description)")
    }

    static func dump(_ window: NSWindow, _ name: String) throws {
        let view = window.contentView!
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No screenshot bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let context = CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect)
        context.draw(bitmap.cgImage!, in: rect)
        let opaque = NSBitmapImageRep(cgImage: context.makeImage()!)
        try opaque.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }

    static func sourceWindow(_ document: PartsmithDocument, controller: ScoreExtractionWindowController) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 980, height: 850),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: SourceCanvasView(document: document,
            onImportRequested: {}, onImportDropped: { _ in }, onNewPartRequested: {},
            onAutoExtractRequested: { controller.show(document: document) },
            onFinishPickingInstrumentNames: controller.finishPickingNames)
            .environment(\.colorScheme, .light))
        // DocumentRoot's split view provides a fixed viewport in the app. Prevent
        // this standalone host from enlarging its window to PDFKit's document.
        host.sizingOptions = []
        window.contentView = host
        controller.attach(to: window)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    static func open(_ controller: ScoreExtractionWindowController, document: PartsmithDocument) -> NSWindow {
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        controller.show(document: document)
        let window = NSApp.windows.first { !before.contains(ObjectIdentifier($0)) && $0.title == "Auto Extract Parts" }!
        window.setFrame(NSRect(x: -10000, y: -10000, width: 1200, height: 850), display: true)
        window.appearance = NSAppearance(named: .aqua)
        pump(0.6)
        return window
    }

    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.finishLaunching()
        NSApp.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        let original = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.makeKeyAndOrderFront(_:)))!
        let recording = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.instrumentFlowMakeKeyAndOrderFront(_:)))!
        method_exchangeImplementations(original, recording)
        defer { method_exchangeImplementations(original, recording) }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let data = try Data(contentsOf: URL(fileURLWithPath:
            "sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf"))
        let document = PartsmithDocument(sourcePDFData: data)
        document.project.pageCount = document.pdfDocument!.pageCount
        let originalProject = document.project
        let controller = ScoreExtractionWindowController()
        let source = sourceWindow(document, controller: controller)
        let auto = open(controller, document: document)
        let autoHost = auto.contentView!
        try dump(auto, "setup-empty.png")
        auto.setContentSize(NSSize(width: 800, height: 580)); pump()
        try dump(auto, "setup-empty-narrow.png")
        auto.setContentSize(NSSize(width: 1200, height: 828)); pump()
        let ax = elements(autoHost).map { ["class": NSStringFromClass(type(of: $0)), "label": label($0),
            "identifier": value($0, "accessibilityIdentifier") as? String ?? "",
            "role": value($0, "accessibilityRole") as? String ?? ""] }
        try JSONSerialization.data(withJSONObject: ax, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("initial-accessibility.json"))
        guard let firstAction = find(autoHost, "selectInstrumentNames") else { fatalError("No direct selection action") }
        check(label(firstAction) == "Select Instrument Names on Score", "Empty setup presents the direct selection action")
        check(press(firstAction), "The actual setup accessibility button starts selection")
        pump()
        check(document.isPickingInstrumentNames && document.canvasMode == .source, "Starting selection enters source picking mode")
        check(FocusRequests.last === source, "Starting selection requests focus for this document's source window")
        check(find(source.contentView!, "instrumentNamePickingBar") != nil, "The score contains a persistent selection bar")
        guard let finishEmpty = find(source.contentView!, "finishInstrumentNamePicking") else { fatalError("No source return action") }
        check(press(finishEmpty), "The actual source Done button completes a zero-pick session")
        pump()
        check(!document.isPickingInstrumentNames && FocusRequests.last === auto, "Done requests focus for the existing Auto window")
        check(fields(autoHost).isEmpty, "A zero-pick session does not invent instrument rows")

        check(press(find(autoHost, "selectInstrumentNames")!), "Selection can be restarted from the existing setup")
        pump()
        document.pickInstrumentName(at: CGPoint(x: 0.115, y: 0.227), pageIndex: 0)
        check(document.isRecognizingInstrumentName, "A real printed-name read enters recognition state")
        controller.finishPickingNames()
        check(document.isPickingInstrumentNames && FocusRequests.last === source, "Done during recognition cannot discard the pending name or return early")
        let deadline = Date().addingTimeInterval(30)
        while document.isRecognizingInstrumentName && Date() < deadline { pump(0.01) }
        check(document.instrumentNamePick?.name == "1. Violine", "Real score recognition returns the complete first violin name")
        // The production subscription is synchronous. Complete immediately after
        // recognition, without a settling delay for a covered setup view.
        controller.finishPickingNames()
        pump()
        check(fields(autoHost).contains("1. Violine"), "Immediate Done retains the final recognized name in the covered setup")
        check(FocusRequests.last === auto && !document.isPickingInstrumentNames, "Immediate Done requests focus for the same setup window")
        check(label(find(autoHost, "selectInstrumentNames")!) == "Add Names from Score", "Populated setup makes the additive action explicit")

        check(press(find(autoHost, "selectInstrumentNames")!), "The additive action reopens source picking")
        pump()
        document.pickInstrumentName(at: CGPoint(x: 0.115, y: 0.268), pageIndex: 0)
        let secondDeadline = Date().addingTimeInterval(30)
        while document.isRecognizingInstrumentName && Date() < secondDeadline { pump(0.01) }
        check(document.instrumentNamePick?.name == "2. Violine", "The second printed violin remains a distinct recognized name")
        pump()
        try dump(source, "source-selecting.png")
        source.setContentSize(NSSize(width: 760, height: 650)); pump()
        try dump(source, "source-selecting-narrow.png")
        source.setContentSize(NSSize(width: 980, height: 850)); pump()
        check(press(find(source.contentView!, "finishInstrumentNamePicking")!), "The visible Done button returns after successful recognition")
        pump()
        check(fields(autoHost).filter { $0.contains("Violine") } == ["1. Violine", "2. Violine"],
            "Both instrument rows and their score order survive the complete round trip")
        try dump(auto, "setup-populated.png")
        let priorFields = fields(autoHost)
        check(press(find(autoHost, "selectInstrumentNames")!), "An established list supports another picking session")
        pump()
        check(press(find(source.contentView!, "finishInstrumentNamePicking")!), "An established list supports zero-pick Done")
        pump()
        check(fields(autoHost) == priorFields, "Returning without more picks preserves the established list exactly")

        document.currentPageIndex = 5
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 5,
            description: "All Pages preserves the current source page instead of jumping to a cover")
        document.currentPageIndex = 7
        guard press(labeled(autoHost, "Current Page")!) else { fatalError("No Current Page action") }
        pump()
        check(value(labeled(autoHost, "Page range")!, "accessibilityValue") as? String == "8",
            "The actual Current Page action defines an explicit extraction selection")
        document.currentPageIndex = 0
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 7,
            description: "Name picking opens the selected eighth page from the document cover")
        guard setText(labeled(autoHost, "Page range")!, "8, 3-4") else { fatalError("Cannot edit Page range") }
        pump()
        check(value(labeled(autoHost, "Page range")!, "accessibilityValue") as? String == "8, 3-4",
            "The real editable Page range accepts a discontiguous selection")
        try dump(auto, "setup-selected-pages.png")
        document.currentPageIndex = 9
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 2,
            description: "An unsorted selected range opens its first page in document order")
        check(fields(autoHost).filter { $0.contains("Violine") } == ["1. Violine", "2. Violine"],
            "Changing page selection and returning preserves both named instruments")
        guard setText(labeled(autoHost, "Page range")!, "1-9999") else { fatalError("Cannot edit invalid Page range") }
        pump()
        check(elements(autoHost).contains {
            label($0).hasPrefix("Use page numbers from 1 to")
                || (value($0, "accessibilityValue") as? String ?? "").hasPrefix("Use page numbers from 1 to")
        },
            "An out-of-range page edit is visibly reported as invalid")
        document.currentPageIndex = 4
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 4,
            description: "An invalid range keeps the current page rather than using the stale valid selection")
        guard press(labeled(autoHost, "Clear")!) else { fatalError("No Clear action") }
        pump()
        check(value(labeled(autoHost, "Page range")!, "accessibilityValue") as? String == "",
            "The actual Clear action removes the selected page range")
        document.currentPageIndex = 6
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 6,
            description: "An empty explicit selection preserves the current source page")
        guard setText(labeled(autoHost, "Page range")!, "3-4"),
              selectSegment("All Pages", in: autoHost) else { fatalError("Cannot switch to All Pages") }
        pump()
        document.currentPageIndex = 8
        pickingRoundTrip(document, source: source, auto: auto, expectedPage: 8,
            description: "Switching back to All Pages ignores the previously selected range")
        document.currentPageIndex = 0

        let otherDocument = PartsmithDocument(sourcePDFData: data)
        otherDocument.project.pageCount = otherDocument.pdfDocument!.pageCount
        let otherController = ScoreExtractionWindowController()
        let otherSource = sourceWindow(otherDocument, controller: otherController)
        let otherAuto = open(otherController, document: otherDocument)
        check(press(find(autoHost, "selectInstrumentNames")!), "First document can start picking while another Auto window exists")
        pump()
        otherAuto.makeKeyAndOrderFront(nil)
        controller.finishPickingNames()
        pump()
        check(FocusRequests.last === auto, "Done targets its owning Auto window, not whichever document most recently requested focus")
        check(fields(otherAuto.contentView!).isEmpty && !otherDocument.isPickingInstrumentNames,
            "The other document's setup and selection state remain untouched")
        check(press(find(autoHost, "selectInstrumentNames")!), "Source-close cleanup is exercised during a live picking session")
        pump()
        source.close()
        pump()
        check(!controller.isPresented && !document.isPickingInstrumentNames && !auto.isVisible,
            "Closing the source closes its Auto window and cancels picking")
        controller.finishPickingNames()
        pump()
        check(!controller.isPresented && !auto.isVisible, "A late Done callback never resurrects a closed setup")
        check(document.project == originalProject, "Picking and returning only edit transient setup, not the source project")
        otherSource.close(); pump()
        check(!otherController.isPresented, "The second document also cleans up its owned Auto window")
        let report: [String: Any] = ["checks": checks, "count": checks.count,
            "scope": "Actual production SwiftUI accessibility actions, native window controllers and real Brahms OCR in an isolated process; no user app or document modified.",
            "focusLimit": "Activation-prohibited process intentionally cannot become the user's active app. An in-process recorder intercepts and forwards the actual production makeKeyAndOrderFront calls to verify their target; this checks focus requests, not OS-level key-window status.",
            "screenshots": ["setup-empty.png", "setup-empty-narrow.png", "source-selecting.png", "source-selecting-narrow.png", "setup-populated.png", "setup-selected-pages.png"]]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("results.json"))
        print("PASS: \(checks.count) instrument-picking flow checks")
    }
}
