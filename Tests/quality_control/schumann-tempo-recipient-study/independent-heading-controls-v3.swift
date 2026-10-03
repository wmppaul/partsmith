import CoreGraphics
import Foundation

@main enum IndependentInkTests {
 static var rows: [[String:Any]] = []
 static func record(_ name:String,_ okay:Bool,_ detail:String="") { rows.append(["name":name,"passed":okay,"detail":detail]) }
 static func image(_ pixels:[UInt8],width:Int=100,height:Int=100,rgba:Bool=false) -> CGImage {
  CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:rgba ? 32 : 8,bytesPerRow:width*(rgba ? 4 : 1),space:rgba ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:rgba ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.none.rawValue),provider:CGDataProvider(data:Data(pixels) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
 }
 static func main() throws {
  typealias D=SchumannHeadingCandidate
  var p=[UInt8](repeating:255,count:10000);p[21*100+17]=0
  let b=D.measuredInkBounds(in:image(p),bounds:[0.1,0.1,0.5,0.5])!
  record("asymmetric top-down raster axes",b==[0.16,0.20,0.19,0.23],"\(b)")
  p[12*100+31]=254
  let faint=D.measuredInkBounds(in:image(p),bounds:[0.1,0.1,0.5,0.5])!
  record("detached254 gray dot outside black text retained",faint[1]<=0.12 && faint[2]>=0.32,"\(faint)")
  var rgba=[UInt8](repeating:0,count:40000)
  for k in 0..<10000 { rgba[k*4]=255;rgba[k*4+1]=255;rgba[k*4+2]=255;rgba[k*4+3]=255 }
  for (x,y,gray,alpha) in [(17,21,40,255),(31,12,0,0),(25,15,0,1)] {
   let index=(y*100+x)*4;rgba[index]=UInt8(gray);rgba[index+1]=UInt8(gray);rgba[index+2]=UInt8(gray);rgba[index+3]=UInt8(alpha)
  }
  let alpha=D.measuredInkBounds(in:image(rgba,rgba:true),bounds:[0.1,0.1,0.5,0.5])!
  record("transparent black is white; alpha1 ink retained",alpha[1]<=0.15 && alpha[1]>0.12 && alpha[2]>=0.26,"\(alpha)")
  let entirelyWhite=D.measuredInkBounds(in:image([UInt8](repeating:255,count:10000)),bounds:[0,0,1,1])
  record("all-white region has no suppression evidence",entirelyWhite==nil)
  for (i,bounds) in [[Double.nan,0,1,1],[-0.1,0,1,1],[0,0,2,1],[0,0,0,1],[0,0,1],[0,0,Double.infinity,1]].enumerated() {
   record("malformed measurement rectangle\(i)",D.measuredInkBounds(in:image(p),bounds:bounds)==nil)
  }
  func staff(_ id:Int,_ top:Double)->ScoreObservedStaff {
   ScoreObservedStaff(StaffBandCandidate(id:id,staffLineFractions:(0..<5).map {top+Double($0)*0.005},topFraction:top-0.01,bottomFraction:top+0.03,confidence:1,warnings:[]))
  }
  let profile=ScoreExtractionProfile(parts:[.init(id:"a",name:"A",staffCount:1),.init(id:"b",name:"B",staffCount:1)],cropMode:"compact")
  var page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:1800,imageHeight:2400,staves:[staff(0,0.2),staff(1,0.3)],warnings:[])
  let baseline=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
  let owner=baseline.bands[0],recipient=baseline.bands[1]
  var h=ScoreSharedHeading(anchorStaffID:0,bounds:[0.2,owner.topFraction-0.01,0.4,owner.topFraction+0.02],recognizedText:"Andante")
  h.inkBounds=[0.21,recipient.topFraction+0.001,0.39,recipient.topFraction+0.01]
  page.sharedHeadings=[h]
  var result=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
  record("valid-but-disjoint metadata cannot suppress lower copy",result.bands[1].sourceMarkings.count==1,"count \(result.bands[1].sourceMarkings.count)")
  h.inkBounds=[0.21,owner.topFraction+0.001,0.39,owner.topFraction+0.01];page.sharedHeadings=[h]
  result=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
  record("valid same-source ink suppresses only owner copy",result.bands[0].sourceMarkings.isEmpty && result.bands[1].sourceMarkings.count==1)
  var raw=try JSONSerialization.jsonObject(with:JSONEncoder().encode(h)) as! [String:Any];raw.removeValue(forKey:"inkBounds")
  let legacy=try JSONDecoder().decode(ScoreSharedHeading.self,from:JSONSerialization.data(withJSONObject:raw));page.sharedHeadings=[legacy]
  result=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
  record("legacy heading lacks ink evidence and keeps padded copies",legacy.inkBounds==nil && result.bands.allSatisfy { $0.sourceMarkings.count==1 })
  record("all tested main geometry remains unchanged",zip(baseline.bands,result.bands).allSatisfy {$0.topFraction==$1.topFraction && $0.bottomFraction==$1.bottomFraction && $0.leftFraction==$1.leftFraction && $0.rightFraction==$1.rightFraction})
  let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]);print(String(decoding:data,as:UTF8.self))
  if rows.contains(where: { $0["passed"] as? Bool != true }) {
   throw NSError(domain: "IndependentHeadingInkReview", code: 1)
  }
 }
}
