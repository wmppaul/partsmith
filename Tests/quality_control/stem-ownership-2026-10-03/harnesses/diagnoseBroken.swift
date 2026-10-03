import Foundation
import CoreGraphics
import ImageIO

/// Independent source masks. Target envelopes come from the explicitly drawn
/// musical pixels BEFORE analysis, not from its component or crop decisions.
@main enum BoundaryControls {
    static let width=720, height=760, space=12, tops=[180,330,480], edge=600
    enum Kind: String, CaseIterable {
        case cleanBoundary, horizontalBreaks, verticalBreak, parallelPaths
        case edgeMusicFullHeight, edgeMusicNearEdge, edgeMusicBroken
        case headAtJunction, sharedStemIntoGap, attachedSlur, ledgerAliases
        var expectsSeparation: Bool {
            [.cleanBoundary,.horizontalBreaks,.verticalBreak,.parallelPaths,.headAtJunction,.sharedStemIntoGap,.attachedSlur].contains(self)
        }
    }
    struct Target: Codable { var owner:Int; var sourceEnvelope:[Double]; var crop:[Double]; var preserved:Bool }
    struct Result: Codable {
        var kind:String; var scale:Double; var tilt:Double; var bow:Double
        var imageSize:[Int]; var targets:[Target]; var allTargetsPreserved:Bool
        var expectsSeparation:Bool; var wholeNeighborCount:Int; var planCanApply:Bool
        var bounds:[[Double]]; var componentCount:Int
    }
    static func main() throws {
        let output=URL(fileURLWithPath:CommandLine.arguments[1])
        let images=CommandLine.arguments.count>2 ? URL(fileURLWithPath:CommandLine.arguments[2]) : nil
        if let images { try FileManager.default.createDirectory(at:images,withIntermediateDirectories:true) }
        let profile=ScoreExtractionProfile(parts:(0..<3).map { .init(id:"p\($0)",name:"Staff \($0+1)",staffCount:1) },cropMode:"compact")
        var results:[Result]=[]
        for kind in Kind.allCases { for scale in [0.5,1.0,1.5] { for tilt in [-1.5,0.0,1.5] { for bow in [-10.0,0.0,10.0] {
            guard kind == .edgeMusicBroken && scale == 0.5 && tilt == 1.5 && bow == 0 else { continue }
            var pixels=[UInt8](repeating:255,count:width*height)
            var musicalOwners=[UInt8](repeating:0,count:width*height)
            func mark(_ x:Int,_ y:Int,_ owners:UInt8=0) {
                guard x>=0,x<width,y>=0,y<height else { return }
                pixels[y*width+x]=0;musicalOwners[y*width+x] |= owners
            }
            func rect(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ owners:UInt8=0) {
                for y in y0..<y1 { for x in x0..<x1 { mark(x,y,owners) } }
            }
            func erase(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int) {
                for y in y0..<y1 { for x in x0..<x1 { pixels[y*width+x]=255;musicalOwners[y*width+x]=0 } }
            }
            func head(_ cx:Int,_ cy:Int,_ owners:UInt8) {
                for y in (cy-4)..<(cy+4) { for x in (cx-8)..<(cx+8) {
                    let a=(Double(x-cx)+0.5)/8,b=(Double(y-cy)+0.5)/4
                    if a*a+b*b<=1 { mark(x,y,owners) }
                } }
            }
            for (i,top) in tops.enumerated() {
                for line in 0..<5 { rect(40,top+space*line,edge+3,top+space*line+1) }
                let x=160+70*i,owner=UInt8(1<<i)
                rect(x,top-20,x+3,top+27,owner);head(x-4,top+24,owner)
            }
            // Conventional left structural boundary is present in every case.
            // The tested right boundary or musical stem ends all three staves.
            rect(40,tops[0],43,tops[2]+49)
            switch kind {
            case .edgeMusicFullHeight,.edgeMusicNearEdge,.edgeMusicBroken,.ledgerAliases:
                let inset=kind == .edgeMusicNearEdge ? 8 : kind == .ledgerAliases ? 12 : 0
                rect(edge,180+inset,edge+3,529-inset,7)
                head(edge+1,184+inset,7);head(edge+1,525-inset,7)
                if kind == .edgeMusicBroken {
                    // A scan interruption in MUSIC must not turn it structural.
                    erase(edge,217,edge+3,225)
                }
                if kind == .ledgerAliases {
                    // The actual outer lines stop earlier; shifted ledger lines
                    // cannot inherit their identities merely by making five rows.
                    erase(525,180,604,181);erase(525,528,604,529)
                    rect(525,240,604,241,7);rect(525,468,604,469,7)
                }
            default: rect(edge,180,edge+3,529)
            }
            switch kind {
            case .horizontalBreaks:
                erase(550,192,edge,193);erase(550,204,edge,205)
                erase(570,342,edge,343)
            case .verticalBreak:
                erase(edge,519,edge+3,527)
            case .parallelPaths:
                // Right edge is clean and removable, but a second structural
                // path remains. A right-cut log is not proof of separation.
                rect(450,180,453,529);erase(450,217,453,225)
            case .headAtJunction:
                for (i,top) in tops.enumerated() {
                    let owner=UInt8(1<<i)
                    rect(edge,top-22,edge+3,top+26,owner)
                    head(edge-4,top+24,owner)
                }
            case .sharedStemIntoGap:
                // This upper musical stem shares the barline's pixels through
                // the gap. Clearing the bare boundary must not lose its head.
                rect(550,182,553,222,1);head(547,218,1)
                rect(550,211,edge+3,214,1);rect(edge,211,edge+3,300,1)
                for y in [240,252,264,276,288] { rect(588,y,613,y+1,1) }
                head(edge-4,296,1)
            case .attachedSlur:
                rect(520,190,523,223,1);head(517,219,1)
                for x in 522...edge {
                    let t=Double(x-522)/Double(edge-522)
                    let y=Int((223+73*t+16*sin(t*Double.pi)).rounded())
                    rect(x,y,x+1,y+3,1)
                }
            default: break
            }
            // Apply an explicit source-column transform to BOTH image and masks.
            // Native analysis receives candidates anchored at the page interior.
            var transformed=[UInt8](repeating:255,count:width*height)
            var ownership=[UInt8](repeating:0,count:width*height)
            for x in 0..<width {
                let shift=Int((tan(tilt*Double.pi/180)*(Double(x)-360)+bow*min(1,max(0,(Double(x)-360)/240))).rounded())
                for y in 0..<height where y+shift>=0 && y+shift<height {
                    transformed[(y+shift)*width+x]=pixels[y*width+x]
                    ownership[(y+shift)*width+x]=musicalOwners[y*width+x]
                }
            }
            let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:width,
                space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),
                provider:CGDataProvider(data:Data(transformed) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
            if let images,scale==1,tilt==0,bow==0 {
                let url=images.appendingPathComponent(kind.rawValue+".png")
                let destination=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
                CGImageDestinationAddImage(destination,image,nil);CGImageDestinationFinalize(destination)
            }
            let w=Int(Double(width)*scale),h=Int(Double(height)*scale)
            var analysisImage=image
            if scale != 1 {
                let context=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w,
                    space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
                context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:w,height:h))
                context.interpolationQuality = .high;context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
                analysisImage=context.makeImage()!
            }
            let candidates=tops.enumerated().map { i,top in
                StaffBandCandidate(id:i,staffLineFractions:(0..<5).map { Double(top+$0*space)/Double(height) },
                    topFraction:Double(top-3*space)/Double(height),bottomFraction:Double(top+7*space)/Double(height),confidence:1,warnings:[])
            }
            let ink=NativeScorePageAnalyzer.notationComponents(image:analysisImage,candidates:candidates,skewDegrees:tilt)!
            let page=ScorePageAnalysis(pageIndex:0,pageWidth:Double(width),pageHeight:Double(height),imageWidth:w,imageHeight:h,
                staves:candidates.map(ScoreObservedStaff.init),warnings:[],analysisSkewDegrees:tilt,inkComponents:ink)
            let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
            let ie=JSONEncoder();ie.outputFormatting=[.prettyPrinted,.sortedKeys]
            try ie.encode(page).write(to:output.deletingPathExtension().appendingPathExtension("page.json"))
            let bounds=plan.bands.map { [$0.leftFraction*Double(width),$0.topFraction*Double(height),(1-$0.rightFraction)*Double(width),$0.bottomFraction*Double(height)] }
            var targets:[Target]=[]
            for owner in 0..<3 {
                var x0=width,y0=height,x1=0,y1=0
                for y in 0..<height { for x in 0..<width where ownership[y*width+x] & UInt8(1<<owner) != 0 {
                    x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1)
                } }
                let envelope=[Double(x0),Double(y0),Double(x1),Double(y1)]
                let band=plan.bands.firstIndex { $0.partID == "p\(owner)" }
                let crop=band.map { bounds[$0] } ?? []
                let retained=crop.count==4 && crop[0]<=envelope[0]+1e-9 && crop[1]<=envelope[1]+1e-9 && crop[2]>=envelope[2]-1e-9 && crop[3]>=envelope[3]-1e-9
                targets.append(.init(owner:owner,sourceEnvelope:envelope,crop:crop,preserved:retained))
            }
            var neighbors=0
            for band in plan.bands {
                let owner=Int(band.partID.dropFirst())!
                for i in 0..<3 where i != owner {
                    if band.topFraction*Double(height)<=Double(tops[i]) && band.bottomFraction*Double(height)>=Double(tops[i]+48) { neighbors+=1 }
                }
            }
            results.append(.init(kind:kind.rawValue,scale:scale,tilt:tilt,bow:bow,imageSize:[w,h],targets:targets,
                allTargetsPreserved:targets.allSatisfy(\.preserved),expectsSeparation:kind.expectsSeparation,
                wholeNeighborCount:neighbors,planCanApply:plan.canApply,bounds:bounds,componentCount:ink.count))
        } } } }
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(results).write(to:output)
        print("Source-defined cases: \(results.count); target-envelope failures: \(results.filter { !$0.allTargetsPreserved }.count)")
        print("Structural-only/readability cases with whole neighbors: \(results.filter { $0.expectsSeparation && $0.wholeNeighborCount>0 }.count)")
    }
}
