import CoreGraphics
import Foundation
import PDFKit

/// Native offline PDF rendering shared by the app and batch inventory. Fractions
/// describe the supplied image; unrectified PDF pages map directly to PDF points.
enum NativeScorePageAnalyzer {
    static func render(_ page: PDFPage, maximumWidth: Int = 1800, maximumHeight: Int = 2600) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(CGFloat(maximumWidth) / bounds.width, CGFloat(maximumHeight) / bounds.height)
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / bounds.width, y: CGFloat(height) / bounds.height)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

}

import Vision
@main enum VisionProbe {
 static func main() throws {
  let pdf=PDFDocument(url:URL(fileURLWithPath:"sample_scores/normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf"))!
  for pageIndex in [0,16] {
   let image=NativeScorePageAnalyzer.render(pdf.page(at:pageIndex)!,maximumWidth:2200,maximumHeight:3200)!
   for regional in [true,false] {
    let y=pageIndex==0 ? 45.948667398498706 : 3.2759540817290236
    let bottom=pageIndex==0 ? 93.35846271559302 : 50.69750170200968
    let sourceHeight=pdf.page(at:pageIndex)!.bounds(for:.mediaBox).height
    let rect=CGRect(x:0,y:floor(y/sourceHeight*Double(image.height)),width:Double(image.width),height:ceil((bottom-y)/sourceHeight*Double(image.height)))
    let request=VNRecognizeTextRequest();request.recognitionLevel = .accurate;request.usesLanguageCorrection=false;request.recognitionLanguages=["en-US"];request.minimumTextHeight=regional ? 0.03 : 0.003
    request.customWords=["Allegro", "Allegretto", "Adagio", "Andante", "Andantino", "Presto", "Prestissimo", "Largo", "Larghetto", "Lento", "Moderato", "Vivace", "Grave", "Maestoso", "Agitato", "Scherzo", "Trio", "Coda", "Doppio", "Movimento", "Variazioni"]
    do {
     try VNImageRequestHandler(cgImage:regional ? image.cropping(to:rect)! : image,options:[:]).perform([request])
     print("page",pageIndex+1,"regional",regional,"observed",request.results?.count ?? -1)
     for obs in request.results ?? [] {print(obs.topCandidates(1).first?.string ?? "",obs.topCandidates(1).first?.confidence ?? 0,obs.boundingBox)}
    } catch { let e=error as NSError; print("ERROR page",pageIndex+1,"regional",regional,"domain",e.domain,"code",e.code,"description",e.localizedDescription,"info",e.userInfo) }
   }
  }
 }
}
