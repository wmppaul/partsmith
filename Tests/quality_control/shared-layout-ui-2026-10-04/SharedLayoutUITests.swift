import AppKit
import SwiftUI

@main @MainActor enum SharedLayoutUITests {
    static var checks = [String]()
    static let output = URL(fileURLWithPath: ".build/shared-layout-ui-2026-10-04")
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
    static func press(_ object: NSObject) -> Bool {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        guard object.responds(to: selector) else { return false }
        typealias Press = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(object.method(for: selector), to: Press.self)(object, selector)
    }
    static func text(_ host: NSView) -> String {
        elements(host).map { (label($0) + " " + String(describing: value($0, "accessibilityValue") ?? "" as NSString)).trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }
    static func activate(_ label: String, in host: NSView) {
        let element = elements(host).first { self.label($0) == label && $0.responds(to: NSSelectorFromString("accessibilityPerformPress")) }
        check(element != nil, "Native control is accessible: \(label)")
        check(press(element!), "Native control activates: \(label)")
        pump()
    }
    static func setSlider(_ index: Int, normalized: Double, in host: NSView, settle: Bool = true) {
        let sliders = views(host).compactMap { $0 as? NSSlider }
        check(sliders.count == 3, "Three native sliders are present")
        sliders[index].doubleValue = normalized
        check(sliders[index].sendAction(sliders[index].action, to: sliders[index].target), "Native slider \(index) accepts \(normalized)")
        if settle { pump() }
    }
    static func effective(_ document: PartsmithDocument, _ part: PartModel) -> PartLayoutSettings {
        document.part(withID: part.id)!.layoutSettings.resolved(in: document.project.projectSettings)
    }
    static func main() throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited); NSApp.finishLaunching()
        NSApp.accessibilitySetValue(true, forAttribute: .init(rawValue: "AXEnhancedUserInterface"))
        var project = ProjectData.empty
        project.projectSettings.defaultScale = 1.25
        project.projectSettings.interSystemGap = 100
        var settings = PartLayoutSettings.default
        settings.usesSharedLayout = true
        let part = PartModel(id: UUID(), name: "1. Violine", color: ColorData(red: 0, green: 0.5, blue: 1), layoutSettings: settings, createdAt: .now)
        var second = part; second.id = UUID(); second.name = "2. Violine"
        project.parts = [part, second]
        let document = PartsmithDocument(project: project)
        document.previewScaleInfo = PartRenderScaleInfo(requestedScale: 1.25, appliedScale: 1.25, maximumSafeScale: 1.09)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 2100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: InspectorView(document: document).environment(\.colorScheme, .light))
        host.sizingOptions = []
        window.contentView = host; window.appearance = NSAppearance(named: .aqua)
        window.orderFront(nil); pump()
        var snapshot = text(host)
        try snapshot.write(to: output.appendingPathComponent("accessibility-shared.txt"), atomically: true, encoding: .utf8)
        check(host.bounds.width == 340, "Inspector stays at the narrow 340-point viewport")
        check(snapshot.contains("Score Layout") && snapshot.contains("stay synchronized across parts"), "Shared scope and behavior are clearly displayed")
        check(snapshot.contains("1.25×") && snapshot.contains("100 pt") && snapshot.contains("18 pt"), "Sliders display inherited scale, gap and margins rather than stale raw defaults")
        check(!snapshot.contains("Use These Settings for All Parts"), "Apply-all button stays hidden when every part already follows the score")
        check(snapshot.contains("Fits Within Margins") && snapshot.contains("Your chosen Scale is applied"), "Overflow remains a warning with requested scale applied")
        try dump(host, "inspector-340-shared-full.png")
        setSlider(0, normalized: 1.0, in: host)
        check(document.project.projectSettings.defaultScale == 1.4 && effective(document, second).scale == 1.4, "Shared Scale updates score and another linked part")
        setSlider(1, normalized: 0.25, in: host)
        check(document.project.projectSettings.margins.leading == 36 && document.project.projectSettings.margins.trailing == 36, "Shared margins update both score margins")
        setSlider(2, normalized: 1.0, in: host)
        check(document.project.projectSettings.interSystemGap == 200 && effective(document, second).interSystemGap == 200, "Shared Gap updates score and another linked part")
        activate("Customize This Part", in: host)
        check(document.part(withID: part.id)!.layoutSettings.usesSharedLayout == false, "Customize toggle creates a local override")
        snapshot = text(host)
        check(snapshot.contains("Part Override") && snapshot.contains("apply only to this part"), "Local scope is clearly displayed")
        check(snapshot.contains("Use These Settings for All Parts"), "Local override offers a visible apply-all action")
        setSlider(0, normalized: 0.5, in: host)
        setSlider(1, normalized: 0.125, in: host)
        setSlider(2, normalized: 0.0, in: host)
        check(effective(document, part).scale == 1 && effective(document, part).interSystemGap == 4, "Local scale and gap accept changes")
        check(effective(document, second).scale == 1.4 && effective(document, second).interSystemGap == 200 && document.project.projectSettings.margins.leading == 36, "Local slider edits leave shared score settings intact")
        check(effective(document, part).outputMargins(in: document.project.projectSettings).leading == 18, "Local margin slider changes only the override")
        document.previewScaleInfo = nil
        pump()
        try text(host).write(to: output.appendingPathComponent("accessibility-local.txt"), atomically: true, encoding: .utf8)
        try dump(host, "inspector-340-local-full.png")
        activate("Use These Settings for All Parts", in: host)
        check(document.project.parts.allSatisfy { $0.layoutSettings.usesSharedLayout == true }, "Apply-all rejoins every part to score settings")
        check(document.project.projectSettings.defaultScale == 1 && document.project.projectSettings.interSystemGap == 4 && document.project.projectSettings.margins.leading == 18, "Apply-all promotes selected effective settings")
        // The native sendAction bridge commits synchronously. Exercise immediate
        // scope changes here; deferred-callback protection is reviewed in source.
        setSlider(0, normalized: 1.0, in: host, settle: false)
        let committedScale = document.project.projectSettings.defaultScale
        document.setPartLayoutOverride(part.id, enabled: true)
        pump()
        check(effective(document, part).scale == committedScale && document.project.projectSettings.defaultScale == committedScale,
            "Immediate shared edit is preserved when customizing the part")
        document.updatePartScale(part.id, scale: 1.3); pump()
        setSlider(0, normalized: 0.0, in: host, settle: false)
        document.setPartLayoutOverride(part.id, enabled: false)
        pump()
        check(document.project.projectSettings.defaultScale == committedScale && effective(document, second).scale == committedScale,
            "Immediate local edit does not overwrite shared settings when rejoining")
        // Legacy asymmetric margins remain distinct until the user moves the margin slider.
        document.project.projectSettings.margins.leading = 18
        document.project.projectSettings.margins.trailing = 33
        pump()
        check(text(host).contains("L 18 · R 33 pt") && text(host).contains("Moving the slider sets both"), "Asymmetric margins are displayed explicitly without flattening")
        activate("Customize This Part", in: host)
        check(effective(document, part).outputMargins(in: document.project.projectSettings).trailing == 33, "Customize preserves asymmetric margins")
        try dump(host, "inspector-340-asymmetric-full.png")
        window.setContentSize(NSSize(width: 340, height: 850)); pump()
        if let scroll = views(host).compactMap({ $0 as? NSScrollView }).first, let content = scroll.documentView {
            content.scroll(NSPoint(x: 0, y: 550)); scroll.reflectScrolledClipView(scroll.contentView); pump()
        }
        try dump(host, "inspector-340-local-scrolled.png")
        activate("Use Project Margins", in: host)
        check(document.part(withID: part.id)!.layoutSettings.sideMarginOverride == nil, "Use Project Margins clears frozen pair explicitly")
        activate("Balance Page Fill", in: host)
        check(document.part(withID: part.id)!.layoutSettings.balancePages == false && document.part(withID: second.id)!.layoutSettings.balancePages == true, "Balance Page Fill remains a per-part choice")
        try JSONSerialization.data(withJSONObject: ["checks": checks, "count": checks.count], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
        window.orderOut(nil)
    }
}
