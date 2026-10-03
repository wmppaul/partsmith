import AppKit
import PDFKit
import Foundation
@main enum VerifyOutput {
 struct Mark:Decodable {var sourceRect:[Double];var destinationRect:[Double]}
 struct Placement:Decodable {var id:String;var sourcePage:Int;var outputPage:Int;var sourceRect:[Double];var destinationRect:[Double];var sourceMarkings:[Mark]}
 struct Part:Decodable {var id:String;var file:String;var placements:[Placement]}
 struct Manifest:Decodable {var source:String;var parts:[Part]}
 struct Item:Codable {var part:String;var page:Int;var band:String;var kind:String;var comparedPixels:Int;var differentPixels:Int;var maxChannelDelta:Int}
 static func rect(_ a:[Double],height:Double)->CGRect{CGRect(x:a[0],y:height-a[3],width:a[2]-a[0],height:a[3]-a[1])}
 static func raster(_ page:PDFPage)->NSBitmapImageRep {
  let b=page.bounds(for:.mediaBox);let c=CGContext(data:nil,width:Int(b.width*2),height:Int(b.height*2),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:b.width*2,height:b.height*2));c.scaleBy(x:2,y:2);c.drawPDFPage(page.pageRef!);return NSBitmapImageRep(cgImage:c.makeImage()!)
 }
 static func main() throws {
  let folder=URL(fileURLWithPath:CommandLine.arguments[1]);let decoder=JSONDecoder()
  let m=try decoder.decode(Manifest.self,from:Data(contentsOf:folder.appendingPathComponent("parts/manifest.json")))
  let original=try decoder.decode(Manifest.self,from:Data(contentsOf:URL(fileURLWithPath:".build/auto-qc/connector8-harmonic/corpus/lightly-skewed-05-schumann-frauenliebe-und-leben-op42-imslp-270922/parts/manifest.json")))
  let frozen=Dictionary(uniqueKeysWithValues:original.parts.flatMap(\.placements).map{($0.id,$0.sourceRect)})
  let source=PDFDocument(url:URL(fileURLWithPath:m.source))!;var records:[Item]=[]
  for part in m.parts {
   let actual=PDFDocument(url:folder.appendingPathComponent("parts/"+part.file))!
   for i in 0..<actual.pageCount {
    autoreleasepool {
     var bounds=actual.page(at:i)!.bounds(for:.mediaBox);let data=NSMutableData();let c=CGContext(consumer:CGDataConsumer(data:data)!,mediaBox:&bounds,nil)!;c.beginPDFPage(nil)
     let placements=part.placements.filter{$0.outputPage==i+1}
     for band in placements {
      precondition(frozen[band.id]==band.sourceRect,"Original intended-staff crop changed")
      let page=source.page(at:band.sourcePage-1)!;let h=page.bounds(for:.mediaBox).height
      // Independent reference uses original frozen musical crops, not proposed
      // recognition boundaries. Only new direction fragments use new metadata.
      let items=[Mark(sourceRect:frozen[band.id]!,destinationRect:band.destinationRect)]+band.sourceMarkings
      for item in items {
       let s=rect(item.sourceRect,height:h),d=rect(item.destinationRect,height:bounds.height)
       c.saveGState();c.clip(to:d);c.translateBy(x:d.minX-s.minX*d.width/s.width,y:d.minY-s.minY*d.height/s.height);c.scaleBy(x:d.width/s.width,y:d.height/s.height);c.drawPDFPage(page.pageRef!);c.restoreGState()
      }
     }
     c.endPDFPage();c.closePDF();let ref=PDFDocument(data:data as Data)!
     let a=raster(actual.page(at:i)!),b=raster(ref.page(at:0)!),ap=a.bitmapData!,bp=b.bitmapData!
     for band in placements { for (j,box) in ([band.destinationRect]+band.sourceMarkings.map(\.destinationRect)).enumerated() {
      // Compare every raster pixel touched by the placed source fragment. Page
      // headers/footers outside these areas are intentionally not compared.
      var n=0,different=0,maximum=0
      let x0=max(0,Int(floor(box[0]*2))),x1=min(a.pixelsWide,Int(ceil(box[2]*2)))
      let y0=max(0,Int(floor(box[1]*2))),y1=min(a.pixelsHigh,Int(ceil(box[3]*2)))
      for y in y0..<y1 {for x in x0..<x1 {
       let ia=y*a.bytesPerRow+x*a.samplesPerPixel,ib=y*b.bytesPerRow+x*b.samplesPerPixel
       let delta=(0..<3).map{abs(Int(ap[ia+$0])-Int(bp[ib+$0]))}.max()!;n+=1;if delta>0{different+=1};maximum=max(maximum,delta)
      }}
      records.append(Item(part:part.id,page:i+1,band:band.id,kind:j==0 ? "original-music":"new-direction-\(j)",comparedPixels:n,differentPixels:different,maxChannelDelta:maximum))
     }}
    }
   }
  }
  let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];try e.encode(records).write(to:folder.appendingPathComponent("actual-output-source-pixels.json"))
  print("\(records.count) fragments; \(records.filter{$0.kind=="original-music"}.count) original music crops; \(records.reduce(0){$0+$1.comparedPixels}) pixels; \(records.reduce(0){$0+$1.differentPixels}) different pixels; maximum \(records.map(\.maxChannelDelta).max() ?? 0)")
 }
}
