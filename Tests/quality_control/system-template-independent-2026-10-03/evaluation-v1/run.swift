import Foundation
import PDFKit
struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
struct Job: Decodable { var id: String; var sourcePath: String }
@main struct Run {
 static func main() throws {
  let base=".build/system-template-matcher-2026-10-03"
  let jobs=try JSONDecoder().decode([Job].self,from:Data(contentsOf:URL(fileURLWithPath:base+"/jobs.json")))
  for job in jobs {
   let dir=base+"/"+job.id
   func read<T:Decodable>(_ name:String,_ type:T.Type)throws->T{try JSONDecoder().decode(type,from:Data(contentsOf:URL(fileURLWithPath:dir+"/"+name+".json")))}
   let inventory=try read("inventory",Inventory.self),profile=try read("profile",ScoreExtractionProfile.self),templates=try read("templates",[ScorePageOverride].self)
   let pdf=PDFDocument(url:URL(fileURLWithPath:job.sourcePath))!
   let result=ScoreSystemTemplateMatcher.suggest(pages:inventory.pages,profile:profile,reviewedOverrides:templates,imageForPage:{ index in pdf.page(at:index).flatMap{NativeScorePageAnalyzer.render($0)} })
   let output:[String:Any] = ["suggestions":result.suggestions.map{s in ["pageIndex":s.pageIndex,"systemIndex":s.systemIndex,"candidateIDs":s.candidateIDs,"presentPartIDs":s.presentPartIDs.sorted(),"templatePageIndex":s.templatePageIndex,"templateSystemIndex":s.templateSystemIndex,"confidence":s.confidence.rawValue,"reasons":s.reasons,"sourceBounds":s.sourceBounds,"requiresMeasureCount":s.requiresMeasureCount] as [String:Any]},"diagnostics":result.diagnostics.map{["pageIndex":$0.pageIndex,"message":$0.message]},"cancelled":result.cancelled]
   try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:dir+"/result.json"))
   print(job.id,result.suggestions.count,result.diagnostics)
  }
 }
}
