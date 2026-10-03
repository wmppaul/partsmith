import Foundation
import CoreGraphics
import PDFKit
@main struct Audit {
 static var currentPage = 0
 static func main() throws {
  let pdf = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
  for oneBased in [5,9,25,31] {
   currentPage = oneBased
   let page = pdf.page(at: oneBased - 1)!, box = page.bounds(for: .mediaBox)
   let result = NativeScorePageAnalyzer.analyze(pageIndex: oneBased - 1,image: NativeScorePageAnalyzer.render(page)!,pageWidth:box.width,pageHeight:box.height)
   fputs("FINISHED page=\(oneBased) staves=\(result.staves.count)\n",stderr)
  }
 }
}
