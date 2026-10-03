import AppKit
import CryptoKit
import Foundation
import PDFKit

@main enum LocalEndingRunner {
    typealias D = ScoreSharedEndingDetector
    typealias L = ScoreLocalEndingPreservation
    struct Input: Decodable { var source:String; var sourceSHA256:String; var profile:String; var profileSHA256:String; var pairs:[D.Pair]; var analyses:[ScorePageAnalysis] }
    struct Inventory: Codable { var source:String; var sourceSHA256:String; var pages:[ScorePageAnalysis] }
    struct Cache: Codable { var sourceSHA256:String;var inputSHA256:String;var profileSHA256:String; var recognitionBinarySHA256:String;var parts:[String:[D.PageResult]];var errors:[String] }
    static let work=URL(fileURLWithPath:".build/ending-local-counterparts")
    static let origin=URL(fileURLWithPath:".build/ending-corpus-2026-10-03")
    static let ids=["lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312","medium-skewed-03-schumann-piano-quintet-op44-imslp-06822","medium-skewed-05-brahms-string-quartet-no3-op67-imslp-09200"]
    static let enc:JSONEncoder={let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes];return e}()
    static func sha(_ d:Data)->String{SHA256.hash(data:d).map{String(format:"%02x",$0)}.joined()}
    static func read<T:Decodable>(_ t:T.Type,_ p:URL)throws->T{try JSONDecoder().decode(t,from:Data(contentsOf:p))}
    static func write<T:Encodable>(_ x:T,_ p:URL)throws{try enc.encode(x).write(to:p,options:.atomic)}
    static func main()throws {
        let binarySHA=sha(try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[0])))
        for id in ids {
            let folder=work.appendingPathComponent(id);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let inputData=try Data(contentsOf:origin.appendingPathComponent(id+"/result.json"))
            let input=try JSONDecoder().decode(Input.self,from:inputData)
            let source=try Data(contentsOf:URL(fileURLWithPath:input.source))
            let profileData=try Data(contentsOf:URL(fileURLWithPath:input.profile))
            precondition(sha(source)==input.sourceSHA256 && sha(profileData)==input.profileSHA256)
            let profile=try JSONDecoder().decode(ScoreExtractionProfile.self,from:profileData)
            let base=ScoreDetectionReview.initial(profile:profile,analyses:input.analyses,sourcePDFData:source,rectifications:[])
            precondition(base.plan.canApply)
            let pdf=PDFDocument(data:source)!
            let needed=Dictionary(grouping:input.pairs.flatMap{[$0.first,$0.second]},by:\.pageIndex)
            let cacheFile=folder.appendingPathComponent("local-recognition.json")
            var cache:Cache
            if FileManager.default.fileExists(atPath:cacheFile.path) {
                cache=try read(Cache.self,cacheFile)
                precondition(cache.sourceSHA256==input.sourceSHA256 && cache.inputSHA256==sha(inputData) && cache.profileSHA256==input.profileSHA256)
            } else {
                cache=Cache(sourceSHA256:input.sourceSHA256,inputSHA256:sha(inputData),profileSHA256:input.profileSHA256,recognitionBinarySHA256:binarySHA,parts:[:],errors:[])
                for pageIndex in needed.keys.sorted() {
                    try autoreleasepool {
                        let page=input.analyses.first{$0.pageIndex==pageIndex}!
                        let systems=Set(needed[pageIndex]!.map(\.systemIndex))
                        let image=NativeScorePageAnalyzer.render(pdf.page(at:pageIndex)!,maximumWidth:2400,maximumHeight:3500)!
                        for part in profile.parts {
                            let recipientSystems=systems.filter { system in
                                base.plan.bands.contains { $0.pageIndex==pageIndex && $0.systemIndex==system && $0.partID==part.id
                                    && !$0.candidateIDs.contains(needed[pageIndex]!.first{$0.systemIndex==system}!.anchorStaffID) }
                            }
                            if recipientSystems.isEmpty{continue}
                            let found=L.analyze(in:image,page:page,profile:profile,plan:base.plan,partID:part.id,systems:Set(recipientSystems),observedFailure:{cache.errors.append($0.localizedDescription)})
                            cache.parts[part.id,default:[]].append(found)
                            print("\(id) p\(pageIndex+1) \(part.id): \(found.candidates.count) local candidates");fflush(stdout)
                        }
                    }
                }
                try write(cache,cacheFile)
            }
            var counterparts:[ScoreEndingLocalCounterpart]=[]
            for pair in input.pairs {for part in profile.parts {
                if let local=cache.parts[part.id],let match=L.counterpart(global:pair,partID:part.id,localPages:local,pages:input.analyses,plan:base.plan){counterparts.append(match)}
            }}
            var pages=input.analyses
            for i in pages.indices {for j in (pages[i].sharedEndings ?? []).indices {
                pages[i].sharedEndings![j].localCounterparts=counterparts.filter{$0.globalMembers==pages[i].sharedEndings![j].members}
            }}
            let after=ScoreDetectionReview.initial(profile:profile,analyses:pages,sourcePDFData:source,rectifications:[])
            var changed:[String]=[],lostMain:[String]=[]
            for (before,after) in zip(base.plan.bands,after.plan.bands) {
                var same=before;same.sourceMarkings=after.sourceMarkings
                if same != after {lostMain.append(before.id)}
                if before.sourceMarkings != after.sourceMarkings {changed.append(before.id)}
            }
            precondition(lostMain.isEmpty)
            try write(counterparts,folder.appendingPathComponent("counterparts.json"))
            try write(after.plan,folder.appendingPathComponent("plan.json"))
            try write(Inventory(source:input.source,sourceSHA256:input.sourceSHA256,pages:pages),folder.appendingPathComponent("inventory.json"))
            let summary:[String:Any] = ["score":id,"globalPairs":input.pairs.count,"counterpartPairs":counterparts.count,"removedRows":changed,"unrelatedOrMainChanges":lostMain,"beforeCopies":base.plan.bands.reduce(0){$0+$1.sourceMarkings.count},"afterCopies":after.plan.bands.reduce(0){$0+$1.sourceMarkings.count},"errors":cache.errors]
            try JSONSerialization.data(withJSONObject:summary,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("summary.json"),options:.atomic)
            print("COMPLETE \(id): counterparts \(counterparts.count), removed \(changed)");fflush(stdout)
        }
    }
}
