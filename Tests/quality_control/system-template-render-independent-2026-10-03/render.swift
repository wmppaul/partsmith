import Foundation
import PDFKit
import ImageIO
@main enum RenderReview {
 struct Inventory:Decodable {var source:String;var sourceSHA256:String;var rectifications:[PageRectification];var pages:[ScorePageAnalysis]}
 static func main() throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  let inv=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:".build/ownership-alternatives-output-2026-10-03/brahms-inventory.json")))
  let pdf=PDFDocument(url:URL(fileURLWithPath:inv.source))!
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:"Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json")))
  var records:[[String:Any]]=[]
  for pageNumber in [2,7,17,19,23,28,34,38,39] {
   let index=pageNumber-1,analysis=inv.pages.first{$0.pageIndex==index}!,rectification=inv.rectifications.first{$0.pageIndex==index}!
   let old=SourcePageRenderCache(pdfDocument:pdf).rectifiedDisplayImage(for:index,rectification:rectification)!
   let fixed=SourcePageRenderCache(pdfDocument:pdf,rasterScale:2.5).rectifiedDisplayImage(for:index,rectification:rectification)!
   if pageNumber == 7 {
    let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent("p07-corrected-native.png") as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination,fixed,nil); precondition(CGImageDestinationFinalize(destination))
   }
   precondition(fixed.width == analysis.imageWidth && fixed.height == analysis.imageHeight)
   let groups=analysis.staves.count/4
   guard groups>0 else{continue}
   let seedIDs=Array(analysis.staves.sorted{$0.staffLineFractions[0]<$1.staffLineFractions[0]}.prefix(4).map(\.id))
   let seed=try ScoreSystemAssignment.assign(page:analysis,profile:profile,pagePlan:nil,existingOverride:nil,systemIndex:0,candidateIDs:seedIDs,presentPartIDs:Set(profile.parts.map(\.id)),startBarNumber:nil,barCount:nil)
   let before=ScoreSystemTemplateMatcher.suggest(pages:[analysis],profile:profile,reviewedOverrides:[seed],imageForPage:{_ in old})
   let after=ScoreSystemTemplateMatcher.suggest(pages:[analysis],profile:profile,reviewedOverrides:[seed],imageForPage:{_ in fixed})
   if pageNumber == 7 { precondition(after.suggestions.map(\.candidateIDs) == [[4,5,6,7],[8,9,10,11],[12,13,14,15]]) }
   precondition(before.suggestions.isEmpty)
   records.append(["page":pageNumber,"analysisSize":[analysis.imageWidth,analysis.imageHeight],"beforeSize":[old.width,old.height],"afterSize":[fixed.width,fixed.height],"staves":analysis.staves.count,"beforeSuggestions":before.suggestions.count,"afterSuggestions":after.suggestions.map{["pageIndex":$0.pageIndex,"systemIndex":$0.systemIndex,"candidateIDs":$0.candidateIDs,"templateSystemIndex":$0.templateSystemIndex,"bounds":$0.sourceBounds,"confidence":$0.confidence.rawValue] as [String:Any]},"beforeDiagnostics":before.diagnostics.map(\.message),"afterDiagnostics":after.diagnostics.map(\.message)])
   print("p\(pageNumber) old\(old.width)x\(old.height) fixed\(fixed.width)x\(fixed.height) expected\(analysis.imageWidth)x\(analysis.imageHeight); suggestions \(before.suggestions.count)→\(after.suggestions.count)");fflush(stdout)
  }
  try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("render-results.json"))
 }
}
