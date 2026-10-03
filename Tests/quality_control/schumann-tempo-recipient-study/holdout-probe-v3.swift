import Foundation
import PDFKit
@main enum HoldoutProbe {
 struct Config:Codable{var name:String;var inventory:String;var profile:String;var reviewSource:String}
 struct Inventory:Codable{var pages:[ScorePageAnalysis]}
 struct Observation:Codable{var anchor:Int;var text:String;var bounds:[Double];var confidence:Float}
 struct Result:Codable{var page:Int;var baseline:[ScoreSharedHeading];var candidate:[ScoreSharedHeading];var baselinePlan:ScoreExtractionPlan;var candidatePlan:ScoreExtractionPlan;var candidateOCR:[Observation];var failures:[String]}
 static func main()throws{
  setbuf(stdout,nil)
  let w=URL(fileURLWithPath:".build/schumann-directions");let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
  let configs=try JSONDecoder().decode([Config].self,from:Data(contentsOf:w.appendingPathComponent("holdout-inputs.json")))
  for config in configs {
   let inv=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:URL(fileURLWithPath:config.inventory)))
   let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:config.profile)))
   let pdf=PDFDocument(url:URL(fileURLWithPath:config.reviewSource))!;var result:[Result]=[]
   for page in inv.pages {
    try autoreleasepool {
     let image=NativeScorePageAnalyzer.render(pdf.page(at:page.pageIndex)!,maximumWidth:2200,maximumHeight:3200)!
     var clean=page;clean.sharedHeadings=nil;clean.sharedNavigation=nil
     var errors:[String]=[],observations:[Observation]=[]
     let a=ScoreSharedHeadingDetector.detect(in:image,page:clean,profile:profile,observedFailure:{id,error in errors.append("baseline \(id): \(error)")})
     let b=SchumannHeadingCandidate.detect(in:image,page:clean,profile:profile,observedText:{id,rows in observations += rows.map{Observation(anchor:id,text:$0.text,bounds:[$0.bounds.minX,$0.bounds.minY,$0.bounds.maxX,$0.bounds.maxY],confidence:$0.confidence)}},observedFailure:{id,error in errors.append("candidate \(id): \(error)")})
     var aa=clean,bb=clean;aa.sharedHeadings=a;bb.sharedHeadings=b
     result.append(Result(page:page.pageIndex+1,baseline:a,candidate:b,baselinePlan:ScoreExtractionPlanner.plan(pages:[aa],profile:profile),candidatePlan:ScoreExtractionPlanner.plan(pages:[bb],profile:profile),candidateOCR:observations,failures:errors))
     try e.encode(result).write(to:w.appendingPathComponent("holdout-v3-\(config.name).json"))
     print("\(config.name) page \(page.pageIndex+1): baseline \(a.count) candidate \(b.count), failures \(errors.count)")
    }
   }
   print("FINISHED \(config.name) \(result.count) pages")
  }
 }
}
