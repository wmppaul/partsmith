import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum ReviewedOverlapTrim {
 struct Envelope: Codable { var project: ProjectData }
 struct Change: Decodable { var id: String; var bandUUID: UUID; var sourcePage: Int; var edge: String; var value: Double; var sourceHeight: Double; var oldRect: [Double]; var newRect: [Double] }
 struct Edits: Decodable { var originalProjectSHA256: String; var sourceSHA256: String; var changes: [Change] }
 static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
 static func rect(_ x: CGRect, _ page: CGRect) -> [Double] { [x.minX-page.minX,page.maxY-x.maxY,x.maxX-page.minX,page.maxY-x.minY] }
 static func json(_ object: Any, _ url: URL) throws { try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to: url) }
 static func main() throws {
  let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
  let base=root.appendingPathComponent("output/pdf/auto-qc-2026-10-03/brahms-quartet-93521-viola-in-tempo-repair")
  let work=root.appendingPathComponent(".build/brahms93521-reviewed-overlap-trim-2026-10-03")
  var manifest=try JSONSerialization.jsonObject(with: Data(contentsOf:base.appendingPathComponent("manifest.json"))) as! [String:Any]
  let package=manifest["project"] as! String
  let source=try Data(contentsOf:base.appendingPathComponent(package).appendingPathComponent("source.pdf"))
  let originalBytes=try Data(contentsOf:base.appendingPathComponent(package).appendingPathComponent("project.json"))
  let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
  let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601;encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
  let edits=try decoder.decode(Edits.self,from:Data(contentsOf:work.appendingPathComponent("proposed-edits-before-output.json")))
  precondition(hash(originalBytes)==edits.originalProjectSHA256 && hash(source)==edits.sourceSHA256)
  let original=try decoder.decode(Envelope.self,from:originalBytes).project
  var document=PartsmithDocument(project:original,sourcePDFData:source)
  precondition(original.bands.count==604 && original.pageRectifications.count==9 && original.bands.reduce(0) { $0+$1.sourceMarkings.count }==42)
  var expected=original
  for change in edits.changes {
   let index=original.bands.firstIndex { $0.id==change.bandUUID }!;let band=original.bands[index]
   precondition(band.pageIndex==change.sourcePage-1 && band.generatedRest==nil)
   let bounds=document.pdfDocument!.page(at:band.pageIndex)!.bounds(for:.mediaBox)
   precondition(abs(bounds.height-change.sourceHeight)<1e-8)
   precondition(abs(band.topFraction*bounds.height-change.oldRect[1])<1e-7 && abs(band.bottomFraction*bounds.height-change.oldRect[3])<1e-7)
   let top=change.edge=="top" ? change.value/bounds.height : band.topFraction
   let bottom=change.edge=="bottom" ? change.value/bounds.height : band.bottomFraction
   document.updateBand(band.id,topFraction:top,bottomFraction:bottom)
   expected.bands[index].topFraction=top;expected.bands[index].bottomFraction=bottom
  }
  expected.modifiedAt=document.project.modifiedAt
  precondition(document.project==expected,"Only seven specified edges and transaction date may change")
  let output=work.appendingPathComponent("parts");precondition(!FileManager.default.fileExists(atPath:output.path))
  try FileManager.default.copyItem(at:base,to:output)
  // Parent receipts remain in the immutable parent delivery, not falsely attached to changed bytes.
  try FileManager.default.removeItem(at:output.appendingPathComponent("delivery-hashes.json"))
  try FileManager.default.removeItem(at:output.appendingPathComponent("README.md"))
  let saved=try encoder.encode(Envelope(project:document.project));try saved.write(to:output.appendingPathComponent(package).appendingPathComponent("project.json"))
  let reopened=PartsmithDocument(project:try decoder.decode(Envelope.self,from:saved).project,sourcePDFData:try Data(contentsOf:output.appendingPathComponent(package).appendingPathComponent("source.pdf")))
  let reopenedBytes = try encoder.encode(Envelope(project:reopened.project));precondition(reopenedBytes==saved)
  precondition(reopened.sourcePDFData==source);document=reopened
  let pdf=document.pdfDocument!;var parts=manifest["parts"] as! [[String:Any]]
  var totalPages=0
  for partIndex in parts.indices {
   let name=parts[partIndex]["name"] as! String;let part=document.project.parts.first { $0.name==name }!
   let stored=document.project.bands.filter { $0.partID==part.id }
   let layout=try PartLayoutEngine.makePlan(project:document.project,pageBoundsProvider:{pdf.page(at:$0)?.bounds(for:.mediaBox)},partID:part.id)
   precondition(stored.count==151 && layout.pages.flatMap(\.placements).flatMap(\.sourceBandIDs)==stored.map(\.id))
   let oldPlacements=parts[partIndex]["placements"] as! [[String:Any]]
   let oldByBand=Dictionary(uniqueKeysWithValues:zip(stored.map(\.id),oldPlacements))
   let outPDF=output.appendingPathComponent(parts[partIndex]["file"] as! String)
   try PartPDFExporter.export(partID:part.id,document:document,to:outPDF)
   var placements=[[String:Any]]()
   for page in layout.pages { for placed in page.placements {
    var row=oldByBand[placed.bandID]!;let sourceBounds=pdf.page(at:placed.sourcePageIndex)!.bounds(for:.mediaBox);let outputBounds=CGRect(origin:.zero,size:layout.pageSize)
    row["outputPage"]=page.index+1;row["sourceRect"]=rect(placed.sourceRect,sourceBounds);row["destinationRect"]=rect(placed.destinationRect,outputBounds)
    row["sourceMarkings"]=placed.sourceMarkings.map { mark -> [String:Any] in
     var x:[String:Any]=["sourceRect":rect(mark.sourceRect,sourceBounds),"destinationRect":rect(mark.destinationRect,outputBounds)]
     if mark.isBelow { x["isBelow"]=true };return x
    };placements.append(row)
   }}
   precondition(placements.count==151);parts[partIndex]["placements"]=placements;parts[partIndex]["outputPages"]=layout.pages.count;parts[partIndex]["systemsPerPage"]=layout.pages.map { $0.placements.count };parts[partIndex]["sha256"]=hash(try Data(contentsOf:outPDF));totalPages+=layout.pages.count
  }
  manifest["parts"]=parts;manifest["status"]="Private seven-edge manual overlap trim awaiting independent source and final-output review"
  manifest["manualOverlapEditsFile"]="proposed-edits-before-output.json"
  try json(manifest,output.appendingPathComponent("manifest.json"))
  try FileManager.default.copyItem(at:work.appendingPathComponent("proposed-edits-before-output.json"),to:output.appendingPathComponent("proposed-edits-before-output.json"))
  try json(["sourceSHA256":hash(source),"originalProjectSHA256":hash(originalBytes),"finalProjectSHA256":hash(saved),"onlySevenSpecifiedEdgesAndModificationDateChanged":true,"all604BandUUIDsAndOrderPreserved":true,"rectificationsExact":true,"sourceMarkingsExact":true,"nativeSaveDecodeReopenCanonicalBytesExact":true,"outputPages":totalPages,"allOriginalReferencesPresent":true],work.appendingPathComponent("native-proof.json"))
  print("Native seven-edge edit/save/reopen/export complete: \(totalPages) pages,604 references,9 corrections,42 source copies preserved.")
 }
}
