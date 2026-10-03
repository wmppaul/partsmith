import Foundation
import PDFKit
import ImageIO
struct Case: Decodable { var id:String;var scoreID:String;var sourcePath:String;var pages:[ScorePageAnalysis];var profile:ScoreExtractionProfile;var overrides:[ScorePageOverride];var unavailableImagePages:[Int]?;var cancelImmediately:Bool? }
@main struct Run {
 static func main() throws {
  let args=CommandLine.arguments;let cases=try JSONDecoder().decode([Case].self,from:Data(contentsOf:URL(fileURLWithPath:args[1])))
  var cache:[String:CGImage]=[:];var outputs:[[String:Any]]=[]
  for c in cases {
   let start=Date();let pdf=c.sourcePath.hasSuffix(".pdf") ? PDFDocument(url:URL(fileURLWithPath:c.sourcePath)):nil
   let result=ScoreSystemTemplateMatcher.suggest(pages:c.pages,profile:c.profile,reviewedOverrides:c.overrides,imageForPage:{i in
    if c.unavailableImagePages?.contains(i)==true{return nil};let key=c.sourcePath+"#\(i)";if let im=cache[key]{return im}
    let im:CGImage?;if let pdf {im=pdf.page(at:i).flatMap {NativeScorePageAnalyzer.render($0)}}else{im=CGImageSourceCreateWithURL(URL(fileURLWithPath:c.sourcePath) as CFURL,nil).flatMap{CGImageSourceCreateImageAtIndex($0,0,nil)}}
    if let im{cache[key]=im};return im
   },isCancelled:{c.cancelImmediately==true})
   let output:[String:Any]=["id":c.id,"cancelled":result.cancelled,"elapsedSeconds":Date().timeIntervalSince(start),"suggestions":result.suggestions.map{s in ["pageIndex":s.pageIndex,"systemIndex":s.systemIndex,"candidateIDs":s.candidateIDs,"presentPartIDs":s.presentPartIDs.sorted(),"confidence":s.confidence.rawValue,"startBarNumber":s.startBarNumber as Any? ?? NSNull(),"barCount":s.barCount as Any? ?? NSNull(),"requiresMeasureCount":s.requiresMeasureCount,"templatePageIndex":s.templatePageIndex,"templateSystemIndex":s.templateSystemIndex] as [String:Any]},"diagnostics":result.diagnostics.map{["pageIndex":$0.pageIndex,"message":$0.message]}]
   outputs.append(output);print(c.id,result.suggestions.count,result.cancelled);fflush(stdout)
   try JSONSerialization.data(withJSONObject:outputs,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args[2]))
  }
 }
}
