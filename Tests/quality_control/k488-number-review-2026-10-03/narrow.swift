import AppKit
import Foundation
import PDFKit
@main enum NarrowReview {
 struct Envelope: Decodable { var project: ProjectData }
 static func main() throws {
  let args=CommandLine.arguments
  let folder=URL(fileURLWithPath:args[1]);let out=URL(fileURLWithPath:args[2])
  let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
  var project=try decoder.decode(Envelope.self,from:Data(contentsOf:folder.appendingPathComponent("project.json"))).project
  let source=try Data(contentsOf:folder.appendingPathComponent("source.pdf"));let pdf=PDFDocument(data:source)!
  project.bands=project.bands.filter{$0.pageIndex==16}
  project.projectSettings.defaultTitleText="Mozart K. 488 — source page 17"
  project.projectSettings.defaultComposerText="Bars 144–156 · Scale 1.4 · Side margins 0 pt"
  for i in project.parts.indices {project.parts[i].layoutSettings.scale=1.4;project.parts[i].layoutSettings.sideMarginPoints=0}
  project.parts=project.parts.filter{["Piano","Flute","Violin I"].contains($0.name)}
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  var rows:[[String:Any]]=[]
  for part in project.parts {
   let cache=SourcePageRenderCache(pdfDocument:pdf)
   let layout=try PartLayoutEngine.makePlan(project:project,pageBoundsProvider:{cache.pageBounds(for:$0)},partID:part.id,
    horizontalContentBoundsProvider:{band,rect in cache.horizontalContentBounds(for:band,sourceRect:rect,rectification:nil)})
   let data=try PartPDFExporter.pdfData(for:part.id,project:project,sourcePDFData:source)
   try data.write(to:out.appendingPathComponent(part.name+".pdf"))
   let paper=CGRect(origin:.zero,size:layout.pageSize)
   for page in layout.pages {
    let numbers=page.placements.compactMap(\.barNumberRect)
    for p in page.placements {
     var row:[String:Any]=["part":part.name,"outputPage":page.index+1,"bandID":p.bandID.uuidString,"musicRect":rect(p.destinationRect),"copies":p.sourceMarkings.map{rect($0.destinationRect)},"paper":rect(paper),"generatedRest":p.generatedRest != nil]
     if let number=p.barNumberRect {
      row["numberRect"]=rect(number);row["onPaper"]=paper.contains(number)
      row["overlapsSourceOrCopy"]=page.placements.contains{$0.destinationRect.intersects(number)||$0.sourceMarkings.contains{$0.destinationRect.intersects(number)}}
      row["overlapsOtherNumber"]=numbers.filter{$0 != number}.contains{$0.intersects(number)}
      row["overlapsHeader"]=page.index==0 && (layout.titleBlockRect?.intersects(number) ?? false)
      precondition(paper.contains(number) && row["overlapsSourceOrCopy"] as! Bool == false && row["overlapsOtherNumber"] as! Bool == false && row["overlapsHeader"] as! Bool == false)
     }
     rows.append(row)
    }
   }
   print(part.name,layout.pages.count,"pages",layout.pages.flatMap(\.placements).count,"placements")
  }
  try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
 }
 static func rect(_ r:CGRect)->[Double]{[r.minX,r.minY,r.maxX,r.maxY]}
}
