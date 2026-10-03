import Foundation
import CoreGraphics
import ImageIO
import PDFKit

/// Authored source geometry and ownership are the oracle. The analyzer's
/// components, crop bounds and terminal-body dimensions never define a target.
@main enum TerminalBodyControls {
    static let width = 720, height = 600, space = 14, tops = [170, 340], spine = 500
    enum Kind: String, CaseIterable {
        case filledOuter, hollowOuter, mixedOuter
        case filledIncomingTie, filledOutgoingTie, filledLowerTie, hollowIncomingTie
        case filledFirstSpace, hollowFirstSpace, hollowSecondLine
        case filledStemInterrupted, hollowStemInterrupted
        case filledStaffInterrupted, hollowStaffInterrupted
        case bareBarline, attachedTie, attachedSlur, tieAcrossBarline, slurAcrossBarline
        case tieStaffInterrupted, slurStaffInterrupted, tieBarlineInterrupted
        case filledAtJunction, hollowAtJunction
        var musical: Bool {
            switch self {
            case .bareBarline,.attachedTie,.attachedSlur,.tieAcrossBarline,.slurAcrossBarline,.tieStaffInterrupted,.slurStaffInterrupted,.tieBarlineInterrupted,.filledAtJunction,.hollowAtJunction: return false
            default: return true
            }
        }
        var mixedJunction: Bool { self == .filledAtJunction || self == .hollowAtJunction }
    }
    struct Transform: Codable { var name:String; var tilt:Double; var bow:Double }
    struct Target: Codable { var owner:Int; var envelope:[Double]; var crop:[Double]; var sourcePixelCount:Int; var sourcePixelsOutsideCrop:Int; var preserved:Bool }
    struct Record: Codable {
        var name:String; var kind:String; var sourceClass:String; var transform:Transform; var rasterScale:Double
        var sourceImage:String; var ownerMasks:[String]; var analysisImageSize:[Int]
        var targets:[Target]; var allMusicalTargetsPreserved:Bool
        var expectedSharedMusicalConnection:Bool; var expectedStructuralSeparation:Bool
        var observedSharedComponentsAtTestedSpine:[ScoreInkComponent]; var observedAlternativesAtTestedSpine:[ScoreInkComponent]
        var wholeNeighborCount:Int; var planCanApply:Bool; var bands:[ScorePlannedBand]
    }
    static func image(_ data:[UInt8]) -> CGImage {
        CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:width,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),
            provider:CGDataProvider(data:Data(data) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    }
    static func save(_ image:CGImage, _ url:URL) {
        let destination=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,image,nil);precondition(CGImageDestinationFinalize(destination))
    }
    static func main() throws {
        precondition(CommandLine.arguments.count==3,"usage: controls results.json source-directory")
        let output=URL(fileURLWithPath:CommandLine.arguments[1]), sourceDir=URL(fileURLWithPath:CommandLine.arguments[2])
        try FileManager.default.createDirectory(at:sourceDir,withIntermediateDirectories:true)
        let transforms=[Transform(name:"straight",tilt:0,bow:0),Transform(name:"rotated",tilt:2,bow:0),Transform(name:"bowed",tilt:-1,bow:7)]
        let profile=ScoreExtractionProfile(parts:[.init(id:"upper",name:"Upper physical staff",staffCount:1),.init(id:"lower",name:"Lower physical staff",staffCount:1)],cropMode:"compact")
        var records:[Record]=[]
        for kind in [Kind.filledIncomingTie, .filledOutgoingTie, .filledLowerTie, .hollowIncomingTie] { for transform in transforms {
            var source=[UInt8](repeating:255,count:width*height), owners=[UInt8](repeating:0,count:width*height)
            func mark(_ x:Int,_ y:Int,_ owner:UInt8=0) {
                guard x>=0,x<width,y>=0,y<height else {return}
                source[y*width+x]=0; owners[y*width+x] |= owner
            }
            func rect(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ owner:UInt8=0) {
                for y in y0..<y1 { for x in x0..<x1 {mark(x,y,owner)} }
            }
            func erase(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int) {
                for y in y0..<y1 { for x in x0..<x1 { source[y*width+x]=255; owners[y*width+x]=0 } }
            }
            // Standard slanted elliptical notehead, with an actual white cavity
            // for half-note heads. The staff beneath remains visible through it.
            func head(_ cx:Double,_ cy:Double,_ hollow:Bool,_ owner:UInt8) {
                let angle = -Double.pi/12, c=cos(angle),s=sin(angle)
                for y in Int(cy-10)...Int(cy+10) { for x in Int(cx-13)...Int(cx+13) {
                    let dx=Double(x)+0.5-cx,dy=Double(y)+0.5-cy
                    let u=dx*c+dy*s,v = -dx*s+dy*c
                    let outer=u*u/100+v*v/36<=1
                    let inner=u*u/56.25+v*v/12.25<1
                    if outer && (!hollow || !inner) {mark(x,y,owner)}
                } }
            }
            func curve(_ x0:Int,_ y0:Double,_ x1:Int,_ y1:Double,_ arch:Double,_ owner:UInt8) {
                for x in x0...x1 {
                    let t=Double(x-x0)/Double(x1-x0), y=y0+(y1-y0)*t-arch*4*t*(1-t)
                    // Two source rows describe a printed curve, not a solid block.
                    let row=Int(y.rounded());rect(x,row,x+1,row+2,owner)
                }
            }
            for (i,top) in tops.enumerated() {
                for line in 0..<5 {rect(40,top+line*space,650,top+line*space+1)}
                let x=150+i*60,owner=UInt8(1<<i)
                rect(x,top-23,x+3,top+31,owner);head(Double(x-7),Double(top+28),false,owner)
            }
            rect(40,tops[0],43,tops[1]+4*space+1)
            let last=tops[1]+4*space
            if kind.musical {
                let inset:Double = [.filledFirstSpace,.hollowFirstSpace].contains(kind) ? 7 : kind == .hollowSecondLine ? 14 : 0
                let top=Double(tops[0])+inset,bottom=Double(last)-inset
                // One source-authored cross-staff chord: both physical staff
                // views must retain its complete musical envelope. This does
                // not assert two separate instruments own the same chord.
                rect(spine,Int(top),spine+3,Int(bottom)+1,3)
                let upperHollow=[.hollowOuter,.mixedOuter,.hollowFirstSpace,.hollowSecondLine,.hollowStemInterrupted,.hollowStaffInterrupted,.hollowIncomingTie].contains(kind)
                let lowerHollow=upperHollow && kind != .mixedOuter
                head(Double(spine+9),top,upperHollow,3)
                head(Double(spine-7),bottom,lowerHollow,3)
                // Supplement: an actual musical notehead can share its stem
                // junction with a long tie. Both source masks retain that tie.
                if kind == .filledIncomingTie || kind == .hollowIncomingTie {
                    curve(400,top+5,spine+1,top+4,18,3)
                } else if kind == .filledOutgoingTie {
                    curve(spine+9,top+3,620,top+4,18,3)
                } else if kind == .filledLowerTie {
                    curve(spine+1,bottom-3,615,bottom-1,-18,3)
                }
                if [.filledStemInterrupted,.hollowStemInterrupted].contains(kind) {erase(spine,201,spine+3,204)}
                if [.filledStaffInterrupted,.hollowStaffInterrupted].contains(kind) {
                    // Erase horizontal scan gaps outside the head, not music.
                    erase(452,tops[0],482,tops[0]+1);erase(521,last,551,last+1)
                }
            } else {
                rect(spine,tops[0],spine+3,last+1)
                switch kind {
                case .attachedTie,.tieAcrossBarline,.tieStaffInterrupted,.tieBarlineInterrupted:
                    // A lower-staff tie enters a continuing structural stroke.
                    // Its complete long curve belongs only to the lower staff.
                    head(409,Double(last-3),false,2);rect(417,last-40,420,last-2,2)
                    curve(410,Double(last-8),kind == .tieAcrossBarline ? 526 : spine+1,Double(last-3),12,2)
                    if kind == .tieStaffInterrupted {erase(461,last,480,last+1)}
                    if kind == .tieBarlineInterrupted {erase(spine,368,spine+3,370)}
                case .attachedSlur,.slurAcrossBarline,.slurStaffInterrupted:
                    head(407,Double(tops[0]+7),false,1);rect(397,tops[0]+8,400,tops[0]+46,1)
                    curve(410,Double(tops[0]+4),kind == .slurAcrossBarline ? 526 : spine+1,Double(tops[0]+3),10,1)
                    if kind == .slurStaffInterrupted {erase(455,tops[0],480,tops[0]+1)}
                case .filledAtJunction,.hollowAtJunction:
                    // Local note stem shares pixels with a longer barline.
                    // Its complete local head/stem must survive. Whether the
                    // global stroke can be separated is intentionally optional.
                    rect(spine,last-35,spine+3,last+1,2)
                    head(Double(spine-7),Double(last),kind == .hollowAtJunction,2)
                default: break
                }
            }
            var transformed=[UInt8](repeating:255,count:width*height), ownership=[UInt8](repeating:0,count:width*height)
            for x in 0..<width {
                let ramp=min(1,max(0,(Double(x)-360)/240))
                let shift=Int((tan(transform.tilt * .pi/180)*(Double(x)-360)+transform.bow*ramp*ramp).rounded())
                for y in 0..<height where y+shift>=0 && y+shift<height {
                    transformed[(y+shift)*width+x]=source[y*width+x];ownership[(y+shift)*width+x]=owners[y*width+x]
                }
            }
            let name=kind.rawValue+"-"+transform.name, sourceImage=image(transformed)
            let path=sourceDir.appendingPathComponent(name+".png");save(sourceImage,path)
            var masks:[String]=[], envelopes:[[Double]]=[]
            for owner in 0..<2 {
                var x0=width,y0=height,x1=0,y1=0, mask=[UInt8](repeating:255,count:width*height)
                for y in 0..<height {for x in 0..<width where ownership[y*width+x] & UInt8(1<<owner) != 0 {
                    x0=min(x0,x);y0=min(y0,y);x1=max(x1,x+1);y1=max(y1,y+1);mask[y*width+x]=0
                }}
                envelopes.append([Double(x0),Double(y0),Double(x1),Double(y1)])
                let maskPath=sourceDir.appendingPathComponent(name+"-owner\(owner).png");save(image(mask),maskPath);masks.append(maskPath.path)
            }
            for scale in [0.5,1.0,1.5] {
                let w=Int(Double(width)*scale),h=Int(Double(height)*scale)
                let context=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
                context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:w,height:h));context.interpolationQuality = .high
                context.draw(sourceImage,in:CGRect(x:0,y:0,width:w,height:h));let analyzed=context.makeImage()!
                let candidates=tops.enumerated().map {i,t in StaffBandCandidate(id:i,staffLineFractions:(0..<5).map {Double(t+$0*space)/Double(height)},topFraction:Double(t-3*space)/Double(height),bottomFraction:Double(t+7*space)/Double(height),confidence:1,warnings:[])}
                let components=NativeScorePageAnalyzer.notationComponents(image:analyzed,candidates:candidates,skewDegrees:transform.tilt)!
                let page=ScorePageAnalysis(pageIndex:0,pageWidth:Double(width),pageHeight:Double(height),imageWidth:w,imageHeight:h,staves:candidates.map(ScoreObservedStaff.init),warnings:[],analysisSkewDegrees:transform.tilt,inkComponents:components)
                let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
                var targets:[Target]=[],neighbors=0
                for owner in 0..<2 {
                    let b=plan.bands.first {$0.partID == (owner==0 ? "upper":"lower")}!
                    let crop=[b.leftFraction*Double(width),b.topFraction*Double(height),(1-b.rightFraction)*Double(width),b.bottomFraction*Double(height)]
                    var count=0,lost=0
                    for y in 0..<height {for x in 0..<width where ownership[y*width+x] & UInt8(1<<owner) != 0 {
                        count+=1
                        if Double(x)<crop[0]-1e-9 || Double(y)<crop[1]-1e-9 || Double(x+1)>crop[2]+1e-9 || Double(y+1)>crop[3]+1e-9 {lost+=1}
                    }}
                    targets.append(.init(owner:owner,envelope:envelopes[owner],crop:crop,sourcePixelCount:count,sourcePixelsOutsideCrop:lost,preserved:lost==0))
                    let neighbor=1-owner
                    if crop[1]<=Double(tops[neighbor]) && crop[3]>=Double(tops[neighbor]+4*space) {neighbors+=1}
                }
                let cross=components.filter {$0.staffIDs==[0,1] && $0.bounds[0]<=Double(spine+2)/Double(width) && $0.bounds[2]>=Double(spine)/Double(width) && $0.bounds[1]<0.45 && $0.bounds[3]>0.5}
                records.append(.init(name:name+"-r\(scale)",kind:kind.rawValue,sourceClass:kind.musical ? "musical-long-stem" : kind.mixedJunction ? "mixed-local-note-and-barline" : "structural-barline-with-owned-curve",transform:transform,rasterScale:scale,sourceImage:path.path,ownerMasks:masks,analysisImageSize:[w,h],targets:targets,allMusicalTargetsPreserved:targets.allSatisfy(\.preserved),expectedSharedMusicalConnection:kind.musical,expectedStructuralSeparation:!kind.musical && !kind.mixedJunction,observedSharedComponentsAtTestedSpine:cross,observedAlternativesAtTestedSpine:cross.filter {$0.isOwnershipAlternative==true},wholeNeighborCount:neighbors,planCanApply:plan.canApply,bands:plan.bands))
            }
        }}
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(records).write(to:output)
        print("\(records.count) cases; \(records.filter {!$0.allMusicalTargetsPreserved}.count) target-envelope failures; \(records.filter {$0.expectedStructuralSeparation && $0.wholeNeighborCount>0}.count) structural cases retain whole neighbor cores")
    }
}
