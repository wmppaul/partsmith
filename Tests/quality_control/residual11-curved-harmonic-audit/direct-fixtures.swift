import Foundation
import CoreGraphics
import PDFKit

/// Regressions for analysis-only structural separation. The fixture pixels
/// remain the independent source; expected notation extents are not derived
/// from the component boxes returned by the analyzer.
enum Probe {
    static var row:[String:Any]=[:], records:[[String:Any]]=[]
    static var targetImage:CGImage!, targetBounds:[Double]=[], anchors:[[Double]]=[]
    static func prepare(scale:Double,tilt:Double,bow:Double) {
        row=["scale":scale,"tilt":tilt,"bow":bow,"cuts":[[String:Any]]()]
        let width=720,height=600,slope=tan(tilt * .pi / 180)
        var pixels=[UInt8](repeating:255,count:width*height),points:[(Int,Int)]=[]
        for x in 443..<459 {
            let shift=Int((slope*(Double(x)-360)+bow).rounded())
            for y in 212..<387 where (x>=450 && x<453) || y<220 || y>=379 {
                pixels[(y+shift)*width+x]=0;points.append((x,y+shift))
            }
        }
        targetBounds=[Double(points.map(\.0).min()!)/720,Double(points.map(\.1).min()!)/600,
                      Double(points.map(\.0).max()!+1)/720,Double(points.map(\.1).max()!+1)/600]
        let shift=Double(Int((slope*91+bow).rounded()))
        anchors=[[451.0/720,(216+shift)/600],[451.0/720,(383+shift)/600]]
        let provider=CGDataProvider(data:Data(pixels) as CFData)!
        targetImage=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:width,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    }
    static func fit(staff:Int,shift:Int?,space:Double,accept:Bool) {
        var fits=(row["localFits"] as? [[String:Any]]) ?? []
        fits.append(["staff":staff,"shift":shift as Any? ?? NSNull(),"space":space,"absoluteShiftInSpaces":shift.map {Double(abs($0))/space} as Any? ?? NSNull(),"trustedLocally":accept])
        row["localFits"]=fits
    }
    static func cut(left:Double,unshifted:Bool,upper:Double,lower:Double,space:Double,localTilt:Double) {
        guard left>0.5 else{return}
        var cuts=row["cuts"] as! [[String:Any]]
        cuts.append(["path":unshifted ? "unshifted" : "fallback","upperShift":upper,"lowerShift":lower,"localTilt":localTilt,"staffSpace":space,
                     "upperFitInSpaces":(upper-localTilt)/space,"lowerFitInSpaces":(lower-localTilt)/space])
        row["cuts"]=cuts
    }
    static func measure(original:[Bool],ink:[Bool],width:Int,height:Int) {
        let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
        context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:width,height:height));context.interpolationQuality = .high
        context.draw(targetImage,in:CGRect(x:0,y:0,width:width,height:height))
        let raw=context.data!.assumingMemoryBound(to:UInt8.self)
        var targetCount=0,missing=0,missingRows:Set<Int>=[],stemMissingRows:Set<Int>=[]
        let stemLeft=Int(floor(450.0*Double(width)/720)),stemRight=Int(ceil(453.0*Double(width)/720))
        for y in 0..<height {
            var expectedStem=false,retainedStem=false
            for x in 0..<width where raw[y*width+x]<190 && original[y*width+x] {
                targetCount+=1
                if !ink[y*width+x] {missing+=1;missingRows.insert(y)}
                if x>=stemLeft && x<stemRight {expectedStem=true;if ink[y*width+x]{retainedStem=true}}
            }
            if expectedStem && !retainedStem {stemMissingRows.insert(y)}
        }
        row["targetMaskForegroundPixels"]=targetCount;row["targetPixelsAbsentFromAnalysis"]=missing
        row["targetRowsChangedInAnalysis"]=missingRows.sorted();row["stemRowsCompletelyAbsent"]=stemMissingRows.sorted()
        row["sourceTargetBounds"]=targetBounds;row["sourceAnchors"]=anchors
    }
    static func finish(components:[ScoreInkComponent],staves:[ScoreObservedStaff],tilt:Double,oldPass:Bool) {
        let tolerance=1.5/600
        let owner=components.filter { component in
            component.staffIDs == [0,1] && anchors.allSatisfy { point in
                point[0]>=component.bounds[0]-tolerance && point[0]<=component.bounds[2]+tolerance &&
                point[1]>=component.bounds[1]-tolerance && point[1]<=component.bounds[3]+tolerance
            }
        }
        let profile=ScoreExtractionProfile(parts:[ScorePartDefinition(id:"upper",name:"Upper",staffCount:1),ScorePartDefinition(id:"lower",name:"Lower",staffCount:1)],cropMode:"compact")
        let page=ScorePageAnalysis(pageIndex:0,pageWidth:720,pageHeight:600,imageWidth:720,imageHeight:600,staves:staves,warnings:[],analysisSkewDegrees:tilt,inkComponents:components)
        let plan=ScoreExtractionPlanner.plan(pages:[page],profile:profile)
        row["oldStrictWidthCheck"]=oldPass;row["sharedEndpointOwners"]=owner.map(\.bounds)
        row["planCanApply"]=plan.canApply
        row["crops"]=plan.bands.map { b in
            ["part":b.partID,"bounds":[b.leftFraction,b.topFraction,1-b.rightFraction,b.bottomFraction],
             "containsWholeSourceMusicalEnvelope":b.leftFraction<=targetBounds[0] && b.topFraction<=targetBounds[1] && 1-b.rightFraction>=targetBounds[2] && b.bottomFraction>=targetBounds[3]] as [String:Any]
        }
        records.append(row)
    }
}

