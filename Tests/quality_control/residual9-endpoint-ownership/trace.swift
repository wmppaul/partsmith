import Foundation
import ImageIO
import CoreGraphics
@main enum Trace {
 static var page=0
 struct DataFile:Decodable {var pages:[ScorePageAnalysis]}
 static func main()throws {
  let root=URL(fileURLWithPath:".build/residual9-endpoint-ownership-2026-10-03")
  let base=try JSONDecoder().decode(DataFile.self,from:Data(contentsOf:root.appendingPathComponent("baseline-actual.json")))
  for pn in [5,9,24,25,28,29,31,35] {
   page=pn;let p=base.pages[pn-1]
   let src=CGImageSourceCreateWithURL(root.appendingPathComponent("rasters/page-\(pn).png") as CFURL,nil)!
   let image=CGImageSourceCreateImageAtIndex(src,0,nil)!
   let candidates=p.staves.map { StaffBandCandidate(id:$0.id,staffLineFractions:$0.staffLineFractions,topFraction:$0.topFraction,bottomFraction:$0.bottomFraction,confidence:$0.confidence,warnings:$0.warnings) }
   let result=NativeScorePageAnalyzer.notationComponents(image:image,candidates:candidates,skewDegrees:p.analysisSkewDegrees)!
   print("DONE page \(pn), components \(result.count)")
  }
 }
}
