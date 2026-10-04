import AppKit
import PDFKit
import SwiftUI

/// Exercises production Auto setup and assignment controls in a private,
/// inactive window. It never opens or modifies the user's app or documents.
@main @MainActor enum SystemBarUITests {
    static var checks = [String]()
    static weak var debugHost: NSView?
    static let output = URL(fileURLWithPath: ".build/system-bar-request-review")
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message); checks.append(message); print("PASS: \(message)")
    }
    static func pump(_ seconds: Double = 0.15) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
    }
    static func wait(_ description: String, timeout: Double = 30, until predicate: () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end { pump(0.025) }
        if !predicate(), let debugHost { try? dump(debugHost, "timeout-state") }
        precondition(predicate(), "Timed out: \(description)")
    }
    static func value(_ object: NSObject, _ name: String) -> AnyObject? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }
    static func elements(_ root: NSObject) -> [NSObject] {
        var queue: [Any] = [root], result = [NSObject](), seen = Set<ObjectIdentifier>()
        while !queue.isEmpty {
            let object = queue.removeFirst() as AnyObject
            guard seen.insert(ObjectIdentifier(object)).inserted, let element = object as? NSObject else { continue }
            result.append(element); queue += value(element, "accessibilityChildren") as? [Any] ?? []
        }
        return result
    }
    static func label(_ object: NSObject) -> String {
        (value(object, "accessibilityLabel") as? String) ?? (value(object, "accessibilityTitle") as? String) ?? ""
    }
    static func find(_ root: NSObject, _ name: String) -> NSObject? {
        elements(root).first { label($0) == name || value($0, "accessibilityValue") as? String == name }
    }
    static func press(_ element: NSObject?) {
        guard let element else { fatalError("Missing action") }
        let selector = NSSelectorFromString("accessibilityPerformPress")
        typealias Press = @convention(c) (AnyObject, Selector) -> Bool
        precondition(element.responds(to: selector))
        precondition(unsafeBitCast(element.method(for: selector), to: Press.self)(element, selector), "AX action failed: \(label(element))")
    }
    static func textFields(_ root: NSObject) -> [NSObject] {
        elements(root).filter { value($0, "accessibilityRole") as? String == "AXTextField" }
    }
    static func countField(_ root: NSObject) -> NSObject {
        let fields = textFields(root)
        guard let count = fields.first(where: { value($0, "accessibilityPlaceholderValue") as? String == "Count" })
            ?? fields.last else { fatalError("Missing count text field") }
        return count
    }
    static func fieldValue(_ field: NSObject) -> String { value(field, "accessibilityValue") as? String ?? "" }
    static func setText(_ field: NSObject, _ text: String) {
        let selector = NSSelectorFromString("setAccessibilityValue:")
        precondition(field.responds(to: selector))
        typealias SetValue = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        unsafeBitCast(field.method(for: selector), to: SetValue.self)(field, selector, text as NSString)
        if let native = (field as? NSTextField) ?? ((field as? NSCell)?.controlView as? NSTextField) {
            native.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: native))
        }
    }
    static func staff(_ root: NSObject, _ oneBased: Int, page: Int = 1) -> NSObject? {
        elements(root).first { label($0).hasPrefix("Staff \(oneBased), page \(page),") }
    }
    static func drag(_ window: NSWindow, from start: NSObject, to end: NSObject) {
        let selector = NSSelectorFromString("accessibilityFrame")
        typealias Frame = @convention(c) (AnyObject, Selector) -> CGRect
        func point(_ element: NSObject) -> NSPoint {
            let frame = unsafeBitCast(element.method(for: selector), to: Frame.self)(element, selector)
            return window.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
        }
        let a = point(start), b = point(end)
        for index in 0...8 {
            let ratio = CGFloat(min(index, 7)) / 7
            let location = NSPoint(x: a.x + (b.x - a.x) * ratio, y: a.y + (b.y - a.y) * ratio)
            let type: NSEvent.EventType = index == 0 ? .leftMouseDown : index == 8 ? .leftMouseUp : .leftMouseDragged
            let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: index, clickCount: 1, pressure: index == 8 ? 0 : 1)!
            window.sendEvent(event); pump(0.025)
        }
        pump(0.15)
    }
    static func text(_ root: NSObject) -> String {
        elements(root).map { label($0) + " " + (value($0, "accessibilityValue") as? String ?? "") }.joined(separator: "\n")
    }
    static func dump(_ view: NSView, _ name: String) throws {
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let context = CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        context.draw(bitmap.cgImage!, in: CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        let axText = text(view).split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n") + "\n"
        try axText.write(to: output.appendingPathComponent(name + "-accessibility.txt"), atomically: true, encoding: .utf8)
    }
    static func main() throws {
        setbuf(stdout, nil)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared; NSApp.setActivationPolicy(.prohibited); NSApp.finishLaunching()
        NSApp.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        let sourceURL = URL(fileURLWithPath: "Tests/extraction/sources/mozart-k488-page-17.pdf")
        let source = PDFDocument(url: sourceURL)!, fixture = PDFDocument()
        // Two separately indexed copies of the independently counted page17
        // make page-local recall deterministic without a long full-score run.
        fixture.insert(source.page(at: 0)!.copy() as! PDFPage, at: 0)
        fixture.insert(source.page(at: 0)!.copy() as! PDFPage, at: 1)
        let sourceData = fixture.dataRepresentation()!
        var project = ProjectData.empty
        project.pageCount = 2; project.sourceFilename = "Mozart-page17-twice-test.pdf"
        let document = PartsmithDocument(project: project, sourcePDFData: sourceData)
        document.saveScoreProfile(ScoreExtractionProfile(parts: [
            .init(id: "flute", name: "Flute", staffCount: 1),
            .init(id: "piano", name: "Piano", staffCount: 2),
            .init(id: "violin1", name: "Violin I", staffCount: 1),
            .init(id: "violin2", name: "Violin II", staffCount: 1),
            .init(id: "viola", name: "Viola", staffCount: 1),
            .init(id: "cello", name: "Cello", staffCount: 1)
        ], cropMode: "compact", requiresSystemAssignment: true))
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1300, height: 950),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: ScoreExtractionView(document: document, onClose: {}, onShowScore: {}, onFinishPickingNames: {})
            .environment(\.colorScheme, .light))
        host.sizingOptions = []; debugHost = host; window.contentView = host; window.appearance = NSAppearance(named: .aqua); window.orderFront(nil)
        pump(0.5)
        try dump(host, "setup-before-auto")
        press(find(host, "Auto")); pump(5)
        print("Progress after Auto:", document.scoreDetectionProgress as Any)
        try dump(host, "after-auto-diagnostic")
        wait("Auto finishes", timeout: 90) { document.scoreDetectionProgress == nil }
        pump(0.5); try dump(host, "review-ready")
        check(find(host, "Bars in system") != nil, "Real Auto flow exposes Bars in system in the enlarged assignment panel")
        press(find(host, "Flute")); pump()
        for i in 1...6 { press(staff(host, i)); pump(0.025) }
        wait("Six-bar suggestion") { fieldValue(countField(host)) == "6" }
        check(text(host).contains("Suggested from printed barlines"), "Actual Mozart page17 source produces six bars and a review reminder")
        try dump(host, "assign-system-suggested-six")

        press(find(host, "Clear")); pump()
        drag(window, from: staff(host, 1)!, to: staff(host, 6)!)
        check(text(host).contains("6 staves selected"), "Native mouse drag across six staff rows selects the printed system")
        wait("Six-bar suggestion after native drag") { fieldValue(countField(host)) == "6" }

        setText(countField(host), "11"); pump(0.2)
        check(fieldValue(countField(host)) == "11", "Editing the production count binding takes precedence over the suggestion")
        press(find(host, "Assign System")); pump(0.4)
        check(text(host).contains("11 bars"), "Assign System stores the explicitly edited count")
        check(fieldValue(countField(host)).isEmpty, "Advancing to a new unsaved system does not carry over its predecessor's count")
        press(find(host, "Next selected page")); pump(0.35)
        check(staff(host, 1, page: 2) != nil && fieldValue(countField(host)).isEmpty,
            "A different page with identical staff IDs starts without the first page's manual count")
        press(find(host, "Previous selected page")); pump(0.35)
        check(fieldValue(countField(host)) == "11", "Returning from another page recalls the last assigned system instead of a blank next-system slot")
        check(text(host).contains("6 staves selected"), "Page return restores the reviewed staff selection along with its count")
        pump(0.5)
        check(fieldValue(countField(host)) == "11", "Saved reviewed count remains unchanged after the automatic worker could finish")
        try dump(host, "assign-system-recalled-eleven")

        setText(countField(host), "12"); pump()
        drag(window, from: staff(host, 1)!, to: staff(host, 6)!)
        check(text(host).contains("6 staves selected") && fieldValue(countField(host)) == "12",
            "Repeating the same native drag preserves an edited count instead of reloading saved eleven")

        // Selecting a new blank system must clear the old reviewed count.
        press(find(host, "Clear")); pump()
        press(find(host, "None")); pump()
        press(find(host, "Piano")); pump()
        press(staff(host, 7)); pump(0.025)
        press(staff(host, 8)); pump(0.025)
        wait("Piano-only three-bar suggestion") { fieldValue(countField(host)) == "3" }
        check(text(host).contains("2 staves selected"), "Selecting the piano-only system counts its bars once across both staves")
        setText(countField(host), "9"); pump(0.05)
        // Entering a manual value and clearing selection must cancel any
        // outstanding suggestion; switching mode exercises the same guard.
        press(find(host, "Crop Review")); pump(0.15)
        press(find(host, "Assign Instruments")); pump(0.35)
        check(fieldValue(countField(host)) == "11", "Re-entering assignment mode loads the saved count rather than an unsaved edit")
        try dump(host, "assign-system-restored")
        check(document.project.bands.isEmpty && document.project.parts.isEmpty,
            "UI review remains a private proposal and does not mutate user's or fixture output parts")
        try JSONSerialization.data(withJSONObject: ["checks": checks, "count": checks.count,
            "scope": "Inactive native window; production accessibility actions, direct native mouse events, and real Auto detection on two indexed copies of Mozart source page17. Manual11/12/9 are deliberate precedence probes, not reviewed musical counts."], options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("ui-results.json"))
        window.orderOut(nil)
        print("PASS: \(checks.count) production assignment UI checks")
    }
}
