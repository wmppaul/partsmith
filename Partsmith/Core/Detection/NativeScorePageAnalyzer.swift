import CoreGraphics
import Foundation
import PDFKit

/// Native offline PDF rendering shared by the app and batch inventory. Fractions
/// describe the supplied image; unrectified PDF pages map directly to PDF points.
enum NativeScorePageAnalyzer {
    static func render(_ page: PDFPage, maximumWidth: Int = 1800, maximumHeight: Int = 2600) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(CGFloat(maximumWidth) / bounds.width, CGFloat(maximumHeight) / bounds.height)
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: CGFloat(width) / bounds.width, y: CGFloat(height) / bounds.height)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        return context.makeImage()
    }

    static func analyze(pageIndex: Int, image: CGImage, pageWidth: Double, pageHeight: Double,
                        isCancelled: () -> Bool = { false }) -> ScorePageAnalysis {
        let detected = StaffBandDetector.detect(in: image, isCancelled: isCancelled)
        return ScorePageAnalysis(pageIndex: pageIndex, pageWidth: pageWidth, pageHeight: pageHeight,
            imageWidth: image.width, imageHeight: image.height, staves: detected.candidates.map(ScoreObservedStaff.init), warnings: detected.warnings, analysisSkewDegrees: detected.estimatedSkewDegrees)
    }
}