@main struct CropQualityTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ description: String) {
        checks += 1
        guard value() else { fputs("FAIL: \(description)\n", stderr); exit(1) }
    }

    static func fixture(skewDegrees: Double = 0, notationBridge: Bool = false, wideBracket: Bool = false, narrowNotationBridge: Bool = false, rasterScale: Double = 1, localBow: Double = 0, nearFullNotationBridge: Bool = false, localBarline: Bool = false, harmonicBridge: Bool = false, continuousBow: Double = 0, continuousNotationBridge: Bool = false) -> ([ScoreInkComponent], [ScoreObservedStaff]) {
        let width = 720, height = 600, space = 12
        var pixels = [UInt8](repeating: 255, count: width * height)
        func black(_ left: Int, _ top: Int, _ right: Int, _ bottom: Int) {
            for y in top..<bottom { for x in left..<right { pixels[y * width + x] = 0 } }
        }
        var candidates: [StaffBandCandidate] = []
        for (index, top) in [200, 350].enumerated() {
            var fractions: [Double] = []
            for line in 0..<5 { fractions.append(Double(top + line * space) / Double(height)) }
            candidates.append(StaffBandCandidate(id: index, staffLineFractions: fractions,
                topFraction: Double(top - 3 * space) / Double(height),
                bottomFraction: Double(top + 7 * space) / Double(height), confidence: 1, warnings: []))
        }
        for top in [200, 350] {
            for line in 0..<5 { black(25, top + line * space, 700, top + line * space + 1) }
        }
        // The two strokes are separated on most rows. Each used to be mistaken
        // for a notation branch of the other, leaving the whole brace connected.
        let firstRight = wideBracket ? 32 : 24
        let secondLeft = wideBracket ? 37 : 29
        let secondRight = wideBracket ? 42 : 33
        black(20, 200, firstRight, 399)
        black(secondLeft, 200, secondRight, 399)
        black(20, 200, secondRight + 1, 202)
        black(20, 397, secondRight + 1, 399)
        black(160, 170, 164, 228)
        black(152, 221, 168, 229)
        black(162, 170, 206, 174)
        black(350, 379, 366, 387)
        black(362, 350, 366, 386)
        // A horizontal slur/direction touching the system line must survive the
        // analysis split; retain it even when it is detached from either staff.
        black(30, 283, 76, 286)
        if notationBridge {
            // A genuine wide cross-staff figure is not a structural line.
            black(450, 238, 454, 361)
            black(450, 273, 515, 278)
            black(511, 275, 515, 361)
            black(442, 238, 458, 245)
            black(504, 358, 520, 365)
        }
        if narrowNotationBridge {
            // The pair's dilated connector envelope is 26px, matching the wide
            // bracket above. It is still music: its stems enter only part of
            // each staff core, so the core-support requirement must reject it.
            black(450, 238, 460, 361)
            black(465, 275, 472, 361)
            black(450, 273, 472, 278)
            black(442, 238, 460, 245)
            black(466, 358, 480, 365)
        }
        if nearFullNotationBridge {
            // A long cross-staff stem still falls short of both outer staff
            // edges. Local staff curvature must not make it a structural
            // barline. The source noteheads establish musical ownership.
            black(450, 210, 453, 389)
            black(443, 209, 459, 217)
            black(443, 382, 459, 390)
        }
        if localBarline { black(continuousBow == 0 ? 450 : 680, 200, continuousBow == 0 ? 453 : 683, 399) }
        if continuousNotationBridge {
            black(600, 210, 603, 389)
            black(593, 209, 609, 217)
            black(593, 382, 609, 390)
        }
        if harmonicBridge {
            // Outer staff lines are interrupted near a long cross-staff stem.
            // Aligned ledger lines create a shifted five-line pattern, but
            // source noteheads make this musical ink, not a barline.
            for x in 380..<530 { pixels[200 * width + x] = 255; pixels[398 * width + x] = 255 }
            black(380, 260, 530, 261)
            black(380, 338, 530, 339)
            black(450, 212, 453, 387)
            black(443, 212, 459, 220)
            black(443, 379, 459, 387)
        }
        let slope = tan(skewDegrees * .pi / 180)
        if skewDegrees != 0 || localBow != 0 || continuousBow != 0 {
            let original = pixels
            pixels = [UInt8](repeating: 255, count: width * height)
            for x in 0..<width {
                // A local bend shifts the right-hand notation independently
                // of the page-wide skew and the detected central staff lines.
                let bow = localBow * min(1, max(0, (Double(x) - 300) / 100)) + continuousBow * min(1, max(0, (Double(x) - 360) / 240))
                let shift = Int((slope * (Double(x) - Double(width) / 2) + bow).rounded())
                for y in 0..<height where y + shift >= 0 && y + shift < height {
                    pixels[(y + shift) * width + x] = original[y * width + x]
                }
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        var analysisImage = image
        if rasterScale != 1 {
            let outputWidth = Int(Double(width) * rasterScale)
            let outputHeight = Int(Double(height) * rasterScale)
            let context = CGContext(data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 8,
                bytesPerRow: outputWidth, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            analysisImage = context.makeImage()!
        }
        return (NativeScorePageAnalyzer.notationComponents(image: analysisImage, candidates: candidates,
            skewDegrees: skewDegrees)!, candidates.map(ScoreObservedStaff.init))
    }

    static func main() throws {
        var failures: [String] = []
        for scale in [0.5, 0.6, 1.0, 1.5] {
            for tilt in [-1.5, 0.0, 1.5] {
                for bow in [-12.0,-10.0,-8.0,-6.0,-5.5,-5.0,-4.75,-4.5,-4.25,-4.0,-3.75,-3.5,-3.25,-3.0,-2.5,-2.0,0.0,2.0,3.0,3.5,4.0,4.5,5.0,5.5,6.0,8.0,10.0,12.0] {
                    Probe.prepare(scale:scale,tilt:tilt,bow:bow)
                    let (music, staves) = fixture(skewDegrees: tilt, rasterScale: scale, localBow: bow, harmonicBridge: true)
                    let retained = music.contains { $0.staffIDs == [0, 1] && $0.bounds[0] > 0.5 && $0.bounds[2] >= 459.0 / 720 }
                    Probe.finish(components:music,staves:staves,tilt:tilt,oldPass:retained)
                    checks += 1
                    if !retained { failures.append("scale=\(scale), tilt=\(tilt), bow=\(bow)") }
                }
            }
        }
        print("Curved harmonic controls: \(checks), failures: \(failures)")
        let name=CommandLine.arguments.dropFirst().first ?? "unknown"
        try JSONSerialization.data(withJSONObject:Probe.records,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:".build/qc-harmonic-independent/\(name)-direct.json"))
    }
}
