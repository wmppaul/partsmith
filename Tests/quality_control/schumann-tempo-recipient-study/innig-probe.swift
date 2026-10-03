import Foundation
import PDFKit
import Vision
@main enum InnigProbe {
 static func main() throws {
  struct Inv:Decodable{var source:String;var pages:[ScorePageAnalysis]}
  let inv=try JSONDecoder().decode(Inv.self,from:Data(contentsOf:URL(fileURLWithPath:".build/schumann-directions/inventory.json")))
  let pdf=PDFDocument(url:URL(fileURLWithPath:inv.source))!, page=inv.pages[6]
  let image=NativeScorePageAnalyzer.render(pdf.page(at:6)!,maximumWidth:2200,maximumHeight:3200)!
  let lines=page.staves[0].staffLineFractions,space=(lines[4]-lines[0])/4,top=max(0,lines[0]-12*space),bottom=lines[0]-space*0.3
  let rect=CGRect(x:0,y:floor(top*Double(image.height)),width:Double(image.width),height:ceil((bottom-top)*Double(image.height)))
  let crop=image.cropping(to:rect)!
  for fast in [false,true] {for correction in [false,true] {for language in ["en-US","de-DE"] {
   let request=VNRecognizeTextRequest();request.recognitionLevel=fast ? .fast:.accurate;request.usesLanguageCorrection=correction;request.recognitionLanguages=[language];request.minimumTextHeight=0.03;request.customWords=["Innig","innig","lebhaft","Langsam"]
   try VNImageRequestHandler(cgImage:crop,options:[:]).perform([request])
   print(fast,correction,language)
   for o in request.results ?? [] {for c in o.topCandidates(3){print(c.string,c.confidence)}}
  }}}
 }
}
