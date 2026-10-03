import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum EndingCorpusRunner {
    typealias D = ScoreSharedEndingDetector
    struct Item: Decodable {
        var id: String; var source: String; var sourceSHA256: String
        var profile: String; var profileSHA256: String
        var inventory: String; var inventorySHA256: String
        var pageCount: Int; var disposition: String
    }
    struct Roster: Decodable { var frozenCoreDigest: String; var scores: [Item] }
    struct Inventory: Decodable { var pages: [ScorePageAnalysis] }
    struct Checkpoint: Codable {
        var inputKey: String; var pageIndex: Int; var result: D.PageResult
        var failures: [String]; var seconds: Double; var renderedWidth: Int; var renderedHeight: Int
    }
    struct FullResult: Codable {
        var inputKey: String; var source: String; var sourceSHA256: String
        var inventory: String; var inventorySHA256: String; var profile: String; var profileSHA256: String
        var pages: [Checkpoint]; var pairs: [D.Pair]; var analyses: [ScorePageAnalysis]
    }
    static let root = URL(fileURLWithPath: ".build/ending-corpus-2026-10-03", isDirectory: true)
    static let encoder: JSONEncoder = { let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes];return e }()
    static func read<T:Decodable>(_ type:T.Type,_ path:URL) throws -> T {
        try JSONDecoder().decode(type,from:Data(contentsOf:path))
    }
    static func sha(_ data:Data)->String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func bound(_ path:String,_ expected:String)throws->Data {
        let data=try Data(contentsOf:URL(fileURLWithPath:path))
        guard sha(data)==expected else {throw failure("Bound input changed: \(path)")};return data
    }
    static func failure(_ text:String)->NSError { .init(domain:"EndingCorpus",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
    static func write<T:Encodable>(_ value:T,_ url:URL)throws {try encoder.encode(value).write(to:url,options:.atomic)}
    static func json(_ value:Any,_ url:URL)throws {
        try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to:url,options:.atomic)
    }
    static func main() throws {
        guard CommandLine.arguments.count==1 else { throw failure("This frozen runner takes no arguments; rerun the same executable to resume page checkpoints.") }
        let roster=try read(Roster.self,root.appendingPathComponent("roster.json"))
        let binaryHash=sha(try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[0])))
        let active=roster.scores.filter { $0.disposition=="scan" }
        let totalPages=active.reduce(0) { $0+$1.pageCount }
        var completedPages=0,summaries:[[String:Any]]=[]
        for item in active {
            let source=try bound(item.source,item.sourceSHA256)
            let inventoryData=try bound(item.inventory,item.inventorySHA256)
            let profileData=try bound(item.profile,item.profileSHA256)
            let inventory=try JSONDecoder().decode(Inventory.self,from:inventoryData)
            let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:profileData)
            guard let pdf=PDFDocument(data:source),pdf.pageCount==item.pageCount,
                  inventory.pages.map(\.pageIndex)==Array(0..<item.pageCount),profile.requiresSystemAssignment != true else {
                throw failure("Full fixed-layout source roster differs: \(item.id)")
            }
            let key=sha(Data([item.sourceSHA256,item.inventorySHA256,item.profileSHA256,roster.frozenCoreDigest,binaryHash].joined(separator:"|").utf8))
            let folder=root.appendingPathComponent(item.id,isDirectory:true)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let base=ScoreDetectionReview.initial(profile:profile,analyses:inventory.pages,sourcePDFData:source,rectifications:[])
            guard base.plan.canApply else { throw failure("Eligibility changed in current frozen Core: \(item.id)") }
            var checkpoints:[Checkpoint]=[]
            for page in inventory.pages {
                let cache=folder.appendingPathComponent(String(format:"page-%03d.json",page.pageIndex+1))
                if FileManager.default.fileExists(atPath:cache.path) {
                    let old=try read(Checkpoint.self,cache)
                    guard old.inputKey==key,old.pageIndex==page.pageIndex else { throw failure("Checkpoint input/binary differs; do not reuse \(cache.path)") }
                    checkpoints.append(old)
                } else {
                    let started=Date()
                    var result=D.PageResult(pageIndex:page.pageIndex,ownershipVerified:false,systemIndices:[],
                        geometryProposalCount:0,mergedProposalCount:0,candidates:[])
                    var errors:[String]=[],width=0,height=0
                    try autoreleasepool {
                        guard let sourcePage=pdf.page(at:page.pageIndex),
                              let image=NativeScorePageAnalyzer.render(sourcePage,maximumWidth:2400,maximumHeight:3500) else {
                            errors.append("Source page could not render; retained as an unknown pairing barrier.");return
                        }
                        width=image.width;height=image.height
                        if page.staves.isEmpty {
                            if let raster=D.Raster(image:image),raster.pixels.allSatisfy({$0==255}) {
                                result.ownershipVerified=true
                            }
                        } else {
                            result=D.analyze(in:image,page:page,profile:profile,observedFailure:{ errors.append($0.localizedDescription) })
                            if !errors.isEmpty {
                                result.ownershipVerified=false;result.candidates=[]
                            }
                        }
                        if !result.candidates.isEmpty {
                            let png=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
                            try png.write(to:folder.appendingPathComponent(String(format:"source-page-%03d.png",page.pageIndex+1)),options:.atomic)
                        }
                    }
                    let record=Checkpoint(inputKey:key,pageIndex:page.pageIndex,result:result,failures:errors,
                        seconds:Date().timeIntervalSince(started),renderedWidth:width,renderedHeight:height)
                    try write(record,cache);checkpoints.append(record)
                }
                completedPages += 1
                print("\(completedPages)/\(totalPages) \(item.id) page \(page.pageIndex+1)/\(item.pageCount): \(checkpoints.last!.result.candidates.count) candidates, \(checkpoints.last!.failures.count) errors")
                fflush(stdout)
                try json(["state":"running","score":item.id,"page":page.pageIndex+1,"completedPages":completedPages,
                          "totalPages":totalPages,"completedScores":summaries.count,"binarySHA256":binaryHash],root.appendingPathComponent("progress.json"))
            }
            let pairs=D.pairs(in:checkpoints.map(\.result))
            let metadata=ScoreSharedEndingMetadata.make(pairs:pairs,pages:inventory.pages)
            var pages=inventory.pages
            for i in pages.indices { pages[i].sharedEndings=metadata[pages[i].pageIndex] ?? [] }
            let after=ScoreDetectionReview.initial(profile:profile,analyses:pages,sourcePDFData:source,rectifications:[]).plan
            let beforeByID=Dictionary(uniqueKeysWithValues:base.plan.bands.map { ($0.id,$0) })
            var expanded:[String]=[],lostGeometry:[String]=[],lostCopies:[String]=[]
            for band in after.bands {
                guard let before=beforeByID[band.id] else { lostGeometry.append(band.id);continue }
                if before.topFraction != band.topFraction || before.bottomFraction != band.bottomFraction
                    || before.leftFraction != band.leftFraction || before.rightFraction != band.rightFraction { expanded.append(band.id) }
                if band.topFraction>before.topFraction || band.bottomFraction<before.bottomFraction
                    || band.leftFraction>before.leftFraction || band.rightFraction>before.rightFraction { lostGeometry.append(band.id) }
                if !before.sourceMarkings.allSatisfy(band.sourceMarkings.contains) {lostCopies.append(band.id)}
            }
            let changedOrder=base.plan.bands.map(\.id) != after.bands.map(\.id)
            let summary:[String:Any]=["id":item.id,"sourceSHA256":item.sourceSHA256,"inputKey":key,"pages":pages.count,
                "geometryProposals":checkpoints.reduce(0) { $0+$1.result.geometryProposalCount },
                "mergedProposals":checkpoints.reduce(0) { $0+$1.result.mergedProposalCount },
                "numericCandidates":checkpoints.reduce(0) { $0+$1.result.candidates.count },"pairs":pairs.count,
                "endingSourceRows":metadata.values.reduce(0) { $0+$1.count },"bands":after.bands.count,
                "sourceCopies":after.bands.reduce(0) { $0+$1.sourceMarkings.count },
                "errors":checkpoints.flatMap { cp in cp.failures.map { ["pageIndex":cp.pageIndex,"error":$0] as [String:Any] } },
                "unknownBarrierPages":checkpoints.filter { !$0.result.ownershipVerified }.map(\.pageIndex),
                "mainCropsExpanded":expanded,"mainCropsLostGeometry":lostGeometry,"lostExistingCopies":lostCopies,
                "changedBandIdentityOrOrder":changedOrder,"planCanApply":after.canApply,
                "sourceGeometryPreserved":lostGeometry.isEmpty && lostCopies.isEmpty && !changedOrder,
                "visualReview":"pending; selected pairs are hypotheses until checked against the source"]
            try write(FullResult(inputKey:key,source:item.source,sourceSHA256:item.sourceSHA256,
                inventory:item.inventory,inventorySHA256:item.inventorySHA256,profile:item.profile,profileSHA256:item.profileSHA256,
                pages:checkpoints,pairs:pairs,analyses:pages),folder.appendingPathComponent("result.json"))
            try write(after,folder.appendingPathComponent("plan.json"));try json(summary,folder.appendingPathComponent("summary.json"))
            summaries.append(summary)
            print("COMPLETE \(item.id): \(pairs.count) pairs, \(after.bands.count) bands; source-geometry preservation \(!changedOrder && lostGeometry.isEmpty && lostCopies.isEmpty)");fflush(stdout)
        }
        try json(["state":"complete","scannedScores":summaries.count,"scannedPages":completedPages,
                  "binarySHA256":binaryHash,"scores":summaries],root.appendingPathComponent("summary.json"))
        try json(["state":"complete","completedPages":completedPages,"totalPages":totalPages,
                  "completedScores":summaries.count,"binarySHA256":binaryHash],root.appendingPathComponent("progress.json"))
    }
}
