import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

@main enum IndependentSourceProbe {
    struct Input: Decodable {
        var cases: [Case]
        struct Case: Decodable {
            var id: String; var imagePath: String; var imageSHA256: String
            var strokeLeft: Int; var strokeRight: Int
            var staffSpace: Double; var staffLinesAtSpine: [Double]
            var skewSlope: Double; var upper: Bool
        }
    }
    static func main() throws {
        let args = CommandLine.arguments
        let inputs = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        var results: [[String: Any]] = []
        var cached: [String: (Int,Int,[Bool])] = [:]
        for c in inputs.cases {
            let raster: (Int,Int,[Bool])
            if let old = cached[c.imagePath] { raster = old }
            else {
                let data = try Data(contentsOf: URL(fileURLWithPath: c.imagePath))
                precondition(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == c.imageSHA256)
                let src = CGImageSourceCreateWithData(data as CFData,nil)!
                let image = CGImageSourceCreateImageAtIndex(src,0,nil)!
                // Match the production native original-ink conversion, including
                // Core Graphics grayscale conversion and its threshold.
                let w=image.width,h=image.height
                let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w,
                    space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue)!
                ctx.setFillColor(gray:1,alpha:1);ctx.fill(CGRect(x:0,y:0,width:w,height:h))
                ctx.interpolationQuality = .high
                ctx.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
                let raw=UnsafeBufferPointer(start:ctx.data!.assumingMemoryBound(to:UInt8.self),count:w*h)
                raster=(w,h,raw.map{$0<190});cached[c.imagePath]=raster
            }
            let w = NativeScorePageAnalyzer.sourceNoteheadEndpoint(original:raster.2,width:raster.0,height:raster.1,
                strokeLeft:c.strokeLeft,strokeRight:c.strokeRight,staffSpace:c.staffSpace,
                staffLinesAtSpine:c.staffLinesAtSpine,skewSlope:c.skewSlope,upper:c.upper)
            var r: [String: Any] = ["id":c.id,"accepted":w != nil,"fullNativeErasurePathTested":false]
            if let w { r["witness"] = try JSONSerialization.jsonObject(with:JSONEncoder().encode(w)) }
            results.append(r);print(c.id,w == nil ? "no witness" : "accepted")
        }
        try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys])
            .write(to:URL(fileURLWithPath:args[2]))
    }
}
