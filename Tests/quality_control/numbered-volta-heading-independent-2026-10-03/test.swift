import Foundation
import CoreGraphics
@main enum Audit {
 static var results: [[String: Any]] = []
 static func check(_ value: Bool, _ name: String) { results.append(["name":name,"pass":value]) }
 static func main() throws {
  let staff = ScoreObservedStaff(StaffBandCandidate(id: 0, staffLineFractions: [0.2,0.205,0.21,0.215,0.22], topFraction:0.19,bottomFraction:0.23,confidence:1,warnings:[]))
  typealias Line=ScoreSharedHeadingDetector.TextLine
  func select(_ lines:[Line])->[ScoreSharedHeading] { ScoreSharedHeadingDetector.select(from:lines,anchor:staff,previousStaffBottom:0.12,imageSize:CGSize(width:1800,height:2600)) }
  let positives=["  2DA\u{00a0}VOLTA\trit.  ","IV. volta molto rallentando.","Prima volta accel.","12th volta poco ritard.","3º volta rit."]
  for t in positives {
   let line=Line(text:t,bounds:CGRect(x:0.2,y:0.172,width:0.28,height:0.018),confidence:1)
   let r=select([line]);check(r.count==1,"Accepted complete conditional tempo: \(t)")
   check(r.first?.recognizedText==t,"Original OCR/source string preserved: \(t)")
  }
  for t in ["2da volta rit. pizz.","2da volta rit. Violin II","2da volta rit. 3","-2da volta rit.","02da volta rit.","IIV volta rit.","2da volta ritornello","2da volta cresc.","2da volta subito p","2da volta rit. e poi","see 2da volta rit.","2da volta poco","volta molto rall."] {
   check(!ScoreSharedHeadingDetector.isHeading(t),"Reject unsupported or incomplete phrase: \(t)")
  }
  var ordinal=Line(text:"2da",bounds:CGRect(x:0.30,y:0.174,width:0.03,height:0.016),confidence:1)
  var tempo=Line(text:"volta rit.",bounds:CGRect(x:0.336,y:0.174,width:0.11,height:0.016),confidence:1)
  check(select([tempo,ordinal]).count==1,"OCR input order does not lose adjacent ordinal")
  tempo.bounds.origin.x=0.6;check(select([ordinal,tempo]).isEmpty,"Distant ordinal does not manufacture a phrase")
  tempo.bounds.origin.x=0.336;tempo.bounds.origin.y=0.152;check(select([ordinal,tempo]).isEmpty,"Different text rows do not combine")
  tempo.bounds.origin.y=0.174;ordinal.confidence=Float.nan;check(select([ordinal,tempo]).isEmpty,"NaN ordinal confidence rejected")
  ordinal.confidence=1;ordinal.bounds.origin.y=0.205;tempo.bounds.origin.y=0.205;check(select([ordinal,tempo]).isEmpty,"Staff-local conditional text rejected")
  ordinal.bounds.origin.y=0.13;tempo.bounds.origin.y=0.13;check(select([ordinal,tempo]).isEmpty,"Previous-system text rejected")
  let profile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"solo",name:"Solo",staffCount:1)],cropMode:"compact")
  let page=ScorePageAnalysis(pageIndex:0,pageWidth:600,pageHeight:800,imageWidth:100,imageHeight:100,staves:[staff],warnings:[])
  let context=CGContext(data:nil,width:100,height:100,bitsPerComponent:8,bytesPerRow:400,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  var observed=false
  let cancelled=ScoreSharedHeadingDetector.detect(in:context.makeImage()!,page:page,profile:profile,observedText:{_,_ in observed=true},isCancelled:{true})
  check(cancelled.isEmpty && !observed,"Pre-cancelled detection never reaches OCR callback")
  let report:[String:Any]=["checks":results.count,"passed":results.filter{($0["pass"]as?Bool)==true}.count,"rows":results,"scope":"Independent selector/grammar checks and pre-cancellation; no Vision recognition or source extraction run"]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
  print("\(results.filter{($0["pass"]as?Bool)==true}.count)/\(results.count) independent controls pass")
  if results.contains(where:{($0["pass"]as?Bool)==false}) { exit(1) }
 }
}
