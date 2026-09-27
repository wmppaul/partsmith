import CoreGraphics
import Foundation
import PDFKit
import CryptoKit
struct Inventory:Decodable {var pages:[ScorePageAnalysis]}
struct Report:Codable {var source:String;var sourceSHA256:String;var inventory:String;var pages:[ScoreSharedEndingDetector.PageResult];var pairs:[ScoreSharedEndingDetector.Pair]}
@main enum Runner {
 static func main() throws {
  let args=CommandLine.arguments,source=args[1],inventory=args[2],profilePath=args[3],out=args[4]
  let data=try Data(contentsOf:URL(fileURLWithPath:source));guard let pdf=PDFDocument(data:data) else{throw NSError(domain:"PDF",code:1)}
  let inv=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:inventory)))
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:profilePath)))
  var pages:[ScoreSharedEndingDetector.PageResult]=[]
  for p in inv.pages {
   let result:ScoreSharedEndingDetector.PageResult=try autoreleasepool {
    guard let pg=pdf.page(at:p.pageIndex) else{throw NSError(domain:"Page",code:1)}
    let b=pg.bounds(for:.mediaBox),scale=min(2400/b.width,3500/b.height),w=Int((b.width*scale).rounded()),h=Int((b.height*scale).rounded())
    guard let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw NSError(domain:"Raster",code:1)}
    c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:w,height:h));c.scaleBy(x:CGFloat(w)/b.width,y:CGFloat(h)/b.height);c.translateBy(x:-b.minX,y:-b.minY);pg.draw(with:.mediaBox,to:c)
    guard let image=c.makeImage() else{throw NSError(domain:"Image",code:1)}
    var failures:[Error]=[]
    let result=ScoreSharedEndingDetector.analyze(in:image,page:p,profile:profile,observedFailure:{failures.append($0)})
    if let error=failures.first{throw error};return result
   }
   pages.append(result);print("Page \(p.pageIndex+1): \(result.geometryProposalCount) geometry, \(result.mergedProposalCount) merged, \(result.candidates.count) numeric, ownership \(result.ownershipVerified)");fflush(stdout)
  }
  let result=Report(source:source,sourceSHA256:SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined(),inventory:inventory,pages:pages,pairs:ScoreSharedEndingDetector.pairs(in:pages))
  let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes];try enc.encode(result).write(to:URL(fileURLWithPath:out))
  print("Pairs \(result.pairs.count)");for p in result.pairs{print("\(p.first.pageIndex+1)s\(p.first.systemIndex+1) -> \(p.second.pageIndex+1)s\(p.second.systemIndex+1): \(p.first.copyBounds) / \(p.second.copyBounds)")}
 }
}
