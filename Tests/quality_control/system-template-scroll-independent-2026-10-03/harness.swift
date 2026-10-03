import AppKit
import SwiftUI
import Foundation

final class Model: ObservableObject {
 @Published var selectedPage = 0
 @Published var focusID: UUID?
 @Published var bounds: [Double]?
 var pending: (Int,[Double])?
 var events: [[String:Any]]=[]
 func select(_ b:[Double]) { bounds=b;focusID=UUID();events.append(["event":"selected", "page":selectedPage]) }
 func reveal(page:Int,y:Double) {
  let b=[0.1,y-0.025,0.9,y+0.025]
  if page != selectedPage {pending=(page,b);selectedPage=page} else {select(b)}
 }
}
final class ProbeView:NSView {}
struct Probe:NSViewRepresentable {
 func makeNSView(context:Context)->ProbeView {ProbeView()}
 func updateNSView(_ nsView:ProbeView,context:Context) {}
}
struct Harness:View {
 @ObservedObject var model:Model
 let initial:Bool
 let variant:String
 let pageWidth=1200.0,pageHeight=2400.0
 @ViewBuilder var marker:some View {
  if let b=model.bounds {
   let y=pageHeight*(b[1]+b[3])/2
   if variant=="position" {
    Color.clear.frame(width:1,height:1).position(x:pageWidth/2,y:y).id("matched-system").allowsHitTesting(false)
   } else if variant=="idBeforePosition" {
    Color.clear.frame(width:1,height:1).id("matched-system").position(x:pageWidth/2,y:y).allowsHitTesting(false)
   } else if variant=="offset" {
    Color.clear.frame(width:1,height:1).offset(x:pageWidth/2,y:y).id("matched-system").allowsHitTesting(false)
   } else {
    VStack(spacing:0) { Color.clear.frame(height:y);Color.clear.frame(height:1).id("matched-system");Spacer(minLength:0) }.frame(width:1,height:pageHeight).offset(x:pageWidth/2).allowsHitTesting(false)
   }
   Probe().frame(width:1,height:1).position(x:pageWidth/2,y:y).allowsHitTesting(false)
  }
 }
 var body:some View {
  GeometryReader { geo in
   ScrollViewReader { proxy in
    ScrollView([.horizontal,.vertical]) {
     ZStack(alignment:.topLeading) {
      Color.white.frame(width:pageWidth,height:pageHeight)
      ForEach(0..<24) { i in
       Text("Page \(model.selectedPage) row \(i)").frame(width:pageWidth,height:80).background(i % 2 == 0 ? Color.gray.opacity(0.15):.clear).offset(y:Double(i)*100)
      }
      marker
     }.frame(width:pageWidth,height:pageHeight).padding(.leading,28).frame(minWidth:geo.size.width,minHeight:geo.size.height,alignment:.topLeading)
    }.onChange(of:model.focusID,initial:initial) {
     model.events.append(["event":"scrollCallback","page":model.selectedPage,"hasBounds":model.bounds != nil])
     if model.bounds != nil {proxy.scrollTo("matched-system",anchor:.center)}
    }
   }.id(model.selectedPage)
  }.onChange(of:model.selectedPage) {
   model.bounds=nil
   if let pending=model.pending,pending.0==model.selectedPage {model.select(pending.1);model.pending=nil}
  }
 }
}
func descendants(_ view:NSView)->[NSView] {[view]+view.subviews.flatMap(descendants)}
@main struct Run {
 static func main() {
  let args=CommandLine.arguments;let variant=args.count>1 ? args[1]:"position";let initial=args.count>2 && args[2]=="initial";let out=args.count>3 ? args[3]:"/tmp/scroll-results.json"
  let app=NSApplication.shared;app.setActivationPolicy(.prohibited)
  let model=Model();let window=NSWindow(contentRect:NSRect(x:10000,y:10000,width:620,height:500),styleMask:[.titled],backing:.buffered,defer:false)
  let host=NSHostingView(rootView:Harness(model:model,initial:initial,variant:variant));window.contentView=host;window.orderFront(nil)
  var records:[[String:Any]]=[]
  func measure(_ name:String) {
   host.layoutSubtreeIfNeeded();let views=descendants(host);let scrolls=views.compactMap{$0 as? NSScrollView};let probes=views.compactMap{$0 as? ProbeView}
   var row:[String:Any]=["stage":name,"page":model.selectedPage,"scrollCount":scrolls.count,"probeCount":probes.count,"events":model.events]
   if let sv=scrolls.first,let doc=sv.documentView {
    let visible=doc.visibleRect;row["visibleRect"]=[visible.minX,visible.minY,visible.width,visible.height];row["clipBounds"]=[sv.contentView.bounds.minX,sv.contentView.bounds.minY,sv.contentView.bounds.width,sv.contentView.bounds.height];row["documentFrame"]=[doc.frame.minX,doc.frame.minY,doc.frame.width,doc.frame.height]
    if let probe=probes.first {let rect=probe.convert(probe.bounds,to:doc);row["targetRect"]=[rect.minX,rect.minY,rect.width,rect.height];row["targetVisible"]=visible.intersects(rect);row["targetCenterErrorY"]=rect.midY-visible.midY}
   }
   records.append(row);print(name,row);fflush(stdout)
  }
  func finish() {
   let obj:[String:Any]=["variant":variant,"initial":initial,"windowVisible":window.isVisible,"windowFrame":[window.frame.minX,window.frame.minY,window.frame.width,window.frame.height],"records":records]
   do {try JSONSerialization.data(withJSONObject:obj,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out))}catch{print(error)}
   window.orderOut(nil);app.stop(nil)
   DispatchQueue.main.async {exit(0)}
  }
  DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {measure("initial");model.reveal(page:0,y:0.82)}
  DispatchQueue.main.asyncAfter(deadline:.now()+0.9) {measure("same-page-lower");model.reveal(page:0,y:0.2)}
  DispatchQueue.main.asyncAfter(deadline:.now()+1.4) {measure("same-page-upper");model.reveal(page:1,y:0.82)}
  DispatchQueue.main.asyncAfter(deadline:.now()+1.9) {measure("new-page-lower");model.reveal(page:1,y:0.65)}
  DispatchQueue.main.asyncAfter(deadline:.now()+2.4) {measure("new-page-followup");finish()}
  app.run()
 }
}
