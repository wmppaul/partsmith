import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

@main enum SharedDestinationTests {
    typealias Detector = ScoreSharedDestinationDetector
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { print("FAILED: \(message)"); fflush(stdout); fatalError(message) }
    }
    static func fixture(_ name: String, hash: String) throws -> Detector.GrayRaster {
        let url = URL(fileURLWithPath: "Tests/quality_control/brahms93521/destination-fixtures/\(name).png")
        let data = try Data(contentsOf: url)
        print("Reading \(name)"); fflush(stdout)
        check(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == hash, "Independent source fixture hash: \(name)")
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { fatalError("Cannot decode fixture \(name)") }
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return Detector.GrayRaster(width: image.width, height: image.height,
            pixels: Array(UnsafeBufferPointer(start: bytes, count: image.width * image.height)))
    }
    struct Geometry: Decodable {
        var sourceSHA256: String
        var page: ScorePageAnalysis
        var profile: ScoreExtractionProfile
        var fixtureOriginPoints: [Double]
    }
    /// Keep the independently captured source pixels in their original page
    /// position. Blank unrelated page areas make ownership tests deterministic.
    static func pageImage(_ fixture: Detector.GrayRaster, geometry: Geometry) -> CGImage {
        let width = fixture.width
        let height = Int(geometry.page.pageHeight * Double(width) / geometry.page.pageWidth)
        let x = Int(floor(geometry.fixtureOriginPoints[0] * Double(width) / geometry.page.pageWidth))
        let y = Int(floor(geometry.fixtureOriginPoints[1] * Double(height) / geometry.page.pageHeight))
        var bytes = [UInt8](repeating: 255, count: width * height)
        for row in 0..<fixture.height {
            bytes.replaceSubrange(((y + row) * width + x)..<((y + row) * width + x + fixture.width),
                                  with: fixture.pixels[(row * fixture.width)..<((row + 1) * fixture.width)])
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
    static func main() throws {
        let navigation = try fixture("navigation-context", hash: "54115b54b34594381f1a51b576a75a0705a63c7863cdb1160a99e4f8a8016b6f")
        let source = Detector.candidates(in: navigation, staffSpace: 18.28555774105054)
        print("Source candidates \(source.count), raster \(navigation.width)x\(navigation.height)"); fflush(stdout)
        check(source.count == 1, "The printed navigation sentence supplies one unambiguous glyph despite its open fourth quadrant")
        let template = Detector.Template(sourcePageIndex: 27, sourceBounds: [0.76, 0.47, 0.79, 0.50],
            pixels: navigation.normalizedPatch(source[0].symbolBox)!)
        let destination = try fixture("destination-gap", hash: "a8c07476c6ce03f829ca2a1d0f7c9d9520e1282c87dc8127950753605598874f")
        // Candidate search ends above the staff; matching samples the complete
        // source context, including the glyph's attached lower stem.
        let destinationSearch = destination.crop(CGRect(x: 0, y: 0, width: destination.width, height: 183))!.0
        let found = Detector.candidates(in: destinationSearch, staffSpace: 18.491644990538813)
        check(found.count == 1, "Source destination remains a candidate when its two lower quadrants join through scan damage")
        let positive = Detector.bestTemplateMatch(in: destination, box: found[0].symbolBox, templates: [template])!
        check(positive.score >= 0.70, "The independent printed destination matches the actual instruction glyph")
        let beams = try fixture("beam-gap", hash: "f3f1effd663b49f15684a1873b6f739a41595f7b0370aa61c013efd0686c5805")
        let beamSearch = beams.crop(CGRect(x: 0, y: 0, width: beams.width, height: 204))!.0
        let confusers = Detector.candidates(in: beamSearch, staffSpace: 18.503878037185824)
        check(confusers.count == 1, "Regression: source beams deliberately exercise a near-miss topology candidate")
        let negative = Detector.bestTemplateMatch(in: beams, box: confusers[0].symbolBox, templates: [template])!
        check(negative.score < 0.70, "Nearby beams must not become a copied repeat destination")
        check(positive.score - negative.score > 0.20, "The real source positive is separated from its most plausible music confuser")
        check(Detector.bestTemplateMatch(in: destination, box: found[0].symbolBox, templates: []).isNil,
            "No instruction source template means no inferred repeat symbol")
        check(Detector.candidates(in: destination, staffSpace: 18.49, isCancelled: { true }).isEmpty,
            "Canceled topology extraction returns no partial candidate")
        check(Detector.bestTemplateMatch(in: destination, box: found[0].symbolBox, templates: [template], isCancelled: { true }).isNil,
            "Canceled source matching returns no partial result")
        check(Detector.candidates(in: destination, staffSpace: .nan).isEmpty, "Invalid staff space cannot define symbol geometry")
        check(Detector.correlation([1, 1], [1, 1]) == 0, "Blank constant regions do not correlate as symbols")
        check(Detector.correlation([0, 1, 0, 1], [0, 1, 0, 1]) > 0.999, "Identical nonblank evidence correlates")
        check(Detector.correlation([0, 1, 0, 1], [1, 0, 1, 0]) < -0.999, "Inverted evidence is not a positive symbol")
        check(Detector.correlation([0], [0, 1]) == 0, "Mismatched evidence dimensions are rejected")
        let geometry = try JSONDecoder().decode(Geometry.self, from: Data(contentsOf: URL(fileURLWithPath:
            "Tests/quality_control/brahms93521/destination-fixtures/public-api-geometry.json")))
        check(geometry.sourceSHA256 == "662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a",
              "Public API ownership fixture is bound to the independently reviewed score")
        let image = pageImage(destination, geometry: geometry)
        let publicMatches = Detector.detect(in: image, page: geometry.page, profile: geometry.profile, templates: [template])
        check(publicMatches.count == 1 && publicMatches.first?.anchorStaffID == 4 && publicMatches.first?.isBelow == false,
              "Public detection associates the complete source fixture with the verified second system")
        var instructionPage = geometry.page
        instructionPage.sharedNavigation = publicMatches.map {
            ScoreSharedNavigation(anchorStaffID: $0.anchorStaffID, bounds: $0.bounds,
                                  recognizedText: "Already assigned navigation instruction", isBelow: true)
        }
        check(Detector.detect(in: image, page: instructionPage, profile: geometry.profile, templates: [template]).isEmpty,
              "An inline instruction glyph must not become the following system's destination")
        var unresolved = geometry.profile
        unresolved.requiresSystemAssignment = true
        check(Detector.detect(in: image, page: geometry.page, profile: unresolved, templates: [template]).isEmpty,
              "Unresolved instrument ownership must not assign a source symbol")
        check(Detector.templates(in: image, page: instructionPage, profile: unresolved).isEmpty,
              "Unresolved source ownership cannot supply a trusted instruction template")
        check(Detector.detect(in: image, page: geometry.page, profile: geometry.profile, templates: [template],
                              isCancelled: { true }).isEmpty, "Canceled public detection returns no partial ownership")
        var previousPass = geometry.page; previousPass.sharedNavigation = publicMatches
        check(Detector.templates(in: image, page: previousPass, profile: geometry.profile).isEmpty,
              "A previously copied empty-text glyph cannot seed another template")
        print("\(checks) shared destination checks passed; positive \(positive.score), beam negative \(negative.score)")
    }
}
private extension Optional { var isNil: Bool { if case .none = self { return true }; return false } }
