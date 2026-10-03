import Foundation
import CoreGraphics
import ImageIO
@main enum Replay {
 struct Inventory: Codable { var pages:[ScorePageAnalysis];var plan:ScoreExtractionPlan }
 struct Output:Codable {var pages:[ScorePageAnalysis];var plan:ScoreExtractionPlan}
 static func main()throws {
  let a=CommandLine.arguments
  let base=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:".build/ownership-alternatives-2026-10-03/actual.json")))
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:"Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json")))
  var pages:[ScorePageAnalysis]=[]
  for pn in [28,31] {
   let old=base.pages[pn-1]
   let url=URL(fileURLWithPath:".build/ownership-alternatives-2026-10-03/rasters/page-\(pn).png")
   let src=CGImageSourceCreateWithURL(url as CFURL,nil)!,image=CGImageSourceCreateImageAtIndex(src,0,nil)!
   let p=NativeScorePageAnalyzer.analyze(pageIndex:pn-1,image:image,pageWidth:old.pageWidth,pageHeight:old.pageHeight)
   precondition(p.staves==old.staves,"Staff geometry drift")
   pages.append(p);print("native page",pn,"components",p.inkComponents?.count ?? -1)
  }
  let out=Output(pages:pages,plan:ScoreExtractionPlanner.plan(pages:pages,profile:profile))
  let e=JSONEncoder();e.outputFormatting=[.sortedKeys,.prettyPrinted];try e.encode(out).write(to:URL(fileURLWithPath:a[1]))
 }
}
