import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

@main enum RasterRelayProbe {
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let width = 720, height = 760, space = 12
        var pixels = [UInt8](repeating: 255, count: width*height)
        func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) {
            for y in y0..<y1 { for x in x0..<x1 { pixels[y*width+x] = 0 } }
        }
        func head(_ cx: Int, _ cy: Int) {
            for y in (cy-4)..<(cy+4) { for x in (cx-8)..<(cx+8) {
                let a = (Double(x-cx)+0.5)/8, b = (Double(y-cy)+0.5)/4
                if a*a+b*b <= 1 { pixels[y*width+x] = 0 }
            } }
        }
        for top in [180,330] {
            for line in 0..<5 { rect(40, top+space*line, 603, top+space*line+1) }
            rect(160, top-20, 163, top+27); head(156,top+24)
        }
        rect(600,180,603,379); head(601,184); head(601,375)
        // A three-row scan gap crosses the final upper staff line. The lower
        // head remains a terminal witness. V1's single missing row left its
        // component touching that last line and thus had two geometric owners.
        for y in 227...229 { for x in 600..<603 { pixels[y*width+x] = 255 } }
        // Detached annotation surrogate, fixed before examining either crop.
        // These are geometry controls, not recognized named musical glyphs.
        let annotations = [[610,249,620,258], [610,272,620,281], [610,295,620,304]]
        for b in annotations { rect(b[0],b[1],b[2],b[3]) }
        let image = CGImage(width: width,height: height,bitsPerComponent: 8,bitsPerPixel: 8,bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: CGDataProvider(data: Data(pixels) as CFData)!,decode: nil,shouldInterpolate: false,intent: .defaultIntent)!
        let imageURL = output.appendingPathComponent("source.png")
        let sink = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(sink,image,nil); precondition(CGImageDestinationFinalize(sink))
        let sourceEvidence: [String: Any] = ["sourceSHA256": SHA256.hash(data: Data(pixels)).map { String(format:"%02x",$0) }.joined(),
            "sourceImageSize": [width,height], "detachedAnnotationRectangles": annotations,
            "sourceBreakRows": [227,228,229], "kind": "constructed native-raster control, not an actual score or a semantic glyph classification"]
        try JSONSerialization.data(withJSONObject: sourceEvidence,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("source-evidence.json"))
        var staves: [StaffBandCandidate] = []
        for (i, top) in [180,330].enumerated() {
            let staffLines: [Double] = (0..<5).map { Double(top + $0*space)/Double(height) }
            staves.append(StaffBandCandidate(id:i,staffLineFractions:staffLines,
                topFraction: Double(top-space)/Double(height),bottomFraction: Double(top+5*space)/Double(height),confidence:1,warnings:[]))
        }
        let profile = ScoreExtractionProfile(parts:[.init(id:"one",name:"One",staffCount:1)],cropMode:"compact")
        let encoder = JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        var results: [[String:Any]] = []
        var local: [ScoreInkComponent] = []
        for musical in [false,true] {
            let components = NativeScorePageAnalyzer.notationComponents(image:image,candidates:staves,skewDegrees:0,retainMusicalEvidence:musical)!
            if !musical { local = components }
            let page = ScorePageAnalysis(pageIndex:0,pageWidth:Double(width),pageHeight:Double(height),imageWidth:width,imageHeight:height,
                staves:staves.map(ScoreObservedStaff.init),warnings:[],inkComponents:components)
            let plan = ScoreExtractionPlanner.plan(pages:[page],profile:profile)
            let name = musical ? "candidate" : "local"
            try encoder.encode(page).write(to:output.appendingPathComponent(name+"-page.json"))
            try encoder.encode(plan).write(to:output.appendingPathComponent(name+"-plan.json"))
            results.append(["retainMusicalEvidence":musical,"componentCount":components.count,
                "allLocalComponentsRetained":local.allSatisfy{components.contains($0)},
                "upperCropBottomPixels":plan.bands[0].bottomFraction*Double(height),
                "canApply":plan.canApply,
                "annotationRetained":annotations.map{Double($0[3]) <= plan.bands[0].bottomFraction*Double(height)}])
        }
        try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("results.json"))
        print(results)
    }
}
