import Foundation
import PDFKit
import Vision
import CryptoKit
@main enum Probe {
 struct Inventory: Codable { var source: String; var sourceSHA256: String; var pages: [ScorePageAnalysis] }
 struct Text: Codable { var page: Int; var anchor: Int; var language: String; var text: String; var bounds: [Double]; var confidence: Float }
 static func main() throws {
  setbuf(stdout,nil)
  let out=URL(fileURLWithPath:CommandLine.arguments[1]);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  let w=URL(fileURLWithPath:".build/schumann-directions")
  var inv=try JSONDecoder().decode(Inventory.self,from:Data(contentsOf:w.appendingPathComponent("inventory.json")))
  let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:Data(contentsOf:w.appendingPathComponent("profile.json")))
  let source=try Data(contentsOf:URL(fileURLWithPath:inv.source))
  precondition(SHA256.hash(data:source).map{String(format:"%02x",$0)}.joined()==inv.sourceSHA256)
  let pdf=PDFDocument(data:source)!; var observations:[Text]=[]; var failures:[String]=[]
  let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
  for index in inv.pages.indices {
   try autoreleasepool {
    let page=inv.pages[index], image=NativeScorePageAnalyzer.render(pdf.page(at:page.pageIndex)!,maximumWidth:2200,maximumHeight:3200)!
    inv.pages[index].sharedHeadings=SchumannHeadingCandidate.detect(in:image,page:page,profile:profile,observedText:{id,lines in
     observations += lines.map{Text(page:page.pageIndex+1,anchor:id,language:"candidate-regional",text:$0.text,bounds:[$0.bounds.minX,$0.bounds.minY,$0.bounds.maxX,$0.bounds.maxY],confidence:$0.confidence)}
    },observedFailure:{id,error in failures.append("Page \(index+1) anchor \(id): \(error)")})
    // Independent broad OCR observations retained for diagnostics, never used
    // as the source oracle or as fabricated source-copy text.
    for language in ["en-US","de-DE"] {
     let request=VNRecognizeTextRequest(); request.recognitionLevel = .accurate
     request.usesLanguageCorrection=false; request.recognitionLanguages=[language];request.minimumTextHeight=0.003
     do {try VNImageRequestHandler(cgImage:image,options:[:]).perform([request])
      observations += (request.results ?? []).compactMap { item in
       guard let c=item.topCandidates(1).first else{return nil};let b=item.boundingBox
       return Text(page:index+1,anchor:-2,language:language,text:c.string,bounds:[b.minX,1-b.maxY,b.maxX,1-b.minY],confidence:c.confidence)
      }
     } catch{failures.append("Page \(index+1) full \(language): \(error)")}
    }
    print("Page \(index+1): \(inv.pages[index].sharedHeadings?.count ?? 0) headings")
    try encoder.encode(observations).write(to:out.appendingPathComponent("ocr.json"))
    try encoder.encode(inv).write(to:out.appendingPathComponent("inventory.json"))
   }
  }
  try encoder.encode(ScoreExtractionPlanner.plan(pages:inv.pages,profile:profile)).write(to:out.appendingPathComponent("plan.json"))
  try encoder.encode(failures).write(to:out.appendingPathComponent("failures.json"))
  print("FINISHED \(inv.pages.count) pages; OCR failures \(failures.count)")
 }
}
