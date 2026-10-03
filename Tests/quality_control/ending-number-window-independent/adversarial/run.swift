import Foundation
import CoreGraphics
import ImageIO
@main enum Controls {
 struct Case:Decodable { var id:String; var image:String }
 struct Record:Encodable { var id:String; var errors:[String]; var result:ScoreSharedEndingDetector.PageResult; var pairs:[ScoreSharedEndingDetector.Pair] }
 static func main() throws {
  let cases=try JSONDecoder().decode([Case].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
  let candidate=StaffBandCandidate(id:0,staffLineFractions:[200,212,224,236,248].map{Double($0)/300},topFraction:0.5,bottomFraction:0.9,confidence:1,warnings:[])
  let page=ScorePageAnalysis(pageIndex:0,pageWidth:620,pageHeight:300,imageWidth:620,imageHeight:300,staves:[ScoreObservedStaff(candidate)],warnings:[])
  let profile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"one",name:"One",staffCount:1)])
  var records:[Record]=[]
  for c in cases {
   let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:c.image) as CFURL,nil)!,im=CGImageSourceCreateImageAtIndex(src,0,nil)!
   var errors:[String]=[]
   let result=ScoreSharedEndingDetector.analyze(in:im,page:page,profile:profile,observedFailure:{errors.append($0.localizedDescription)})
   records.append(.init(id:c.id,errors:errors,result:result,pairs:ScoreSharedEndingDetector.pairs(in:[result])))
  }
  let enc=JSONEncoder();enc.outputFormatting=[.prettyPrinted,.sortedKeys]
  try enc.encode(records).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
 }
}
