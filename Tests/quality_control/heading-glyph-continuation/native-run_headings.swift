import AppKit
import CryptoKit
import Foundation
import PDFKit

struct HeadingCase: Codable { var id:String; var source:String; var sourceSHA256:String; var profile:String; var profileSHA256:String; var inventory:String; var inventorySHA256:String }
struct HeadingInventory: Codable { var source:String; var sourceSHA256:String; var rectifications:[PageRectification]?; var pages:[ScorePageAnalysis] }
struct HeadingOCRLine: Codable { var text:String; var bounds:[Double]; var confidence:Float }
struct HeadingOCRPass: Codable { var pageIndex:Int; var anchorStaffID:Int; var lines:[HeadingOCRLine] }
struct HeadingCaseSummary: Codable { var id:String; var pages:Int; var headingCount:Int; var copiedRows:Int; var bandCount:Int; var planCanApply:Bool; var emptyStaffPages:[Int]; var errors:[String]; var elapsedSeconds:Double; var sourceSHA256:String; var inputInventorySHA256:String }
@main enum HeadingRunner {
    static func hash(_ d:Data)->String { SHA256.hash(data:d).map{String(format:"%02x",$0)}.joined() }
    static func read<T:Decodable>(_ t:T.Type,_ path:String)throws->T {try JSONDecoder().decode(t,from:Data(contentsOf:URL(fileURLWithPath:path)))}
    static func write<T:Encodable>(_ x:T,_ url:URL)throws {let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes];try e.encode(x).write(to:url,options:.atomic)}
    static func fail(_ s:String)->NSError {NSError(domain:"HeadingBlockQA",code:1,userInfo:[NSLocalizedDescriptionKey:s])}
    static func main()throws {
        let args=Array(CommandLine.arguments.dropFirst());guard let variant=args.first else{throw fail("Need variant")}
        let root=URL(fileURLWithPath:".build/heading-glyph-continuation-2026-10-03/native"),out=root.appendingPathComponent(variant)
        let cases=try read([HeadingCase].self,root.appendingPathComponent("config.json").path).filter{ args.count == 1 || args.dropFirst().contains($0.id) }
        var summaries:[HeadingCaseSummary]=[]
        for c in cases {
            let start=Date(),directory=out.appendingPathComponent(c.id);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let source=try Data(contentsOf:URL(fileURLWithPath:c.source)),input=try Data(contentsOf:URL(fileURLWithPath:c.inventory)),profileData=try Data(contentsOf:URL(fileURLWithPath:c.profile))
            guard hash(source)==c.sourceSHA256, hash(input)==c.inventorySHA256, hash(profileData)==c.profileSHA256, let pdf=PDFDocument(data:source) else{throw fail("Input changed: \(c.id)")}
            var inventory=try JSONDecoder().decode(HeadingInventory.self,from:input)
            let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:profileData)
            guard inventory.pages.map(\.pageIndex)==Array(0..<pdf.pageCount) else{throw fail("Missing input page: \(c.id)")}
            var errors:[String]=[],observed:[HeadingOCRPass]=[]
            for index in inventory.pages.indices {
                autoreleasepool {
                    var page=inventory.pages[index];page.sharedHeadings=nil
                    guard !page.staves.isEmpty else{inventory.pages[index].sharedHeadings=[];return}
                    guard let sourcePage=pdf.page(at:page.pageIndex) else{errors.append("Missing PDF page \(page.pageIndex)");return}
                    let image:CGImage?
                    if let correction=inventory.rectifications?.first(where:{$0.pageIndex==page.pageIndex}) {
                        let bounds=sourcePage.bounds(for:.mediaBox)
                        image=SourcePageRenderCache(pdfDocument:pdf,rasterScale:min(2200/bounds.width,3200/bounds.height)).rectifiedDisplayImage(for:page.pageIndex,rectification:correction)
                    } else { image=NativeScorePageAnalyzer.render(sourcePage,maximumWidth:2200,maximumHeight:3200) }
                    guard let image else{errors.append("Render failed \(page.pageIndex)");return}
                    let headings=ScoreSharedHeadingDetector.detect(in:image,page:page,profile:profile,observedText:{anchor,lines in
                        observed.append(.init(pageIndex:page.pageIndex,anchorStaffID:anchor,lines:lines.map{.init(text:$0.text,bounds:[$0.bounds.minX,$0.bounds.minY,$0.bounds.maxX,$0.bounds.maxY],confidence:$0.confidence)}))
                    },observedFailure:{anchor,error in errors.append("Page \(page.pageIndex) anchor \(anchor): \(error)")})
                    inventory.pages[index].sharedHeadings=headings
                }
                print("\(variant) \(c.id) p\(index+1)/\(inventory.pages.count)");fflush(stdout)
            }
            let plan=ScoreExtractionPlanner.plan(pages:inventory.pages.filter{!$0.staves.isEmpty},profile:profile)
            let summary=HeadingCaseSummary(id:c.id,pages:inventory.pages.count,headingCount:inventory.pages.reduce(0){$0+($1.sharedHeadings?.count ?? 0)},copiedRows:plan.bands.reduce(0){$0+$1.sourceMarkings.count},bandCount:plan.bands.count,planCanApply:plan.canApply,emptyStaffPages:inventory.pages.filter{$0.staves.isEmpty}.map(\.pageIndex),errors:errors,elapsedSeconds:Date().timeIntervalSince(start),sourceSHA256:c.sourceSHA256,inputInventorySHA256:c.inventorySHA256)
            try write(inventory,directory.appendingPathComponent("inventory.json"));try write(plan,directory.appendingPathComponent("plan.json"));try write(observed,directory.appendingPathComponent("ocr.json"));try write(summary,directory.appendingPathComponent("summary.json"))
            summaries.append(summary);try write(summaries,out.appendingPathComponent("summary.json"))
            print("DONE \(variant) \(c.id) headings=\(summary.headingCount) bands=\(summary.bandCount) copies=\(summary.copiedRows) errors=\(errors.count)");fflush(stdout)
        }
        if summaries.contains(where:{!$0.errors.isEmpty}){throw fail("Recognition/render errors are recorded")}
    }
}
