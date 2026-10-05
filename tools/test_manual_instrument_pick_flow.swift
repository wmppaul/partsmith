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
@main @MainActor enum ManualInstrumentPickFlowTests {
    static var checks: [String] = []
    static let output = URL(fileURLWithPath: ".build/manual-name-ui-2026-10-05")

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
            "instrumentNamePickingBar": ["Select instrument names"],
            "manualInstrumentName": ["Instrument name"],
            "manualInstrumentStaffCount": ["Staves for this instrument"],
            "addManualInstrumentName": ["Add Instrument"],
            "cancelManualInstrumentName": ["Cancel"]]
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
        guard let field = (object as? NSTextField) ?? ((object as? NSCell)?.controlView as? NSTextField) else {
            print("Unexpected text field AX class: \(NSStringFromClass(type(of: object)))")
            return false
        }
        field.window?.makeFirstResponder(field)
        if let editor = field.currentEditor() as? NSTextView {
            editor.selectAll(nil)
            editor.insertText(text, replacementRange: editor.selectedRange())
        } else {
            field.stringValue = text
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


    static func views(_ root: NSView) -> [NSView] {
        var queue = [root], found: [NSView] = []
        while !queue.isEmpty { let view = queue.removeFirst(); found.append(view); queue += view.subviews }
        return found
    }

    static func enabled(_ object: NSObject) -> Bool {
        let selector = NSSelectorFromString("isAccessibilityEnabled")
        guard object.responds(to: selector) else { fatalError("No native accessibility enabled state") }
        typealias Read = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(object.method(for: selector), to: Read.self)(object, selector)
    }

    /// Native events are dispatched to the production private overlay found in
    /// the hosted view tree; no direct document pick method bypasses the gesture.
    static func drag(_ region: CGRect, source: NSWindow, document: PartsmithDocument) {
        let all = views(source.contentView!)
        guard let overlay = all.first(where: { NSStringFromClass(type(of: $0)).contains("BandOverlayView") }),
              let pdf = all.compactMap({ $0 as? PDFView }).first,
              let page = pdf.currentPage else { fatalError("No production PDF overlay") }
        let frame = pdf.convert(page.bounds(for: .mediaBox), from: page)
        let start = CGPoint(x: frame.minX + region.minX * frame.width,
                            y: frame.maxY - region.minY * frame.height)
        let end = CGPoint(x: frame.minX + region.maxX * frame.width,
                          y: frame.maxY - region.maxY * frame.height)
        func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: overlay.convert(point, to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: source.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
        }
        overlay.mouseDown(with: event(.leftMouseDown, start))
        overlay.mouseDragged(with: event(.leftMouseDragged, end))
        overlay.mouseUp(with: event(.leftMouseUp, end))
        let deadline = Date().addingTimeInterval(30)
        while document.isRecognizingInstrumentName && Date() < deadline { pump(0.01) }
        pump(0.4)
        check(!document.isRecognizingInstrumentName, "The dragged selection finishes local recognition")
        check(document.instrumentNameDraft != nil, "A dragged blank region opens a manual-name draft")
        if let draft = document.instrumentNameDraft {
            check(abs(draft.bounds.minX - region.minX) < 0.001 && abs(draft.bounds.minY - region.minY) < 0.001
                && abs(draft.bounds.width - region.width) < 0.001 && abs(draft.bounds.height - region.height) < 0.001,
                "The manual draft retains the actual drag rectangle in source coordinates")
        }
    }

    static func increment(_ object: NSObject) -> Bool {
        let selector = NSSelectorFromString("accessibilityPerformIncrement")
        guard object.responds(to: selector) else { return false }
        typealias Perform = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(object.method(for: selector), to: Perform.self)(object, selector)
    }

    static func key(_ characters: String, code: UInt16, in field: NSObject) -> Bool {
        guard let control = (field as? NSTextField) ?? ((field as? NSCell)?.controlView as? NSTextField),
              let window = control.window else { return false }
        window.makeFirstResponder(control)
        guard let editor = control.currentEditor() as? NSTextView else { return false }
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
        editor.keyDown(with: event)
        return true
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
        let sourcePath = "Tests/quality_control/manual-name-ui-2026-10-05/source-page-1.pdf"
        let data = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
        let document = PartsmithDocument(sourcePDFData: data)
        document.project.pageCount = document.pdfDocument!.pageCount
        document.zoomMode = .fitPage
        let originalProject = document.project
        let controller = ScoreExtractionWindowController()
        let source = sourceWindow(document, controller: controller)
        let auto = open(controller, document: document)
        let host = source.contentView!
        check(press(find(auto.contentView!, "selectInstrumentNames")!), "The production Auto action opens score name picking")
        pump(0.7)
        let first = CGRect(x: 0.045, y: 0.565, width: 0.135, height: 0.026)
        drag(first, source: source, document: document)
        check(find(host, "manualInstrumentName") != nil, "The score displays an editable manual instrument-name field")
        check(!enabled(find(host, "addManualInstrumentName")!), "Add is disabled for an empty name")
        check(!enabled(find(host, "finishInstrumentNamePicking")!), "Done is disabled while the highlighted name is unfinished")
        let draft = document.instrumentNameDraft!
        controller.finishPickingNames(); pump()
        check(document.isPickingInstrumentNames && document.instrumentNameDraft?.id == draft.id,
            "An early finish action cannot discard the unfinished selected instrument")
        try dump(source, "source-pending-name.png")
        source.setContentSize(NSSize(width: 760, height: 650)); pump(0.5)
        try dump(source, "source-pending-name-narrow.png")
        check(find(host, "manualInstrumentName") != nil && find(host, "addManualInstrumentName") != nil,
            "Name entry and Add remain available in a narrow source window")
        check(setText(find(host, "manualInstrumentName")!, "   "), "The native name field accepts an edit")
        pump()
        check(!enabled(find(host, "addManualInstrumentName")!), "Whitespace alone cannot add an instrument")
        check(setText(find(host, "manualInstrumentName")!, " Violin "), "The actual native field accepts a typed instrument name")
        pump()
        check(enabled(find(host, "addManualInstrumentName")!), "A typed name enables the actual Add button")
        check(key("\r", code: 36, in: find(host, "manualInstrumentName")!), "Return is sent through the native field editor to add the typed name")
        pump()
        check(document.instrumentNameDraft == nil && document.instrumentNameHighlights.map(\.name) == ["Violin"],
            "Adding replaces the amber draft with one named green selection")
        check(document.instrumentNameHighlights[0].bounds == draft.bounds,
            "The committed manual highlight preserves the user's selected region")
        check(document.isPickingInstrumentNames && enabled(find(host, "finishInstrumentNamePicking")!),
            "Adding keeps selection mode active and makes Done available")
        source.setContentSize(NSSize(width: 980, height: 850)); pump(0.5)
        try dump(source, "source-added-name.png")
        check(enabled(labeled(auto.contentView!, "Auto")!), "Auto becomes available after the first complete instrument name")

        drag(CGRect(x: 0.045, y: 0.66, width: 0.135, height: 0.026), source: source, document: document)
        check(!enabled(labeled(auto.contentView!, "Auto")!), "Auto cannot discard a pending draft when a valid instrument list already exists")
        check(elements(auto.contentView!).contains { label($0).contains("Add or cancel the highlighted name")
            || (value($0, "accessibilityValue") as? String ?? "").contains("Add or cancel the highlighted name") },
            "The Auto setup explains how to finish the highlighted pending name")
        check(setText(find(host, "manualInstrumentName")!, "Violin"), "A second separate area accepts the same typed name")
        pump()
        check(press(find(host, "addManualInstrumentName")!), "The second manual instrument can be added")
        pump()
        check(document.instrumentNameHighlights.map(\.name) == ["Violin", "Violin 2"],
            "Same-name instruments at separate source areas remain two uniquely named selections")

        drag(CGRect(x: 0.045, y: 0.755, width: 0.135, height: 0.058), source: source, document: document)
        check(setText(find(host, "manualInstrumentName")!, "Cello and Bass"), "A grouped unnamed instrument can be named")
        pump()
        guard let count = find(host, "manualInstrumentStaffCount") else { fatalError("No staff-count control") }
        let stepperElements = elements(count)
        guard let stepper = stepperElements.first(where: { $0.responds(to: NSSelectorFromString("accessibilityPerformIncrement")) })
            ?? views(host).compactMap({ $0 as? NSStepper }).first else { fatalError("No native staff stepper") }
        let nativeStepper = views(host).compactMap { $0 as? NSStepper }.first
        let incremented: Bool
        if let nativeStepper {
            nativeStepper.doubleValue += nativeStepper.increment
            incremented = nativeStepper.sendAction(nativeStepper.action, to: nativeStepper.target)
        } else { incremented = increment(stepper) }
        if !incremented {
            let ax = elements(host).map { ["class": NSStringFromClass(type(of: $0)), "label": label($0),
                "identifier": value($0, "accessibilityIdentifier") as? String ?? "",
                "role": value($0, "accessibilityRole") as? String ?? ""] }
            try JSONSerialization.data(withJSONObject: ax, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("stepper-accessibility.json"))
        }
        check(incremented, "The actual native staff-count control increments to two staves")
        pump()
        try dump(source, "source-two-staff-name.png")
        check(press(find(host, "addManualInstrumentName")!), "The named two-staff instrument can be added")
        pump()
        check(document.instrumentNameHighlights.last?.name == "Cello and Bass" && document.instrumentNameHighlights.last?.suggestedStaffCount == 2,
            "The selected two-staff count survives the native Add action")
        let picked = document.instrumentNameHighlights

        drag(CGRect(x: 0.045, y: 0.875, width: 0.135, height: 0.026), source: source, document: document)
        check(setText(find(host, "manualInstrumentName")!, "Discarded"), "An unwanted pending name can be edited before canceling")
        pump()
        check(press(find(host, "cancelManualInstrumentName")!), "The actual Cancel button dismisses an unfinished name")
        pump()
        check(document.instrumentNameDraft == nil && document.instrumentNameHighlights == picked,
            "Cancel removes only the pending area and preserves all committed selections")
        check(enabled(labeled(auto.contentView!, "Auto")!), "Cancel makes Auto available again for the completed instrument list")
        drag(CGRect(x: 0.045, y: 0.895, width: 0.135, height: 0.023), source: source, document: document)
        check(setText(find(host, "manualInstrumentName")!, "Discarded with Escape"), "Another pending name can be edited before keyboard cancellation")
        pump()
        check(key("\u{1b}", code: 53, in: find(host, "manualInstrumentName")!), "Escape is sent through the native field editor")
        pump()
        check(document.instrumentNameDraft == nil && document.instrumentNameHighlights == picked,
            "Escape cancels only the unfinished name and leaves accepted selections unchanged")
        check(press(find(host, "finishInstrumentNamePicking")!), "Done returns to Auto without switching windows manually")
        pump()
        check(!document.isPickingInstrumentNames && FocusRequests.last === auto,
            "Done requests focus for the same owning Auto window")
        check(fields(auto.contentView!) == ["Violin", "Violin 2", "Cello and Bass"],
            "Auto receives all manual names in order, with distinct rows for repeated names")
        try dump(auto, "auto-manual-instruments.png")
        let autoAX = elements(auto.contentView!).map { ["class": NSStringFromClass(type(of: $0)), "label": label($0),
            "value": value($0, "accessibilityValue") as? String ?? "",
            "identifier": value($0, "accessibilityIdentifier") as? String ?? "",
            "role": value($0, "accessibilityRole") as? String ?? ""] }
        try JSONSerialization.data(withJSONObject: autoAX, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("auto-accessibility.json"))
        let countLabels = autoAX.filter { $0["role"] == "AXStaticText" }.map { ($0["value"] ?? "").isEmpty ? ($0["label"] ?? "") : $0["value"]! }
        check(countLabels.filter { ["1 staff", "2 staves"].contains($0) } == ["1 staff", "1 staff", "2 staves"],
            "The actual Auto staff-count labels retain one, one, and two staves")
        check(document.project == originalProject && document.sourcePDFData == data,
            "Name picking and returning preserve the entire project and original source PDF")
        check(press(find(auto.contentView!, "selectInstrumentNames")!), "A manual list supports another source-picking session")
        pump()
        drag(CGRect(x: 0.045, y: 0.875, width: 0.135, height: 0.023), source: source, document: document)
        source.close(); pump()
        check(!controller.isPresented && document.instrumentNameDraft == nil && !document.isPickingInstrumentNames,
            "Closing the source cleans up an unfinished name and its owned Auto window")
        let report: [String: Any] = ["checks": checks, "count": checks.count,
            "scope": "Actual production SourceCanvas SwiftUI, native mouse drag events on its BandOverlayView, local Vision OCR, native field/stepper/Add/Cancel/Done accessibility actions, and owning Auto window. Isolated offscreen process; no user app or project modified.",
            "focusLimit": "Activation-prohibited test process records and forwards production focus requests; it does not claim OS foreground/key-window behavior.",
            "source": sourcePath,
            "screenshots": ["source-pending-name.png", "source-pending-name-narrow.png", "source-added-name.png", "source-two-staff-name.png", "auto-manual-instruments.png"]]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("results.json"))
        print("PASS: \(checks.count) manual instrument-picking flow checks")
    }
}
