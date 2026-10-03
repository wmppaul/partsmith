import Foundation
import PDFKit
@main enum NumberProbe {
 static func main() throws {
  var p=ProjectData.empty
  let id=UUID();var settings=PartLayoutSettings.default;settings.scale=0.6;settings.interSystemGap=4;settings.balancePages=false
  p.parts=[PartModel(id:id,name:"Small staff",color:ColorData(red:0.2,green:0.3,blue:0.4),layoutSettings:settings,createdAt:.now)]
  p.pageCount=1;p.projectSettings.showTitleBlock=false;p.projectSettings.showPartNameInHeader=false
  p.bands=(0..<3).map { i in BandModel(id:UUID(),pageIndex:0,partID:id,topFraction:0.2+Double(i)*0.1,bottomFraction:0.2125+Double(i)*0.1,leftFraction:0,rightFraction:0,excluded:false,createdAt:.now,barNumberMode:.manual,barNumberValue:i+1) }
  let plan=try PartLayoutEngine.makePlan(project:p,pageBoundsProvider:{_ in CGRect(x:0,y:0,width:600,height:800)},partID:id)
  for page in plan.pages {for (i,a) in page.placements.enumerated(){print(i,a.destinationRect,a.barNumberRect!);for b in page.placements.dropFirst(i+1) {if a.barNumberRect!.intersects(b.barNumberRect!){print("NUMBER_COLLISION",a.barNumberRect!.intersection(b.barNumberRect!))}}}}
 }
}
