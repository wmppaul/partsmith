import Foundation
import ImageIO
import CoreGraphics
@main enum Trace {
 static var page=0
 static let out=URL(fileURLWithPath:".build/residual9-boundary-2026-10-03/agent-probe")
 struct DataFile:Decodable {var pages:[ScorePageAnalysis]}
 static func watched(index:Int,column:Int,width:Int)->Bool {index == (page == 24 ? 6:0)}
 static func emit(_ event:String,_ fields:[String:Any]) {let data=try! JSONSerialization.data(withJSONObject:fields.merging(["event":event,"page":page]){old,_ in old},options:[.sortedKeys]);print(String(data:data,encoding:.utf8)!);fflush(stdout)}
 static func saveMask(_ mask:[Bool],width:Int,height:Int,phase:String="native") {var data=Data("P5\n\(width) \(height)\n255\n".utf8);data.append(contentsOf:mask.map{$0 ? UInt8(0):UInt8(255)});try! data.write(to:out.appendingPathComponent("page-\(page)-\(phase)-mask.pgm"))}
 static func main()throws {
  let root=URL(fileURLWithPath:".build/residual9-endpoint-ownership-2026-10-03")
  let base=try JSONDecoder().decode(DataFile.self,from:Data(contentsOf:root.appendingPathComponent("baseline-actual.json")))
  for pn in [24,28,29,31,35] {
   page=pn;let p=base.pages[pn-1]
   let src=CGImageSourceCreateWithURL(root.appendingPathComponent("rasters/page-\(pn).png") as CFURL,nil)!,image=CGImageSourceCreateImageAtIndex(src,0,nil)!
   let candidates=p.staves.map { StaffBandCandidate(id:$0.id,staffLineFractions:$0.staffLineFractions,topFraction:$0.topFraction,bottomFraction:$0.bottomFraction,confidence:$0.confidence,warnings:$0.warnings) }
   let result=NativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:p.analysisSkewDegrees)!
   let unchanged=UnmodifiedNativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:p.analysisSkewDegrees)!
   let signatures:([ScoreInkComponent])->[String] = { $0.map { "\($0.bounds)|\($0.staffIDs)" }.sorted() }
   let same=signatures(result)==signatures(p.inkComponents ?? [])
   let loggingOnly=signatures(result)==signatures(unchanged)
   emit("result",["componentCount":result.count,"exactPriorNativeComponents":same,"loggingOnlyMatchesUnmodifiedAnalyzer":loggingOnly,"connectedTargetBoxes":result.filter{$0.staffIDs.contains(pn == 24 ? 6:0) && $0.staffIDs.contains(pn == 24 ? 7:1)}.map{$0.bounds}])
   precondition(loggingOnly,"Logging probe changed component result")
  }
 }
}
