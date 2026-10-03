import Foundation
@main enum ReplayPlans {
 struct Case: Decodable {var id:String; var page:ScorePageAnalysis}
 struct Replay:Decodable {var id:String;var components:[ScoreInkComponent]}
 struct Result:Encodable {var id:String;var baseline:ScoreExtractionPlan;var candidate:ScoreExtractionPlan}
 static func main() throws {
  let a=CommandLine.arguments
  let cases=try JSONDecoder().decode([Case].self,from:Data(contentsOf:URL(fileURLWithPath:a[1])))
  let replay=try JSONDecoder().decode([Replay].self,from:Data(contentsOf:URL(fileURLWithPath:a[2])))
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:URL(fileURLWithPath:a[3])))
  let rows=Dictionary(uniqueKeysWithValues:replay.map{($0.id,$0.components)})
  let results=cases.map { item in
   var page=item.page;page.inkComponents=rows[item.id]!
   let p=item.id.hasPrefix("corrected-brahms93521:") ? profile : ScoreExtractionProfile(parts:page.staves.map{.init(id:"staff-\($0.id)",name:"Staff \($0.id)",staffCount:1)},cropMode:"compact")
   return Result(id:item.id,baseline:ScoreExtractionPlanner.plan(pages:[item.page],profile:p),candidate:ScoreExtractionPlanner.plan(pages:[page],profile:p))
  }
  let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys]
  try e.encode(results).write(to:URL(fileURLWithPath:a[4]))
 }
}
