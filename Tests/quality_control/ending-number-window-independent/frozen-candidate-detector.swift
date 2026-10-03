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
    struct PageResult: Codable {
        var pageIndex: Int
        var ownershipVerified: Bool
        var systemIndices: [Int]
        var geometryProposalCount: Int
        var mergedProposalCount: Int
        var candidates: [Candidate]
    }
    struct Pair: Codable { var first: Candidate; var second: Candidate }
    struct Raster {
        var width: Int; var height: Int; var pixels: [UInt8]
        init?(image: CGImage) {
            width = image.width; height = image.height
            guard let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            c.setFillColor(gray: 1, alpha: 1); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
            c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let data = c.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
            pixels = Array(UnsafeBufferPointer(start: data, count: width * height))
        }
        init(width: Int, height: Int, pixels: [UInt8]) { self.width=width; self.height=height; self.pixels=pixels }
        func black(_ x: Int, _ y: Int) -> Bool { pixels[y * width + x] < 170 }
        func hasInk(x: Int, y: Int) -> Bool {
            (max(0,x-1)..<min(width,x+2)).contains { black($0,y) }
        }
        func numberImage(_ b: [Int]) -> CGImage? {
            let w=b[2]-b[0],h=b[3]-b[1]
            guard w>0,h>0,b[0]>=0,b[1]>=0,b[2]<=width,b[3]<=height else{return nil}
            var values:[UInt8]=[]; values.reserveCapacity(w*h)
            for y in b[1]..<b[3] { values.append(contentsOf:pixels[(y*width+b[0])..<(y*width+b[2])]) }
            guard let provider=CGDataProvider(data:Data(values) as CFData),
                let original=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:w,
                    space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.none.rawValue),
                    provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent),
                let c=CGContext(data:nil,width:w*4+120,height:h*4+120,bitsPerComponent:8,bytesPerRow:0,
                    space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else{return nil}
            c.setFillColor(gray:1,alpha:1);c.fill(CGRect(x:0,y:0,width:w*4+120,height:h*4+120));c.interpolationQuality = .high
            c.draw(original,in:CGRect(x:60,y:60,width:w*4,height:h*4));return c.makeImage()
        }
    }
    struct Proposal {
        var x0:Int;var x1:Int;var y:Int;var hookX:Int;var hookBottom:Int;var support:Double
    }
    struct System {
        var index:Int;var first:ScoreObservedStaff;var previous:ScoreObservedStaff?
    }
    static func systems(page:ScorePageAnalysis,profile:ScoreExtractionProfile,isCancelled:()->Bool) -> [System]? {
        guard page.pageWidth.isFinite,page.pageWidth>0,page.pageHeight.isFinite,page.pageHeight>0,
            page.staves.allSatisfy({ s in
                let a=s.staffLineFractions;return a.count==5 && a.allSatisfy{$0.isFinite && $0>=0 && $0<=1}
                && zip(a,a.dropFirst()).allSatisfy{$0<$1}
            }),Set(page.staves.map(\.id)).count==page.staves.count else{return nil}
        if page.staves.isEmpty{return []}
        var p=page;p.sharedHeadings=nil;p.sharedNavigation=nil;p.sharedEndings=nil
        let plan=ScoreExtractionPlanner.plan(pages:[p],profile:profile,isCancelled:isCancelled)
        guard plan.canApply,!isCancelled() else{return nil}
        let bands=plan.bands.filter{$0.pageIndex==page.pageIndex && $0.kind=="music"}
        let ids=bands.flatMap(\.candidateIDs)
        guard ids.count==Set(ids).count,Set(ids)==Set(page.staves.map(\.id)) else{return nil}
        let grouped=Dictionary(grouping:bands,by:\.systemIndex),ordered=page.staves.sorted{$0.staffLineFractions[0]<$1.staffLineFractions[0]}
        return grouped.keys.sorted().compactMap { system in
            let owned=Set(grouped[system]!.flatMap(\.candidateIDs))
            guard let first=ordered.firstIndex(where:{owned.contains($0.id)}) else{return nil}
            return System(index:system,first:ordered[first],previous:first>0 ? ordered[first-1]:nil)
        }
    }
    /// Straight or gently raster-stepped thin line with a descending left hook.
    static func proposals(raster r:Raster,space:Double,top:Int,bottom:Int,isCancelled:()->Bool={false}) -> [Proposal] {
        guard space.isFinite,space>0,top>=0,bottom<=r.height,bottom>top else{return []}
        let radius=max(1,Int(space*0.1)),gap=max(1,Int(space*0.08))
        guard bottom-top>radius*2 else{return []}
        var result:[Proposal]=[]
        for y in (top+radius)..<(bottom-radius) {
            if isCancelled(){return []}
            var hits:[Int]=[]
            for x in 0..<r.width {
                if ((y-radius)...(y+radius)).contains(where:{r.black(x,$0)}) {hits.append(x)}
            }
            var runs:[(Int,Int)]=[]
            for x in hits {
                if let last=runs.last,x-last.1<=gap {runs[runs.count-1].1=x+1}
                else{runs.append((x,x+1))}
            }
            for (x0,x1) in runs where Double(x1-x0)>=space*4 {
                let support=Double((x0..<x1).filter{r.black($0,y)}.count)/Double(x1-x0)
                guard support>=0.68 else{continue}
                var ink=0
                for yy in (y-radius)...(y+radius){for x in x0..<x1 where r.black(x,yy){ink+=1}}
                guard Double(ink)/Double(x1-x0)<=space*0.38 else{continue}
                var best:(length:Int,x:Int,last:Int)?
                for x in max(0,Int(Double(x0)-space*0.25))..<min(r.width,Int(Double(x0)+space*0.35)+1) {
                    var last=y,misses=0
                    let limit=min(bottom,Int(Double(y)+space*4))
                    if y+radius+1>=limit{continue}
                    for yy in (y+radius+1)..<limit {
                        if r.hasInk(x:x,y:yy){last=yy;misses=0}else{misses+=1}
                        if misses>gap{break}
                    }
                    let length=last-y
                    if Double(length)>=space*0.7 && Double(length)<=space*3.1,
                        best == nil || length>best!.length || (length==best!.length && x>best!.x){best=(length,x,last)}
                }
                guard let b=best else{continue}
                let p=Proposal(x0:x0,x1:x1,y:y,hookX:b.x,hookBottom:b.last,support:support)
                if let i=result.firstIndex(where:{abs(Double($0.y-y))<=space*0.45 && abs(Double($0.x0-x0))<=space*0.4 && abs(Double($0.x1-x1))<=space*0.4}) {
                    if support>result[i].support{result[i]=p}
                }else{result.append(p)}
            }
        }
        return result
    }
    static func analyze(in image:CGImage,page:ScorePageAnalysis,profile:ScoreExtractionProfile,
        observedFailure:((Error)->Void)?=nil,isCancelled:()->Bool={false}) -> PageResult {
        let empty=PageResult(pageIndex:page.pageIndex,ownershipVerified:false,systemIndices:[],geometryProposalCount:0,mergedProposalCount:0,candidates:[])
        guard !isCancelled(),let systems=systems(page:page,profile:profile,isCancelled:isCancelled),let r=Raster(image:image) else{return empty}
        var result=PageResult(pageIndex:page.pageIndex,ownershipVerified:true,systemIndices:systems.map(\.index),geometryProposalCount:0,mergedProposalCount:0,candidates:[])
        let sx=Double(r.width)/page.pageWidth,sy=Double(r.height)/page.pageHeight
        for system in systems {
            guard !isCancelled() else{return empty}
            let lines=system.first.staffLineFractions,space=(lines[4]-lines[0])*Double(r.height)/4,sp=space/sy
            let top=lines[0]*Double(r.height),previous=system.previous.map{$0.staffLineFractions[4]*Double(r.height)+space*0.1} ?? 0
            let y0=max(0,Int(max(previous,top-space*14))),y1=min(r.height,Int(top-space*0.12))
            guard Double(y1-y0)>=space else{continue}
            var groups:[Candidate]=[]
            for p in proposals(raster:r,space:space,top:y0,bottom:y1,isCancelled:isCancelled) {
                guard !isCancelled() else{return empty}
                let x0=Double(p.x0),y=Double(p.y),x1=Double(p.x1),hb=Double(p.hookBottom)
                let b=[max(0,x0-space*0.3)/sx,max(0,y-space*0.3)/sy,min(Double(r.width),x1+space*0.3)/sx,min(Double(r.height),max(y+space*2.35,hb+space*0.25))/sy]
                let nb=[max(0,Int(x0+space*0.4)),max(0,Int(y+space*0.15)),min(r.width,Int(x0+space*3.3)),min(y1,Int(max(y+space*2.2,hb+space*0.15)))]
                guard nb[2]>nb[0],nb[3]>nb[1],let number=r.numberImage(nb) else{continue}
                result.geometryProposalCount+=1
                var evidence:[TextEvidence]=[]
                for mode in ["accurate","fast"] {
                    guard !isCancelled() else{return empty}
                    let request=VNRecognizeTextRequest();request.recognitionLevel=mode=="fast" ? .fast:.accurate
                    request.usesLanguageCorrection=false;request.minimumTextHeight=0.06;request.recognitionLanguages=["en-US"]
                    do {try VNImageRequestHandler(cgImage:number,options:[:]).perform([request])}
                    catch{observedFailure?(error);return empty}
                    if let observations=request.results,observations.count==1,let t=observations[0].topCandidates(1).first {
                        let box=observations[0].boundingBox
                        evidence.append(TextEvidence(mode:mode,text:t.string,confidence:t.confidence,bounds:[box.minX,1-box.maxY,box.maxX,1-box.minY]))
                    }
                }
                var c=Candidate(pageIndex:page.pageIndex,systemIndex:system.index,anchorStaffID:system.first.id,bounds:b,copyBounds:[],numberBounds:[Double(nb[0])/sx,Double(nb[1])/sy,Double(nb[2])/sx,Double(nb[3])/sy],staffSpace:sp,pageWidth:page.pageWidth,pageHeight:page.pageHeight,closedRight:false,rightHookBottom:nil,evidence:evidence,memberCount:1)
                // Scratch candidate: retry only unrecognized geometry with a wider
                // accurate OCR window; retain existing candidates and copy bounds.
                if c.role == nil {
                    let wide = [nb[0], nb[1], min(r.width, Int(x0 + space * 4.8)), nb[3]]
                    if let number = r.numberImage(wide) {
                        let request = VNRecognizeTextRequest()
                        request.recognitionLevel = .accurate
                        request.usesLanguageCorrection = false
                        request.minimumTextHeight = 0.06
                        request.recognitionLanguages = ["en-US"]
                        do { try VNImageRequestHandler(cgImage: number, options: [:]).perform([request]) }
                        catch { observedFailure?(error); return empty }
                        if let observations = request.results, observations.count == 1,
                           let t = observations[0].topCandidates(1).first,
                           t.confidence >= 0.5,
                           ["1", "2"].contains(t.string.trimmingCharacters(in: CharacterSet(charactersIn: " ."))) {
                            let box = observations[0].boundingBox
                            c.evidence.append(.init(mode: "accurate-wide", text: t.string, confidence: t.confidence,
                                bounds: [box.minX, 1-box.maxY, box.maxX, 1-box.minY]))
                            c.numberBounds = [Double(wide[0])/sx, Double(wide[1])/sy, Double(wide[2])/sx, Double(wide[3])/sy]
                        }
                    }
                }
                if let i=groups.firstIndex(where:{g in
                    abs(g.bounds[0]-b[0])<sp*0.4 && abs(g.bounds[1]-b[1])<sp*0.5 && min(g.bounds[2],b[2])-max(g.bounds[0],b[0])>0.8*min(g.bounds[2]-g.bounds[0],b[2]-b[0])
                }) {
                    groups[i].bounds=[min(groups[i].bounds[0],b[0]),min(groups[i].bounds[1],b[1]),max(groups[i].bounds[2],b[2]),max(groups[i].bounds[3],b[3])]
                    groups[i].evidence+=evidence;groups[i].memberCount+=1
                }else{groups.append(c)}
            }
            if page.pageIndex == 20, let data = try? JSONEncoder().encode(groups), let text = String(data: data, encoding: .utf8) {
                print("DIAGNOSTIC system \(system.index): \(text)")
            }
            result.mergedProposalCount+=groups.count
            for var g in groups where g.role != nil {
                let start=(g.bounds[1]+sp*0.3)*sy,end=(g.bounds[2]-sp*0.3)*sx
                var best=0
                for x in max(0,Int(end-space*0.4))..<min(r.width,Int(end+space*0.4)+1) {
                    var last=Int(start),miss=0
                    let from=Int(start+space*0.2),to=min(r.height,Int(start+space*3.5))
                    if from>=to{continue}
                    for y in from..<to {
                        if r.hasInk(x:x,y:y){last=y;miss=0}else{miss+=1}
                        if miss>max(1,Int(space*0.08)){break}
                    }
                    if Double(last)-start>=space*0.65{best=max(best,last)}
                }
                g.closedRight=best>0;g.rightHookBottom=best>0 ? Double(best)/sy:nil
                g.copyBounds=[max(0,g.bounds[0]-sp*0.35),max(0,g.bounds[1]-sp*0.35),min(page.pageWidth,g.bounds[2]+sp*0.35),min(page.pageHeight,max(g.bounds[3],g.rightHookBottom.map{$0+sp*0.35} ?? g.bounds[3])+sp*0.25)]
                result.candidates.append(g)
            }
        }
        return isCancelled() ? empty:result
    }
    static func pairable(_ first:Candidate,_ second:Candidate,systemGap:Int) -> Bool {
        guard first.role=="first",second.role=="second",first.closedRight,
            first.bounds.count==4,second.bounds.count==4,first.bounds.allSatisfy(\.isFinite),second.bounds.allSatisfy(\.isFinite),
            first.staffSpace>0,second.staffSpace>0 else{return false}
        let sp=max(first.staffSpace,second.staffSpace)
        if systemGap==0 {return first.pageIndex==second.pageIndex && first.systemIndex==second.systemIndex && first.anchorStaffID==second.anchorStaffID && abs(second.bounds[0]-first.bounds[2])<=sp*1.8 && abs(first.bounds[1]-second.bounds[1])<=sp*1.2}
        if systemGap==1{return first.bounds[2]>0.7*first.pageWidth && second.bounds[0]<0.4*second.pageWidth}
        return false
    }
    static func pairs(in pages:[PageResult],isCancelled:()->Bool={false}) -> [Pair] {
        guard !isCancelled(),Set(pages.map(\.pageIndex)).count==pages.count else{return []}
        var order:[String:Int]=[:],ordinal=0,candidates:[Candidate]=[]
        var previousPageIndex:Int?
        func key(_ page:Int,_ system:Int)->String{"\(page):\(system)"}
        for p in pages.sorted(by:{$0.pageIndex<$1.pageIndex}) {
            // Missing input pages have unknown systems. Never compress the gap
            // into apparent adjacency between unrelated printed endings.
            if let previous=previousPageIndex,p.pageIndex>previous+1{ordinal+=2}
            previousPageIndex=p.pageIndex
            if !p.ownershipVerified {ordinal+=2;continue}
            for s in p.systemIndices.sorted(){order[key(p.pageIndex,s)]=ordinal;ordinal+=1}
            candidates+=p.candidates.filter{$0.pageIndex==p.pageIndex && p.systemIndices.contains($0.systemIndex)}
        }
        var potential:[(Int,Int)]=[]
        for i in candidates.indices where candidates[i].role=="first" {
            if isCancelled(){return []}
            for j in candidates.indices where candidates[j].role=="second" {
                guard let a=order[key(candidates[i].pageIndex,candidates[i].systemIndex)],let b=order[key(candidates[j].pageIndex,candidates[j].systemIndex)] else{continue}
                if pairable(candidates[i],candidates[j],systemGap:b-a){potential.append((i,j))}
            }
        }
        // A second ending cannot validate two different first endings.
        let result=potential.filter {p in potential.filter{$0.0==p.0}.count==1 && potential.filter{$0.1==p.1}.count==1}
            .map{Pair(first:candidates[$0.0],second:candidates[$0.1])}
        return isCancelled() ? []:result
    }
}

