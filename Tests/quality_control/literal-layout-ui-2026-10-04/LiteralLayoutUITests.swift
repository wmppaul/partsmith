import AppKit
import SwiftUI

@main @MainActor enum LiteralLayoutUITests {
    static var checks = [String]()
    static let output = URL(fileURLWithPath: ".build/literal-layout-ui-2026-10-04")
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) {
        precondition(ok(), message); checks.append(message); print("PASS: \(message)")
    }
    static func pump(_ seconds: Double = 0.4) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
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
    static func dump(_ view: NSView, _ name: String) throws {
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let context = CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect)
        context.draw(bitmap.cgImage!, in: rect)
        try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
    static func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { views($0) } }
    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited); NSApp.finishLaunching()
        NSApp.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        var project = ProjectData.empty
        var settings = PartLayoutSettings.default
        settings.scale = 1.4
        let part = PartModel(id: UUID(), name: "1. Violine", color: ColorData(red: 0, green: 0.5, blue: 1), layoutSettings: settings, createdAt: .now)
        project.parts = [part]
        let document = PartsmithDocument(project: project)
        document.previewScaleInfo = PartRenderScaleInfo(requestedScale: 1.4, appliedScale: 1.4, maximumSafeScale: 1.09)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 1800), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: InspectorView(document: document).environment(\.colorScheme, .light))
        host.sizingOptions = []
        window.contentView = host; window.appearance = NSAppearance(named: .aqua)
        window.orderFront(nil); pump()
        let text = elements(host).map { label($0) + " " + String(describing: value($0, "accessibilityValue") ?? "" as NSString) }.joined(separator: "\n")
        try text.write(to: output.appendingPathComponent("accessibility-initial.txt"), atomically: true, encoding: .utf8)
        check(host.bounds.width == 340, "Inspector stays at the narrow 340-point viewport")
        check(text.contains("Fits Within Margins") && text.contains("1.09×") && text.contains("1.40×"), "Warning shows safe guidance 1.09× beside chosen Scale 1.40×")
        check(!text.contains("Applied Scale"), "No clamped Applied Scale row is presented")
        check(text.contains("Your chosen Scale is applied") && text.contains("be cut off at the paper edge"), "Visible warning explains requested scale is applied and paper-edge clipping is possible")
        check(text.contains("Side Margins") && text.contains("18 pt"), "New part starts with visible 18-point side margins")
        check(text.contains("Spacing is kept at the selected value") && text.contains("Larger gaps may add pages"), "Visible System Gap caption says chosen spacing is preserved")
        let balance = elements(host).first { label($0) == "Balance Page Fill" }!
        check((value(balance, "accessibilityHelp") as? String)?.contains("keeping the selected scale and system gap") == true, "Balance Page Fill help promises to retain scale and gap")
        let sliders = views(host).compactMap { $0 as? NSSlider }
        print("Native slider count: \(sliders.count)")
        for slider in sliders { print("Slider \(slider.minValue)...\(slider.maxValue) value \(slider.doubleValue)") }
        let axSliders = elements(host).filter { value($0, "accessibilityRole") as? String == "AXSlider" }
        let gapAX = axSliders.first { label($0) == "System Gap" }!
        check((value(gapAX, "accessibilityMinValue") as? NSNumber)?.doubleValue == 4 && (value(gapAX, "accessibilityMaxValue") as? NSNumber)?.doubleValue == 200,
            "Native System Gap accessibility slider exposes the complete 4–200-point range")
        // SwiftUI's backing NSSliders use normalized 0…1 values; the third is gap.
        check(sliders.count == 3, "Scale, margins and gap have three native slider controls")
        let gap = sliders[2]
        gap.doubleValue = 1.0
        check(gap.sendAction(gap.action, to: gap.target), "Native gap slider sends its control action at the maximum")
        pump()
        check(document.selectedPart!.layoutSettings.interSystemGap == 200, "Gap slider commits 200 points to the real document")
        document.previewScaleInfo = PartRenderScaleInfo(requestedScale: 1.4, appliedScale: 1.4, maximumSafeScale: 1.09)
        pump()
        try dump(host, "inspector-340-full.png")
        window.setContentSize(NSSize(width: 340, height: 850)); pump()
        if let scroll = views(host).compactMap({ $0 as? NSScrollView }).first, let content = scroll.documentView {
            content.scroll(NSPoint(x: 0, y: 640)); scroll.reflectScrolledClipView(scroll.contentView); pump()
        }
        try dump(host, "inspector-340-scrolled.png")
        document.updatePartConsistentScale(part.id, enabled: false)
        document.previewScaleInfo = PartRenderScaleInfo(requestedScale: 1.4, appliedScale: 1.4, maximumSafeScale: 1.09)
        pump()
        let independentText = elements(host).map { label($0) + " " + String(describing: value($0, "accessibilityValue") ?? "" as NSString) }.joined(separator: "\n")
        check(independentText.contains("Fits Within Margins") && independentText.contains("Your chosen Scale is applied"), "Independent scaling retains the requested-scale overflow warning")
        try dump(host, "inspector-340-independent.png")
        document.previewScaleInfo = PartRenderScaleInfo(requestedScale: 1.0, appliedScale: 1.0, maximumSafeScale: 1.09)
        document.updatePartScale(part.id, scale: 1.0)
        pump()
        let safeText = elements(host).map { label($0) + " " + String(describing: value($0, "accessibilityValue") ?? "" as NSString) }.joined(separator: "\n")
        check(!safeText.contains("Fits Within Margins") && safeText.contains("Scale applies as requested"), "Within-fit state clears the overflow warning")
        try JSONSerialization.data(withJSONObject: ["checks": checks, "count": checks.count], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
        window.orderOut(nil)
    }
}
