import Foundation
import CoreGraphics
import ImageIO
@main enum Trace {
 static var page = 0
 static func isTarget(_ index:Int,_ left:Int)->Bool { (page == 31 && index == 0 && left > 1600) || (page == 24 && index == 6 && left > 1600) || (page == 28 && index == 0 && left > 200 && left < 300) }
 static let out=URL(fileURLWithPath:".build/p31-spine-provenance-2026-10-03")
 struct DataFile:Decodable {var pages:[ScorePageAnalysis]}
 static func emit(_ event:String,_ fields:[String:Any]) { let d=try! JSONSerialization.data(withJSONObject:fields.merging(["event":event,"page":page]){a,_ in a},options:[.sortedKeys]);print(String(data:d,encoding:.utf8)!);fflush(stdout) }
 static func saveMask(_ mask:[Bool],width:Int,height:Int,phase:String) {var d=Data("P5\n\(width) \(height)\n255\n".utf8);d.append(contentsOf:mask.map{$0 ? UInt8(0):UInt8(255)});try! d.write(to:out.appendingPathComponent("p\(page)-\(phase).pgm"))}
 static func main()throws {
  let root=URL(fileURLWithPath:".build/ownership-alternatives-2026-10-03")
  let base=try JSONDecoder().decode(DataFile.self,from:Data(contentsOf:root.appendingPathComponent("actual.json")))
  var rows:[[String:Any]]=[]
  for pn in [24,28,31] {
   page=pn;let p=base.pages[pn-1]
   let src=CGImageSourceCreateWithURL(root.appendingPathComponent("rasters/page-\(pn).png") as CFURL,nil)!,image=CGImageSourceCreateImageAtIndex(src,0,nil)!
   let candidates=p.staves.map{StaffBandCandidate(id:$0.id,staffLineFractions:$0.staffLineFractions,topFraction:$0.topFraction,bottomFraction:$0.bottomFraction,confidence:$0.confidence,warnings:$0.warnings)}
   let result=ProbeNativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:p.analysisSkewDegrees)!
   let unchanged=NativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:p.analysisSkewDegrees)!
   let signatures:([ScoreInkComponent])->[String] = { $0.map {"\($0.bounds)|\($0.staffIDs)|\($0.isOwnershipAlternative == true)"}.sorted() }
   precondition(signatures(result)==signatures(unchanged),"Logging changed result")
   precondition(signatures(result)==signatures(p.inkComponents ?? []),"Frozen baseline differs")
   rows.append(["physicalPage":pn,"components":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result)),"loggingOnly":true,"matchesFrozen":true])
   emit("result",["components":result.count,"loggingOnly":true,"matchesFrozen":true])
  }
  try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("components.json"))
 }
}
