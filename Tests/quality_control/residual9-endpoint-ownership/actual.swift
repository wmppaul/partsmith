import Foundation
import CoreGraphics
import PDFKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
@main struct Actual {
 struct Inventory: Codable { var source:String;var sourceSHA256:String;var pages:[ScorePageAnalysis];var rectifications:[PageRectification] }
 struct Output:Codable {var source:String;var sourceSHA256:String;var rectifications:[PageRectification];var pages:[ScorePageAnalysis];var plan:ScoreExtractionPlan}
 static func main()throws {
  let a=CommandLine.arguments
  let base=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:a[1])))
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:a[2])))
  let data=try Data(contentsOf:URL(fileURLWithPath:base.source));precondition(SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()==base.sourceSHA256)
  let pdf=PDFDocument(data:data)!,cache=SourcePageRenderCache(pdfDocument:pdf,rasterScale:2.5)
  var pages:[ScorePageAnalysis]=[]
  for i in 0..<pdf.pageCount {
   try autoreleasepool {
    let p=pdf.page(at:i)!,b=p.bounds(for:.mediaBox)
    let correction=base.rectifications.first{$0.pageIndex==i}
    let image=correction == nil ? NativeScorePageAnalyzer.render(p)!:cache.rectifiedDisplayImage(for:i,rectification:correction)!
    let analysis=NativeScorePageAnalyzer.analyze(pageIndex:i,image:image,pageWidth:b.width,pageHeight:b.height)
    pages.append(analysis)
    if [4,8,23,24,27,28,30,34].contains(i) {
      let dir=URL(fileURLWithPath:a[3]).deletingLastPathComponent().appendingPathComponent("rasters")
      try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
      let url=dir.appendingPathComponent("page-\(i+1).png")
      if !FileManager.default.fileExists(atPath:url.path) {
       let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
       CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
      }
    }
    print("page \(i+1)/\(pdf.pageCount) staves \(analysis.staves.count)");fflush(stdout)
   }
  }
  let result=Output(source:base.source,sourceSHA256:base.sourceSHA256,rectifications:base.rectifications,pages:pages,plan:ScoreExtractionPlanner.plan(pages:pages,profile:profile))
  let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];try e.encode(result).write(to:URL(fileURLWithPath:a[3]))
 }
}
