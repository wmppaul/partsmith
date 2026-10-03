import AppKit
import PDFKit
import SwiftUI

@MainActor final class Store: ObservableObject {
    @Published var review: ScoreDetectionReview?
    var revealed = 0
    var applied = 0
    init(_ review: ScoreDetectionReview) { self.review = review }
}
struct Host: View {
    @ObservedObject var store: Store
    var body: some View {
        ScrollView {
            ScoreSystemTemplatePanel(review: $store.review, onReveal: { _ in store.revealed += 1 }, onApplied: { store.applied += $0 })
                .padding(16)
        }.frame(width: 330, height: 820).background(Color.white).environment(\.colorScheme, .light)
    }
}
@main enum PanelUI {
    struct Inventory: Decodable { var source: String?; var pages: [ScorePageAnalysis] }
    @MainActor static func main() throws {
        let a=CommandLine.arguments,d=JSONDecoder(),base=URL(fileURLWithPath:a[1]),out=URL(fileURLWithPath:a[2])
        let inventory=try d.decode(Inventory.self,from:Data(contentsOf:base.appendingPathComponent("inventory.json")))
        let profile=try d.decode(ScoreExtractionProfile.self,from:Data(contentsOf:base.appendingPathComponent("profile.json")))
        let templates=try d.decode([ScorePageOverride].self,from:Data(contentsOf:base.appendingPathComponent("templates.json")))
        let source=try Data(contentsOf:URL(fileURLWithPath:a[3]))
        let review=ScoreDetectionReview.initial(profile:profile,analyses:inventory.pages,overrides:templates,sourcePDFData:source,rectifications:[])
        let store=Store(review)
        _=NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let window=NSWindow(contentRect:NSRect(x:-10000,y:-10000,width:330,height:820),styleMask:[.borderless],backing:.buffered,defer:false)
        let host=NSHostingView(rootView:Host(store:store));window.contentView=host
        host.frame=NSRect(x:0,y:0,width:330,height:820)
        window.orderFrontRegardless()
        func tick(_ seconds: Double) {
            let end=Date().addingTimeInterval(seconds)
            while Date()<end { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
        }
        func dump(_ file: String) throws {
            host.layoutSubtreeIfNeeded();host.displayIfNeeded()
            guard let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else { fatalError("No bitmap") }
            host.cacheDisplay(in:host.bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(file))
        }
        func value(_ object: NSObject, _ name: String) -> AnyObject? {
            let selector=NSSelectorFromString(name)
            guard object.responds(to:selector) else {return nil}
            return object.perform(selector)?.takeUnretainedValue()
        }
        func find(_ label: String) -> NSObject? {
            var queue:[Any]=[host],seen=Set<ObjectIdentifier>()
            while !queue.isEmpty {
                let object=queue.removeFirst() as AnyObject
                if !seen.insert(ObjectIdentifier(object)).inserted {continue}
                guard let element=object as? NSObject else {continue}
                if value(element,"accessibilityLabel") as? String == label || value(element,"accessibilityTitle") as? String == label {return element}
                queue += value(element,"accessibilityChildren") as? [Any] ?? []
            }
            return nil
        }
        func press(_ object: NSObject) -> Bool {
            let selector=NSSelectorFromString("accessibilityPerformPress")
            guard object.responds(to:selector) else {return false}
            typealias Press = @convention(c) (AnyObject, Selector) -> Bool
            return unsafeBitCast(object.method(for:selector),to:Press.self)(object,selector)
        }
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        tick(0.5);try dump("initial.png")
        let commands=out.appendingPathComponent("commands")
        try FileManager.default.createDirectory(at:commands,withIntermediateDirectories:true)
        var seen=Set<String>()
        let deadline=Date().addingTimeInterval(240)
        while Date()<deadline {
            for file in (try FileManager.default.contentsOfDirectory(at:commands,includingPropertiesForKeys:nil)).sorted(by:{$0.lastPathComponent<$1.lastPathComponent}) where !seen.contains(file.lastPathComponent) {
                seen.insert(file.lastPathComponent)
                let command=try JSONSerialization.jsonObject(with:Data(contentsOf:file)) as! [String:Any]
                if let point=command["click"] as? [Double] {
                    let location=NSPoint(x:point[0],y:host.bounds.height-point[1])
                    for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
                        let event=NSEvent.mouseEvent(with:type,location:location,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
                        window.sendEvent(event)
                    }
                    tick(0.3)
                }
                if let name=command["snapshot"] as? String {try dump(name)}
                if command["finish"] as? Bool == true {
                    print("Local panel event test: applied \(store.applied), revealed \(store.revealed)")
                    return
                }
            }
            tick(0.05)
        }
        print("Local panel timed out: applied \(store.applied), revealed \(store.revealed)")
    }
}
