import Foundation
import CoreGraphics
import ImageIO
struct Cases: Decodable { var cases:[Case] }
struct Case:Decodable { var id:String;var image:String;var globalBounds:[Double];var localBounds:[Double];var recognizedGlobalText:String;var recognizedLocalText:String;var expectEquivalent:Bool }
@main enum Check {
 static func main()throws {
  let url=URL(fileURLWithPath:"Tests/quality_control/heading-local-ownership-2026-10-03/matcher-fixtures/cases.json")
  let cases=try JSONDecoder().decode(Cases.self,from:Data(contentsOf:url)).cases
  var results:[[String:Any]]=[]
  for c in cases {
   let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:c.image) as CFURL,nil)!,image=CGImageSourceCreateImageAtIndex(source,0,nil)!
   func crop(_ b:[Double])->CGImage {image.cropping(to:CGRect(x:b[0],y:b[1],width:b[2]-b[0],height:b[3]-b[1]))!}
   let actual=ExactHeadingBlockMatch.equivalent(crop(c.globalBounds),crop(c.localBounds),globalText:c.recognizedGlobalText,localText:c.recognizedLocalText)
   results.append(["id":c.id,"expected":c.expectEquivalent,"actual":actual,"pass":actual==c.expectEquivalent])
  }
  let p="Tests/quality_control/heading-local-ownership-2026-10-03/matcher-results.json"
  try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:p))
  print("\(results.filter{$0["pass"] as? Bool == true}.count)/\(results.count) independent whole-block matcher fixtures pass")
  if results.contains(where:{$0["pass"] as? Bool != true}){exit(1)}
 }
}
