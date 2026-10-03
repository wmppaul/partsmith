import CoreGraphics
import Foundation
import Vision

/// Experimental paired ending recognition. OCR establishes evidence, while
/// exports retain the original lines and literal source glyphs. No re-engraving.
enum ScoreSharedEndingDetector {
    struct TextEvidence: Codable {
        var mode: String
        var text: String
        var confidence: Float
        var bounds: [Double]
    }
    struct Candidate: Codable {
        var pageIndex: Int
        var systemIndex: Int
        var anchorStaffID: Int
        var bounds: [Double] // top-down PDF points, before final copy allowance
        var copyBounds: [Double]
        var numberBounds: [Double]
        var staffSpace: Double
        var pageWidth: Double
        var pageHeight: Double
        var closedRight: Bool
        var rightHookBottom: Double?
        var evidence: [TextEvidence]
        var memberCount: Int
        var role: String? {
            let eligible = evidence.filter { $0.confidence.isFinite && $0.confidence >= 0.5 }
            let labels = Set(eligible.map { $0.text.trimmingCharacters(in: CharacterSet(charactersIn: " .")) })
            if labels.contains("1") && labels.contains("2") { return nil }
            if labels.contains("2") { return "second" }
            if labels.contains("1") || eligible.contains(where: { $0.mode == "fast" && $0.text.trimmingCharacters(in: CharacterSet(charactersIn: " .")) == "I" }) { return "first" }
            return nil
        }
    }

    static func merge(_ groups: inout [Candidate], _ c: Candidate, narrow evidence:[TextEvidence]) {
      let b=c.bounds,sp=c.staffSpace
                if let i=groups.firstIndex(where:{g in
                    abs(g.bounds[0]-b[0])<sp*0.4 && abs(g.bounds[1]-b[1])<sp*0.5 && min(g.bounds[2],b[2])-max(g.bounds[0],b[0])>0.8*min(g.bounds[2]-g.bounds[0],b[2]-b[0])
                }) {
                    groups[i].bounds=[min(groups[i].bounds[0],b[0]),min(groups[i].bounds[1],b[1]),max(groups[i].bounds[2],b[2]),max(groups[i].bounds[3],b[3])]
                    groups[i].evidence+=evidence;groups[i].memberCount+=1
                }else{groups.append(c)}
    }
}

@main enum Control {
 typealias D=ScoreSharedEndingDetector
 static func candidate(_ evidence:[D.TextEvidence]) -> D.Candidate {
 D.Candidate(pageIndex:0,systemIndex:0,anchorStaffID:0,bounds:[196.4,136.4,270,168.2],copyBounds:[],numberBounds:[204,141,257,166],staffSpace:12,pageWidth:620,pageHeight:300,closedRight:false,rightHookBottom:nil,evidence:evidence,memberCount:1)
 }
 static func main() throws {
 let wide2=D.TextEvidence(mode:"accurate-wide",text:"2",confidence:1,bounds:[0.6,0.2,0.8,0.7])
 let narrow1=D.TextEvidence(mode:"accurate",text:"1",confidence:1,bounds:[0.6,0.2,0.8,0.7])
 let wide1=D.TextEvidence(mode:"accurate-wide",text:"1",confidence:1,bounds:[0.6,0.2,0.8,0.7])
 let cases:[(String,[D.TextEvidence],[D.TextEvidence],[D.TextEvidence],String?)]=[
 ("later-only-wide-success",[],[wide2],[],"second"),
 ("later-wide-conflicts-with-earlier-narrow",[narrow1],[wide2],[],nil),
 ("earlier-wide-retained",[wide2],[],[],"second"),
 ("later-narrow-positive",[],[narrow1],[narrow1],"first"),
 ("later-wide-same-label",[narrow1],[wide1],[],"first")]
 var out:[[String:Any]]=[]
 for (name,early,late,narrow,expected) in cases {
 var groups=[candidate(early)],c=candidate(late);c.bounds=[196.4,139.4,254,170]
 D.merge(&groups,c,narrow:narrow)
 out.append(["id":name,"expectedRole":expected ?? "nil","actualRole":groups[0].role ?? "nil","matchesExpected":groups[0].role==expected,"memberCount":groups[0].memberCount,"modesRetained":groups[0].evidence.map{$0.mode},"textsRetained":groups[0].evidence.map{$0.text}])
 }
 let data=try JSONSerialization.data(withJSONObject:out,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
 }
}
