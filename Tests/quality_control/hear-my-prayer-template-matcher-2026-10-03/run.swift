import Foundation
import PDFKit
struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
@main struct Run {
 static func main() throws {
  let base = ".build/hear-my-prayer-matcher-2026-10-03"
  let decoder = JSONDecoder()
  let inventory = try decoder.decode(Inventory.self, from: Data(contentsOf: URL(fileURLWithPath: ".build/envelope-compatibility-corpus-2026-10-03/baseline/lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163.json")))
  let profile = try decoder.decode(ScoreExtractionProfile.self, from: Data(contentsOf: URL(fileURLWithPath: "Tests/quality_control/profiles/lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163.json")))
  let seeds = try decoder.decode([ScorePageOverride].self, from: Data(contentsOf: URL(fileURLWithPath: base + "/two-seeds.json")))
  let pdf = PDFDocument(url: URL(fileURLWithPath: "sample_scores/lightly_skewed/08_mendelssohn_hear_my_prayer_woo15_imslp_40163.pdf"))!
  let result = ScoreSystemTemplateMatcher.suggest(pages:inventory.pages, profile:profile, reviewedOverrides:seeds,
   imageForPage:{ index in pdf.page(at:index).flatMap{NativeScorePageAnalyzer.render($0)} })
  let output:[String:Any] = ["suggestions":result.suggestions.map{s in ["pageIndex":s.pageIndex,"systemIndex":s.systemIndex,"candidateIDs":s.candidateIDs,"presentPartIDs":s.presentPartIDs.sorted(),"templatePageIndex":s.templatePageIndex,"templateSystemIndex":s.templateSystemIndex,"confidence":s.confidence.rawValue,"reasons":s.reasons,"sourceBounds":s.sourceBounds,"requiresMeasureCount":s.requiresMeasureCount,"countWasInferred": s.barCount != nil] as [String:Any]},"diagnostics":result.diagnostics.map{["pageIndex":$0.pageIndex,"message":$0.message]},"cancelled":result.cancelled]
  try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:base+"/result.json"))
  print("suggestions",result.suggestions.count,"diagnostics",result.diagnostics)
 }
}
