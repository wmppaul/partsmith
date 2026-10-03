import AppKit
import Foundation
import PDFKit
import CryptoKit

@main enum ManualReviewedExport {
    struct Envelope: Codable { var project: ProjectData }
    struct Proposals: Decodable { var proposals: [Proposal] }
    struct Proposal: Decodable { var bandID: String; var currentRect: [Double]; var proposedRect: [Double] }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func rect(_ r: CGRect, _ b: CGRect) -> [Double] { [r.minX-b.minX,b.maxY-r.maxY,r.maxX-b.minX,b.maxY-r.minY] }
    static func equal(_ a: [Double], _ b: [Double]) -> Bool { a.count == b.count && zip(a,b).allSatisfy { abs($0-$1) < 1e-8 } }
    static func write(_ value: Any, _ url: URL) throws {
        try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to:url)
    }
    static func main() throws {
        let root = URL(fileURLWithPath: ".build/brahms-reviewed-cleanup-2026-10-03")
        let baseline = URL(fileURLWithPath: "output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation")
        let proposalsURL = URL(fileURLWithPath: "Tests/quality_control/brahms-reviewed-cleanup-2026-10-03/manual-proposals-v1.json")
        let decoder=JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let encoder=JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        let proposals=try decoder.decode(Proposals.self,from:Data(contentsOf:proposalsURL)).proposals
        let proposalMap=Dictionary(uniqueKeysWithValues:proposals.map{($0.bandID,$0)})
        let sourceManifest=try JSONSerialization.jsonObject(with:Data(contentsOf:baseline.appendingPathComponent("manifest.json"))) as! [String:Any]
        let package=baseline.appendingPathComponent(sourceManifest["project"] as! String)
        let originalJSON=try Data(contentsOf:package.appendingPathComponent("project.json"))
        let original=try decoder.decode(Envelope.self,from:originalJSON)
        guard try encoder.encode(original)==originalJSON else { fatalError("Baseline codec mismatch") }
        let source=try Data(contentsOf:package.appendingPathComponent("source.pdf"))
        guard hash(source)==sourceManifest["sourceSHA256"] as! String else { fatalError("Source mismatch") }
        let sourceParts=sourceManifest["parts"] as! [[String:Any]]
        var modelToSource:[UUID:[String:Any]]=[:]
        for part in original.project.parts {
            let metadata=sourceParts.first{$0["name"] as? String == part.name}!
            let rows=metadata["placements"] as! [[String:Any]]
            let stored=original.project.bands.filter{$0.partID==part.id}
            guard stored.count==151 && rows.count==stored.count else { fatalError("Part row count") }
            for (band,row) in zip(stored,rows) { modelToSource[band.id]=row }
        }
        guard modelToSource.count==604 && proposalMap.count==7 else {fatalError("Wrong scope")}
        for mode in (CommandLine.arguments.contains("--manual-only") ? ["manual"] : ["baseline", "manual"]) {
            let output=root.appendingPathComponent(mode+"-parts")
            guard !FileManager.default.fileExists(atPath:output.path) else {fatalError("Refusing overwrite")}
            var document=PartsmithDocument(project:original.project,sourcePDFData:source)
            var changed:Set<String>=[]
            if mode=="manual" {
                for band in original.project.bands {
                    let row=modelToSource[band.id]!, id=row["id"] as! String
                    guard let proposed=proposalMap[id] else {continue}
                    let page=document.pdfDocument!.page(at:band.pageIndex)!.bounds(for:.mediaBox)
                    let actual=[band.leftFraction*page.width,band.topFraction*page.height,(1-band.rightFraction)*page.width,band.bottomFraction*page.height]
                    guard equal(actual,proposed.currentRect) else {fatalError("Incorrect target \(id)")}
                    document.updateBand(band.id,topFraction:proposed.proposedRect[1]/page.height,bottomFraction:proposed.proposedRect[3]/page.height)
                    changed.insert(id)
                }
                guard changed==Set(proposalMap.keys) else {fatalError("Not all crop proposals applied")}
                document.project.id=UUID()
                document.project.projectName="Brahms String Quartet No. 3 Op. 67 — Manually reviewed"
                document.project.projectSettings.defaultTitleText="Brahms — String Quartet No. 3, Op. 67"
                // The existing project codec records dates to whole seconds.
                document.project.modifiedAt=Date(timeIntervalSince1970:floor(Date().timeIntervalSince1970))
            }
            var expectedSettings=original.project.projectSettings
            if mode=="manual" {expectedSettings.defaultTitleText="Brahms — String Quartet No. 3, Op. 67"}
            guard document.project.parts==original.project.parts,
                  document.project.projectSettings==expectedSettings,
                  document.project.pageRectifications==original.project.pageRectifications,
                  document.project.bands.filter({$0.pageBreakBefore}).map(\.id)==original.project.bands.filter({$0.pageBreakBefore}).map(\.id),
                  document.project.bands.filter({$0.pageBreakBefore}).count==6 else {fatalError("Unrelated project metadata changed")}
            for (old,new) in zip(original.project.bands,document.project.bands) {
                var comparison=new;comparison.topFraction=old.topFraction;comparison.bottomFraction=old.bottomFraction
                guard comparison==old else {fatalError("Changed noncrop band field")}
            }
            try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
            let packageName=(mode=="manual" ? document.project.projectName : "Brahms baseline reexport")+".partsmithproject"
            let destinationPackage=output.appendingPathComponent(packageName)
            try FileManager.default.createDirectory(at:destinationPackage,withIntermediateDirectories:true)
            let saved=try encoder.encode(Envelope(project:document.project))
            try saved.write(to:destinationPackage.appendingPathComponent("project.json"))
            try source.write(to:destinationPackage.appendingPathComponent("source.pdf"))
            let reopened=try decoder.decode(Envelope.self,from:Data(contentsOf:destinationPackage.appendingPathComponent("project.json")))
            guard try encoder.encode(reopened)==saved, reopened.project==document.project,
                  try Data(contentsOf:destinationPackage.appendingPathComponent("source.pdf"))==source else {fatalError("Reopen mismatch")}
            document=PartsmithDocument(project:reopened.project,sourcePDFData:source)
            let pdf=document.pdfDocument!
            var parts:[[String:Any]]=[]
            for part in document.project.parts {
                var metadata=sourceParts.first{$0["name"] as? String==part.name}!
                let layout=try PartLayoutEngine.makePlan(project:document.project,pageBoundsProvider:{pdf.page(at:$0)?.bounds(for:.mediaBox)},partID:part.id)
                let stored=document.project.bands.filter{$0.partID==part.id}
                guard layout.pages.flatMap(\.placements).map(\.bandID)==stored.map(\.id) else {fatalError("Dropped/reordered band")}
                let filename=part.name+".pdf",url=output.appendingPathComponent(filename)
                try PartPDFExporter.export(partID:part.id,document:document,to:url)
                guard PDFDocument(url:url)?.pageCount==layout.pages.count else {fatalError("Page count")}
                var placements:[[String:Any]]=[]
                for page in layout.pages {for placed in page.placements {
                    var row=modelToSource[placed.bandID]!
                    let sourceBounds=pdf.page(at:placed.sourcePageIndex)!.bounds(for:.mediaBox)
                    let outputBounds=CGRect(origin:.zero,size:layout.pageSize)
                    row["outputPage"]=page.index+1;row["sourceRect"]=rect(placed.sourceRect,sourceBounds);row["destinationRect"]=rect(placed.destinationRect,outputBounds)
                    if changed.contains(row["id"] as! String) {row["provenance"]="manual-source-reviewed-crop"}
                    row["sourceMarkings"]=placed.sourceMarkings.map {mark -> [String:Any] in
                        var result:[String:Any]=["sourceRect":rect(mark.sourceRect,sourceBounds),"destinationRect":rect(mark.destinationRect,outputBounds)]
                        if mark.isBelow {result["isBelow"]=true};return result
                    }
                    placements.append(row)
                }}
                metadata["file"]=filename;metadata["sha256"]=hash(try Data(contentsOf:url));metadata["outputPages"]=layout.pages.count
                metadata["placements"]=placements;metadata["systemsPerPage"]=layout.pages.map{$0.placements.count}
                parts.append(metadata)
                print("\(mode) \(part.name): \(placements.count) bands, \(layout.pages.count) pages, \(layout.pages.map{$0.placements.count})");fflush(stdout)
            }
            var manifest=sourceManifest
            manifest["project"]=packageName;manifest["parts"]=parts
            manifest["status"]=mode=="manual" ? "Manual source-reviewed draft — separate from Auto; full output review pending" : "Current native reexport control of unchanged Auto delivery"
            manifest["renderer"]="Saved project, PartLayoutEngine and PartPDFExporter; seven explicit manual crop edits only in manual set"
            manifest["manualCropReview"]=["changedBandIDs":changed.sorted(),"proposalSHA256":hash(try Data(contentsOf:proposalsURL)),"projectRoundtripExact":true,"embeddedSourceExact":true,"retainedPageBreaks":6]
            try write(manifest,output.appendingPathComponent("manifest.json"))
            for name in ["rectified-review-source.pdf","layout-page-breaks.json"] {
                try FileManager.default.copyItem(at:baseline.appendingPathComponent(name),to:output.appendingPathComponent(name))
            }
        }
    }
}