enum ScoreSharedEndingMetadata {
    static func make(pairs: [ScoreSharedEndingDetector.Pair], pages: [ScorePageAnalysis],
                     isCancelled: () -> Bool = { false }) -> [Int: [ScoreSharedEnding]] {
        guard Set(pages.map(\.pageIndex)).count == pages.count else { return [:] }
        let byPage = Dictionary(uniqueKeysWithValues: pages.map { ($0.pageIndex, $0) })
        var result: [Int: [ScoreSharedEnding]] = [:]
        for pair in pairs {
            guard !isCancelled() else { return [:] }
            var members: [ScoreEndingMember] = []
            for (candidate, role) in [(pair.first, ScoreEndingMember.Role.first), (pair.second, .second)] {
                guard let page = byPage[candidate.pageIndex],
                      candidate.pageWidth == page.pageWidth, candidate.pageHeight == page.pageHeight,
                      page.pageWidth.isFinite, page.pageWidth > 0, page.pageHeight.isFinite, page.pageHeight > 0,
                      candidate.copyBounds.count == 4, candidate.copyBounds.allSatisfy(\.isFinite),
                      page.staves.contains(where: { $0.id == candidate.anchorStaffID }) else { break }
                let r = candidate.copyBounds
                let normalized = [r[0] / page.pageWidth, r[1] / page.pageHeight,
                                  r[2] / page.pageWidth, r[3] / page.pageHeight]
                guard ScoreSharedEnding.validBounds(normalized) else { break }
                members.append(.init(sourcePageIndex: candidate.pageIndex, sourceSystemIndex: candidate.systemIndex,
                    anchorStaffID: candidate.anchorStaffID, bounds: normalized, role: role,
                    evidence: candidate.evidence.map { .init(mode: $0.mode, text: $0.text,
                        confidence: $0.confidence, bounds: $0.bounds) }))
            }
            guard members.count == 2 else { continue }
            let grouped = Dictionary(grouping: members) { "\($0.sourcePageIndex):\($0.sourceSystemIndex):\($0.anchorStaffID)" }
            for key in grouped.keys.sorted() {
                let local = grouped[key]!, anchor = local[0]
                let ending = ScoreSharedEnding(sourcePageIndex: anchor.sourcePageIndex,
                    anchorStaffID: anchor.anchorStaffID, systemIndex: anchor.sourceSystemIndex,
                    bounds: ScoreSharedEnding.union(local.map(\.bounds)), members: members)
                result[anchor.sourcePageIndex, default: []].append(ending)
            }
        }
        return isCancelled() ? [:] : result
    }
}
