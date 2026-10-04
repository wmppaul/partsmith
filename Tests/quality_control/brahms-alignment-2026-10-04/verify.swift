import AppKit
import PDFKit
import Foundation
struct Envelope: Codable { var project: ProjectData }
@main enum Verify {
 static var checks = 0
 static func check(_ valid: Bool, _ message: String) throws {
  checks += 1
  if !valid { throw NSError(domain: "BrahmsAlignment", code: checks, userInfo: [NSLocalizedDescriptionKey:message]) }
 }
 static func rect(_ band: BandModel, _ box: CGRect) -> CGRect {
  CGRect(x:box.minX+band.leftFraction*box.width,y:box.maxY-band.bottomFraction*box.height,width:(1-band.leftFraction-band.rightFraction)*box.width,height:(band.bottomFraction-band.topFraction)*box.height)
 }
 static func array(_ rect: CGRect) -> [Double] { [rect.minX,rect.minY,rect.width,rect.height] }
 static func reference(plan: PartRenderPlan, project: ProjectData, source: Data) throws -> Data {
  let data=NSMutableData(); var box=CGRect(origin:.zero,size:plan.pageSize)
  let context=CGContext(consumer:CGDataConsumer(data:data)!,mediaBox:&box,nil)!
  let cache=SourcePageRenderCache(pdfDocument:PDFDocument(data:source)!)
  for page in plan.pages {
   context.beginPDFPage(nil);context.setFillColor(NSColor.white.cgColor);context.fill(box)
   for placement in page.placements {
    let band=project.bands.first{$0.id==placement.bandID}!, full=rect(band,cache.pageBounds(for:placement.sourcePageIndex)!)
    let scale=placement.destinationRect.width/placement.sourceRect.width
    let target=CGRect(x:placement.destinationRect.minX+(full.minX-placement.sourceRect.minX)*scale,y:placement.destinationRect.minY,width:full.width*scale,height:full.height*scale)
    try cache.draw(pageIndex:band.pageIndex,rectification:nil,sourceRect:full,destinationRect:target,in:context)
   }
   context.endPDFPage()
  }
  context.closePDF();return data as Data
 }
 static func pixels(_ data: Data, index: Int) -> (Data, Int, Int) {
  let page=PDFDocument(data:data)!.page(at:index)!,box=page.bounds(for:.mediaBox)
  let width=Int(box.width*2),height=Int(box.height*2)
  let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.setFillColor(NSColor.white.cgColor);c.fill(CGRect(x:0,y:0,width:width,height:height));c.scaleBy(x:2,y:2);c.drawPDFPage(page.pageRef!)
  return (Data(bytes:c.data!,count:width*height*4),width,height)
 }
 static func main() throws {
  let variant=CommandLine.arguments[1]
  let root=URL(fileURLWithPath:".build/brahms-alignment-2026-10-04/"+variant)
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  let package=URL(fileURLWithPath:"output/pdf/auto-qc-2026-10-04/brahms-quartet-93521-reviewed-trims/Brahms — String Quartet No.3, Op.67.partsmithproject")
  let source=try Data(contentsOf:package.appendingPathComponent("source.pdf"))
  let projectData=try Data(contentsOf:package.appendingPathComponent("project.json"))
  let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
  var base=try decoder.decode(Envelope.self,from:projectData).project
  base.parts=[base.parts[0]];base.bands=base.sortedBands(for:base.parts[0].id).filter{$0.pageIndex==2}
  base.parts[0].layoutSettings.sideMarginPoints=30
  base.parts[0].layoutSettings.useConsistentScale=true
  base.projectSettings.showPartNameInHeader=false;base.projectSettings.showTitleBlock=false
  base.projectSettings.margins.bottom=0
  let cases:[(Double,Double)] = variant=="before" ? [(1.05,20)] : [(1.05,20),(1.3,20),(1.4,20),(1.05,100),(1.05,200)]
  var reports:[[String:Any]]=[]
  for (scale,gap) in cases {
   var project=base;project.parts[0].layoutSettings.scale=scale;project.parts[0].layoutSettings.interSystemGap=gap
   project.parts[0].layoutSettings.balancePages=true
   let original=project
   let cache=SourcePageRenderCache(pdfDocument:PDFDocument(data:source)!)
   let plan=try PartLayoutEngine.makePlan(project:project,pageBoundsProvider:{cache.pageBounds(for:$0)},partID:project.parts[0].id,horizontalContentBoundsProvider:{band,rect in cache.horizontalContentBounds(for:band,sourceRect:rect,rectification:nil)})
   let result=try PartPDFExporter.renderResult(for:project.parts[0].id,project:project,sourcePDFData:source)
   let key=String(format:"scale-%.2f-gap-%.0f",scale,gap)
   try result.data.write(to:root.appendingPathComponent(key+".pdf"))
   let expected=try reference(plan:plan,project:project,source:source)
   try expected.write(to:root.appendingPathComponent(key+"-full-crop-reference.pdf"))
   var pixelReports:[[String:Int]]=[]
   for page in plan.pages {
    let (actual,w,h)=pixels(result.data,index:page.index),(wanted,_,_)=pixels(expected,index:page.index)
    var changed=0,maximum=0,dark=0
    for offset in stride(from:0,to:actual.count,by:4) {
     let delta=(0..<3).map{abs(Int(actual[offset+$0])-Int(wanted[offset+$0]))}.max()!
     maximum=max(maximum,delta);if delta>2 {changed += 1};if wanted[offset]<180 {dark += 1}
    }
    pixelReports.append(["page":page.index+1,"pixels":w*h,"changedOver2":changed,"maxDelta":maximum,"darkReferencePixels":dark])
    try check(dark>100,"Pixel reference contains no ink")
    try check(changed==0,"Complete-source reference differs on \(key) page\(page.index+1): \(changed) pixels,max\(maximum)")
   }
   let placements=plan.pages.flatMap(\.placements)
   var entries:[[String:Any]]=[]
   let transforms=placements.map{$0.destinationRect.minX-$0.sourceRect.minX*$0.destinationRect.width/$0.sourceRect.width}
   for (index,p) in placements.enumerated() {
    let factor=p.destinationRect.width/p.sourceRect.width
    entries.append(["sourceRect":array(p.sourceRect),"destinationRect":array(p.destinationRect),"sourceX0OutputX":transforms[index],"renderScale":factor])
    try check(abs(p.sourceRect.minY-rect(project.bands[index],cache.pageBounds(for:2)!).minY)<1e-7 && abs(p.sourceRect.height-rect(project.bands[index],cache.pageBounds(for:2)!).height)<1e-7,"Vertical crop moved")
   }
   let realizedGaps=plan.pages.flatMap{page in zip(page.placements,page.placements.dropFirst()).map{$0.destinationRect.minY-$1.destinationRect.maxY}}
   if variant=="after" {
    try check(transforms.allSatisfy{abs($0-transforms[0])<1e-7},"Same source x does not transform identically")
    try check(abs(plan.scaleInfo.appliedScale-scale)<1e-7,"Requested scale clamped")
    try check(realizedGaps.allSatisfy{abs($0-gap)<1e-7},"Gap does not equal requested points")
    try check(!realizedGaps.isEmpty,"Spacing fixture has no same-page system pair")
   }
   try check(project==original,"Planning/rendering changed input project")
   try check(placements.map(\.bandID)==base.bands.map(\.id),"Part order changed")
   try check(abs(result.scaleInfo.appliedScale-plan.scaleInfo.appliedScale)<1e-7,"Export and preview scale differ")
   reports.append(["pixelChecks":pixelReports,"case":key,"requestedScale":scale,"gap":gap,"balancePages":true,"appliedScale":plan.scaleInfo.appliedScale,"safeScale":plan.scaleInfo.maximumSafeScale,"exceedsWidth":scale>plan.scaleInfo.maximumSafeScale+0.0001,"pageCount":plan.pages.count,"sameSourceXTransformSpread":(transforms.max() ?? 0)-(transforms.min() ?? 0),"realizedGaps":realizedGaps,"placements":entries])
  }
  try check(try Data(contentsOf:package.appendingPathComponent("source.pdf"))==source,"Source file changed")
  try check(try Data(contentsOf:package.appendingPathComponent("project.json"))==projectData,"Project file changed")
  let data=try JSONSerialization.data(withJSONObject:["variant":variant,"checks":checks,"cases":reports],options:[.prettyPrinted,.sortedKeys])
  try data.write(to:root.appendingPathComponent("results.json"))
  print("\(variant): \(checks) checks passed")
 }
}
