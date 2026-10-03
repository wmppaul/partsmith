import Foundation
import CoreGraphics

@main enum GlyphContinuationControls {
    static let width = 400, height = 300
    static let box = [0.25, 0.2, 0.6, 0.4]
    static var checks: [[String: Any]] = []
    static func check(_ value: Bool, _ name: String) { checks.append(["name":name,"passed":value]) }
    static func anchor() -> ScoreObservedStaff {
        ScoreObservedStaff(StaffBandCandidate(id:0,
            staffLineFractions:[140,148,156,164,172].map { Double($0)/Double(height) },
            topFraction:0.45,bottomFraction:0.59,confidence:1,warnings:[]))
    }
    static func image(_ draw: (inout [UInt8]) -> Void) -> CGImage {
        var pixels = [UInt8](repeating:255,count:width*height); draw(&pixels)
        let provider = CGDataProvider(data:Data(pixels) as CFData)!
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:width,
            space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.none.rawValue),
            provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    }
    static func line(_ p: inout [UInt8], _ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ thickness:Int=3) {
        let steps=max(abs(x1-x0),abs(y1-y0))
        for i in 0...steps {
            let x=x0+(x1-x0)*i/max(1,steps),y=y0+(y1-y0)*i/max(1,steps)
            for yy in max(0,y-thickness/2)...min(height-1,y+thickness/2) {
                for xx in max(0,x-thickness/2)...min(width-1,x+thickness/2) {p[yy*width+xx]=0}
            }
        }
    }
    static func a(_ p: inout [UInt8], dx:Int=0) {
        line(&p,106+dx,76,94+dx,108)
        line(&p,106+dx,76,118+dx,108)
        line(&p,99+dx,96,113+dx,96)
    }
    static func main() throws {
        let original = box, staff = anchor()
        let left = image { a(&$0) }
        let changed = ScoreSharedHeadingDetector.continuedGlyphBounds(in:left,bounds:original,anchor:staff)
        check(changed[0] <= 93.0/400 && changed[1...] == original[1...],
              "connected original A restores its complete left stroke and keeps the other edges")
        let right = image { a(&$0,dx:128) }
        let rightBox = ScoreSharedHeadingDetector.continuedGlyphBounds(in:right,bounds:original,anchor:staff)
        check(rightBox[2] >= 249.0/400 && rightBox[0]==original[0] && rightBox[1]==original[1] && rightBox[3]==original[3],
              "right-edge glyph recovery uses the same source continuation rule")
        let beyondReach = image { a(&$0,dx:136) }
        check(ScoreSharedHeadingDetector.continuedGlyphBounds(in:beyondReach,bounds:original,anchor:staff)==original,
              "a glyph extending past the bounded search retains the original box rather than guessing its edge")
        check(ScoreSharedHeadingDetector.continuedGlyphBounds(in:left,bounds:changed,anchor:staff)==changed,
              "repeated continuation is idempotent")
        for (name,draw) in [
            ("empty paper", { (_:inout [UInt8]) in }),
            ("detached neighboring letter", { (p:inout [UInt8]) in a(&p,dx:-27) }),
            ("horizontal staff line", { (p:inout [UInt8]) in line(&p,40,111,350,111) }),
            ("shallow slur", { (p:inout [UInt8]) in line(&p,91,111,125,108,1) }),
            ("note stem connected below the copy", { (p:inout [UInt8]) in line(&p,97,86,97,133);line(&p,97,133,109,131,7) }),
            ("clef fragment crossing top limit", { (p:inout [UInt8]) in line(&p,97,45,110,90,5) }),
            ("horizontal reach would end within another component", { (p:inout [UInt8]) in line(&p,60,84,108,84,9);line(&p,108,84,108,105,5) })
        ] {
            let result = ScoreSharedHeadingDetector.continuedGlyphBounds(in:image(draw),bounds:original,anchor:staff)
            check(result==original,"\(name) cannot justify margin growth")
        }
        let equation = image { p in
            a(&p); line(&p,155,78,155,107);line(&p,146,107,155,107,5)
            line(&p,161,106,162,106);line(&p,168,93,179,93,1);line(&p,168,98,179,98,1)
            line(&p,195,85,195,106);line(&p,207,84,213,104,3)
        }
        let eq = ScoreSharedHeadingDetector.continuedGlyphBounds(in:equation,bounds:original,anchor:staff)
        check(eq[0] <= original[0] && eq[1] <= original[1] && eq[2] >= original[2] && eq[3] >= original[3],
              "metronome note, dot, equals sign and numeral pixels cannot be lost by continuation")
        check(ScoreSharedHeadingDetector.continuedGlyphBounds(in:left,bounds:original,anchor:staff,isCancelled:{true})==original,
              "cancellation before work returns the original complete box")
        var calls=0
        check(ScoreSharedHeadingDetector.continuedGlyphBounds(in:left,bounds:original,anchor:staff,isCancelled:{calls+=1;return calls>5})==original,
              "cancellation during scan discards partial expansion")
        for i in 0..<6 {
            var bad=staff
            if i==0 {bad.staffLineFractions=[]}
            else if i==1 {bad.staffLineFractions[2] = .nan}
            else if i==2 {bad.staffLineFractions.reverse()}
            else if i==3 {bad.staffLineFractions[0] = -0.1}
            else if i==4 {bad.staffLineFractions[4] = 1.1}
            else {bad.staffLineFractions = [-1e308, -1e307, 0, 1e307, 1e308]}
            check(ScoreSharedHeadingDetector.continuedGlyphBounds(in:left,bounds:original,anchor:bad)==original,
                  "invalid staff geometry \(i) cannot change source bounds")
        }
        let report:[String:Any]=["checks":checks,"count":checks.count,"failures":checks.filter{$0["passed"] as? Bool != true}.count]
        print(String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
        if checks.contains(where:{$0["passed"] as? Bool != true}) {exit(1)}
    }
}
