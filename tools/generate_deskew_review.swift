import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

struct FractionPoint: Codable {
    var x: Double
    var y: Double

    func normalized() -> FractionPoint {
        FractionPoint(
            x: max(0, min(x, 1)),
            y: max(0, min(y, 1))
        )
    }
}

struct PageRectification: Codable {
    var pageIndex: Int
    var topLeft: FractionPoint
    var topRight: FractionPoint
    var bottomRight: FractionPoint
    var bottomLeft: FractionPoint

    func normalized() -> PageRectification {
        PageRectification(
            pageIndex: pageIndex,
            topLeft: topLeft.normalized(),
            topRight: topRight.normalized(),
            bottomRight: bottomRight.normalized(),
            bottomLeft: bottomLeft.normalized()
        )
    }
}

struct PageRectificationEstimate {
    var rectification: PageRectification
    var angleDegrees: Double
}

enum PageRectificationEstimator {
    static func estimate(
        for image: CGImage,
        pageIndex: Int,
        minimumCorrectionDegrees: Double = 0.12
    ) -> PageRectificationEstimate? {
        let samples = extractInkSamples(from: image)
        guard let angleDegrees = estimateAngle(samples: samples, imageSize: CGSize(width: image.width, height: image.height)) else {
            return nil
        }

        guard abs(angleDegrees) >= minimumCorrectionDegrees else { return nil }
        guard let rectification = rectification(
            pageIndex: pageIndex,
            angleDegrees: angleDegrees,
            pageSize: CGSize(width: image.width, height: image.height)
        ) else {
            return nil
        }

        return PageRectificationEstimate(rectification: rectification, angleDegrees: angleDegrees)
    }

    private struct InkSample {
        var x: Double
        var y: Double
        var weight: Double
    }

    private static func extractInkSamples(from image: CGImage, sampleStride: Int = 2) -> [InkSample] {
        guard let provider = image.dataProvider, let data = provider.data else { return [] }
        guard let bytes = CFDataGetBytePtr(data) else { return [] }

        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow

        let minX = Int(Double(width) * 0.03)
        let maxX = Int(Double(width) * 0.97)
        let minY = Int(Double(height) * 0.03)
        let maxY = Int(Double(height) * 0.97)

        var samples: [InkSample] = []
        samples.reserveCapacity((width / sampleStride) * (height / sampleStride) / 6)

        for rowIndex in Swift.stride(from: minY, to: maxY, by: sampleStride) {
            let row = bytes + rowIndex * bytesPerRow
            let y = Double(height - rowIndex - 1)

            for columnIndex in Swift.stride(from: minX, to: maxX, by: sampleStride) {
                let pixel = row + columnIndex * 4
                let red = Double(pixel[0]) / 255.0
                let green = Double(pixel[1]) / 255.0
                let blue = Double(pixel[2]) / 255.0
                let luma = 0.299 * red + 0.587 * green + 0.114 * blue
                let darkness = max(0.0, 1.0 - luma)

                if darkness > 0.22 {
                    samples.append(
                        InkSample(
                            x: Double(columnIndex),
                            y: y,
                            weight: darkness
                        )
                    )
                }
            }
        }

        return samples
    }

    private static func estimateAngle(samples: [InkSample], imageSize: CGSize) -> Double? {
        guard samples.count > 1_000 else { return nil }

        let centerX = imageSize.width / 2.0
        let centerY = imageSize.height / 2.0

        var bestAngle = 0.0
        var bestScore = -Double.infinity

        var angle = -4.0
        while angle <= 4.0 {
            let score = projectionScore(
                samples: samples,
                angleDegrees: angle,
                centerX: centerX,
                centerY: centerY
            )

            if score > bestScore {
                bestScore = score
                bestAngle = angle
            }

            angle += 0.25
        }

        let coarseBestAngle = bestAngle
        bestScore = -Double.infinity
        angle = coarseBestAngle - 0.35

        while angle <= coarseBestAngle + 0.35 {
            let score = projectionScore(
                samples: samples,
                angleDegrees: angle,
                centerX: centerX,
                centerY: centerY
            )

            if score > bestScore {
                bestScore = score
                bestAngle = angle
            }

            angle += 0.025
        }

        return bestAngle
    }

    private static func projectionScore(
        samples: [InkSample],
        angleDegrees: Double,
        centerX: Double,
        centerY: Double
    ) -> Double {
        let radians = angleDegrees * .pi / 180.0
        let sine = sin(radians)
        let cosine = cos(radians)
        let binSize = 1.5

        var histogram: [Int: Double] = [:]
        histogram.reserveCapacity(4096)
        var totalWeight = 0.0

        for sample in samples {
            let dx = sample.x - centerX
            let dy = sample.y - centerY
            let rotatedY = -sine * dx + cosine * dy
            let bin = Int((rotatedY / binSize).rounded())
            histogram[bin, default: 0.0] += sample.weight
            totalWeight += sample.weight
        }

        guard totalWeight > 0 else { return 0 }
        let energy = histogram.values.reduce(0.0) { partial, value in
            partial + value * value
        }
        return energy / (totalWeight * totalWeight)
    }

    private static func rectification(
        pageIndex: Int,
        angleDegrees: Double,
        pageSize: CGSize
    ) -> PageRectification? {
        let width = pageSize.width
        let height = pageSize.height
        guard width > 0, height > 0 else { return nil }

        let radians = angleDegrees * .pi / 180.0
        let absoluteCosine = abs(cos(radians))
        let absoluteSine = abs(sin(radians))
        let scale = min(
            width / (width * absoluteCosine + height * absoluteSine),
            height / (width * absoluteSine + height * absoluteCosine)
        ) * 0.998

        let halfWidth = width * scale / 2.0
        let halfHeight = height * scale / 2.0
        let centerX = width / 2.0
        let centerY = height / 2.0
        let cosine = cos(radians)
        let sine = sin(radians)

        func point(dx: Double, dy: Double) -> FractionPoint {
            let x = centerX + dx * cosine - dy * sine
            let y = centerY + dx * sine + dy * cosine

            return FractionPoint(
                x: x / width,
                y: 1.0 - (y / height)
            )
        }

        return PageRectification(
            pageIndex: pageIndex,
            topLeft: point(dx: -halfWidth, dy: halfHeight),
            topRight: point(dx: halfWidth, dy: halfHeight),
            bottomRight: point(dx: halfWidth, dy: -halfHeight),
            bottomLeft: point(dx: -halfWidth, dy: -halfHeight)
        ).normalized()
    }
}

struct PageReviewRecord: Codable {
    var id: String
    var pdfName: String
    var pdfRelativePath: String
    var pageIndex: Int
    var pageNumber: Int
    var pageWidth: Int
    var pageHeight: Int
    var sourceImage: String
    var rectifiedImage: String?
    var angleDegrees: Double?
    var absoluteAngleDegrees: Double?
    var rectification: PageRectification?
    var overlayLines: [[CGPoint]]
}

struct PDFSummaryRecord: Codable {
    var pdfName: String
    var pageCount: Int
    var estimatedCount: Int
    var estimatedShare: Double
    var meanSignedAngle: Double?
    var medianSignedAngle: Double?
    var medianAbsoluteAngle: Double?
    var p90AbsoluteAngle: Double?
    var maxAbsoluteAngle: Double?
}

struct HistogramBin: Codable {
    var label: String
    var count: Int
}

struct OverallSummaryRecord: Codable {
    var totalPDFs: Int
    var totalPages: Int
    var estimatedPages: Int
    var estimatedShare: Double
    var meanSignedAngle: Double?
    var medianSignedAngle: Double?
    var medianAbsoluteAngle: Double?
    var p90AbsoluteAngle: Double?
    var p95AbsoluteAngle: Double?
    var maxAbsoluteAngle: Double?
    var signedHistogram: [HistogramBin]
    var absoluteHistogram: [HistogramBin]
}

struct ReviewReport: Codable {
    var generatedAt: String
    var sourceDirectory: String
    var overall: OverallSummaryRecord
    var perPDF: [PDFSummaryRecord]
    var pages: [PageReviewRecord]
}

func usageAndExit() -> Never {
    fputs("usage: generate_deskew_review.swift <pdf-dir> <output-dir>\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 3 else { usageAndExit() }

let pdfDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let pageImagesDirectory = outputDirectory.appendingPathComponent("pages", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: pageImagesDirectory, withIntermediateDirectories: true)

let pdfURLs = try FileManager.default.contentsOfDirectory(
    at: pdfDirectory,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
)
    .filter { $0.pathExtension.lowercased() == "pdf" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard pdfURLs.isEmpty == false else {
    fputs("no PDFs found in \(pdfDirectory.path)\n", stderr)
    exit(2)
}

var pageRecords: [PageReviewRecord] = []
var pdfSummaries: [PDFSummaryRecord] = []
var allSignedAngles: [Double] = []
var allAbsoluteAngles: [Double] = []

for pdfURL in pdfURLs {
    guard let document = PDFDocument(url: pdfURL) else {
        fputs("failed to open \(pdfURL.path)\n", stderr)
        continue
    }

    var pdfSignedAngles: [Double] = []
    var pdfAbsoluteAngles: [Double] = []

    for pageIndex in 0..<document.pageCount {
        guard let page = document.page(at: pageIndex) else { continue }
        guard let analysisImage = rasterizedImage(for: page, targetPixelWidth: 1200) else { continue }

        let estimate = PageRectificationEstimator.estimate(for: analysisImage, pageIndex: pageIndex)
        let sourcePreview = resizedImage(from: analysisImage, targetWidth: 420) ?? analysisImage
        let rectifiedPreview: CGImage?

        if let estimate {
            pdfSignedAngles.append(estimate.angleDegrees)
            pdfAbsoluteAngles.append(abs(estimate.angleDegrees))
            allSignedAngles.append(estimate.angleDegrees)
            allAbsoluteAngles.append(abs(estimate.angleDegrees))
            if let rectifiedImage = rectifiedImage(from: analysisImage, angleDegrees: estimate.angleDegrees) {
                rectifiedPreview = resizedImage(from: rectifiedImage, targetWidth: 420) ?? rectifiedImage
            } else {
                rectifiedPreview = nil
            }
        } else {
            rectifiedPreview = nil
        }

        let baseName = sanitizedBaseName(for: pdfURL)
        let pageStem = "\(baseName)_p\(String(format: "%03d", pageIndex + 1))"
        let sourceRelativePath = "pages/\(pageStem)_source.jpg"
        let sourceURL = outputDirectory.appendingPathComponent(sourceRelativePath)
        try writeJPEG(sourcePreview, to: sourceURL, quality: 0.72)

        var rectifiedRelativePath: String?
        if let rectifiedPreview {
            rectifiedRelativePath = "pages/\(pageStem)_rectified.jpg"
            try writeJPEG(rectifiedPreview, to: outputDirectory.appendingPathComponent(rectifiedRelativePath!), quality: 0.72)
        }

        pageRecords.append(
            PageReviewRecord(
                id: "\(baseName)-\(pageIndex + 1)",
                pdfName: pdfURL.lastPathComponent,
                pdfRelativePath: pdfDirectory.relativePath == "." ? pdfURL.lastPathComponent : pdfURL.path.replacingOccurrences(of: pdfDirectory.deletingLastPathComponent().path + "/", with: ""),
                pageIndex: pageIndex,
                pageNumber: pageIndex + 1,
                pageWidth: sourcePreview.width,
                pageHeight: sourcePreview.height,
                sourceImage: sourceRelativePath,
                rectifiedImage: rectifiedRelativePath,
                angleDegrees: estimate?.angleDegrees,
                absoluteAngleDegrees: estimate.map { abs($0.angleDegrees) },
                rectification: estimate?.rectification,
                overlayLines: estimate.map { overlayLines(for: $0.rectification, width: sourcePreview.width, height: sourcePreview.height) } ?? []
            )
        )
    }

    pdfSummaries.append(
        PDFSummaryRecord(
            pdfName: pdfURL.lastPathComponent,
            pageCount: document.pageCount,
            estimatedCount: pdfSignedAngles.count,
            estimatedShare: ratio(pdfSignedAngles.count, document.pageCount),
            meanSignedAngle: mean(pdfSignedAngles),
            medianSignedAngle: median(pdfSignedAngles),
            medianAbsoluteAngle: median(pdfAbsoluteAngles),
            p90AbsoluteAngle: percentile(pdfAbsoluteAngles, 0.90),
            maxAbsoluteAngle: pdfAbsoluteAngles.max()
        )
    )
}

let report = ReviewReport(
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    sourceDirectory: pdfDirectory.path,
    overall: OverallSummaryRecord(
        totalPDFs: pdfURLs.count,
        totalPages: pageRecords.count,
        estimatedPages: allSignedAngles.count,
        estimatedShare: ratio(allSignedAngles.count, pageRecords.count),
        meanSignedAngle: mean(allSignedAngles),
        medianSignedAngle: median(allSignedAngles),
        medianAbsoluteAngle: median(allAbsoluteAngles),
        p90AbsoluteAngle: percentile(allAbsoluteAngles, 0.90),
        p95AbsoluteAngle: percentile(allAbsoluteAngles, 0.95),
        maxAbsoluteAngle: allAbsoluteAngles.max(),
        signedHistogram: signedHistogram(allSignedAngles),
        absoluteHistogram: absoluteHistogram(allAbsoluteAngles)
    ),
    perPDF: pdfSummaries,
    pages: pageRecords
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let reportJSON = try encoder.encode(report)
try reportJSON.write(to: outputDirectory.appendingPathComponent("summary.json"))
try buildHTML(report: report).write(to: outputDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

print("Generated deskew review at \(outputDirectory.path)")
print("PDFs: \(report.overall.totalPDFs)")
print("Pages: \(report.overall.totalPages)")
print("Estimated pages: \(report.overall.estimatedPages) (\(formatPercent(report.overall.estimatedShare)))")
print("Mean signed angle: \(formatOptional(report.overall.meanSignedAngle))")
print("Median signed angle: \(formatOptional(report.overall.medianSignedAngle))")
print("Median absolute angle: \(formatOptional(report.overall.medianAbsoluteAngle))")
print("P90 absolute angle: \(formatOptional(report.overall.p90AbsoluteAngle))")
print("P95 absolute angle: \(formatOptional(report.overall.p95AbsoluteAngle))")
print("Max absolute angle: \(formatOptional(report.overall.maxAbsoluteAngle))")

func rasterizedImage(for page: PDFPage, targetPixelWidth: CGFloat) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let scale = targetPixelWidth / max(bounds.width, 1)
    let pixelWidth = max(1, Int((bounds.width * scale).rounded(.up)))
    let pixelHeight = max(1, Int((bounds.height * scale).rounded(.up)))

    guard let context = CGContext(
        data: nil,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    return context.makeImage()
}

func rectifiedImage(from image: CGImage, angleDegrees: Double) -> CGImage? {
    let width = image.width
    let height = image.height

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    context.rotate(by: CGFloat(-angleDegrees * .pi / 180.0))
    context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

func resizedImage(from image: CGImage, targetWidth: Int) -> CGImage? {
    guard targetWidth > 0 else { return nil }
    let scale = Double(targetWidth) / Double(image.width)
    let targetHeight = max(1, Int((Double(image.height) * scale).rounded()))

    guard let context = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.interpolationQuality = .high
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    return context.makeImage()
}

func writeJPEG(_ image: CGImage, to url: URL, quality: Double) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw NSError(domain: "DeskewReview", code: 10, userInfo: [NSLocalizedDescriptionKey: "Could not create image destination for \(url.path)"])
    }

    let options: NSDictionary = [
        kCGImageDestinationLossyCompressionQuality: quality
    ]
    CGImageDestinationAddImage(destination, image, options)

    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DeskewReview", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to write image to \(url.path)"])
    }
}

func overlayLines(for rectification: PageRectification, width: Int, height: Int) -> [[CGPoint]] {
    func point(_ fractionPoint: FractionPoint) -> CGPoint {
        CGPoint(
            x: fractionPoint.x * Double(width),
            y: fractionPoint.y * Double(height)
        )
    }

    let topLeft = point(rectification.topLeft)
    let topRight = point(rectification.topRight)
    let bottomRight = point(rectification.bottomRight)
    let bottomLeft = point(rectification.bottomLeft)

    func interpolate(_ first: CGPoint, _ second: CGPoint, t: Double) -> CGPoint {
        CGPoint(
            x: first.x + (second.x - first.x) * t,
            y: first.y + (second.y - first.y) * t
        )
    }

    var lines: [[CGPoint]] = [[topLeft, topRight], [topRight, bottomRight], [bottomRight, bottomLeft], [bottomLeft, topLeft]]

    for step in 1...4 {
        let t = Double(step) / 5.0
        lines.append([
            interpolate(topLeft, bottomLeft, t: t),
            interpolate(topRight, bottomRight, t: t)
        ])
        lines.append([
            interpolate(topLeft, topRight, t: t),
            interpolate(bottomLeft, bottomRight, t: t)
        ])
    }

    return lines
}

func sanitizedBaseName(for url: URL) -> String {
    url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
}

func ratio(_ numerator: Int, _ denominator: Int) -> Double {
    guard denominator > 0 else { return 0 }
    return Double(numerator) / Double(denominator)
}

func mean(_ values: [Double]) -> Double? {
    guard values.isEmpty == false else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

func median(_ values: [Double]) -> Double? {
    percentile(values, 0.5)
}

func percentile(_ values: [Double], _ percentile: Double) -> Double? {
    guard values.isEmpty == false else { return nil }
    let sorted = values.sorted()
    let clamped = max(0.0, min(1.0, percentile))
    let index = Double(sorted.count - 1) * clamped
    let lowerIndex = Int(floor(index))
    let upperIndex = Int(ceil(index))

    if lowerIndex == upperIndex {
        return sorted[lowerIndex]
    }

    let lowerValue = sorted[lowerIndex]
    let upperValue = sorted[upperIndex]
    let weight = index - Double(lowerIndex)
    return lowerValue + (upperValue - lowerValue) * weight
}

func signedHistogram(_ values: [Double]) -> [HistogramBin] {
    let bins: [(String, ClosedRange<Double>)] = [
        ("<= -1.0", -100...(-1.0)),
        ("-1.0 to -0.5", -1.0...(-0.5)),
        ("-0.5 to -0.25", -0.5...(-0.25)),
        ("-0.25 to 0.0", -0.25...0.0),
        ("0.0 to 0.25", 0.0...0.25),
        ("0.25 to 0.5", 0.25...0.5),
        ("0.5 to 1.0", 0.5...1.0),
        (">= 1.0", 1.0...100)
    ]

    return bins.map { label, range in
        let count = values.filter { range.contains($0) }.count
        return HistogramBin(label: label, count: count)
    }
}

func absoluteHistogram(_ values: [Double]) -> [HistogramBin] {
    let bins: [(String, ClosedRange<Double>)] = [
        ("0.0 to 0.15", 0.0...0.15),
        ("0.15 to 0.3", 0.15...0.3),
        ("0.3 to 0.45", 0.3...0.45),
        ("0.45 to 0.6", 0.45...0.6),
        ("0.6 to 0.8", 0.6...0.8),
        ("0.8 to 1.0", 0.8...1.0),
        (">= 1.0", 1.0...100)
    ]

    return bins.map { label, range in
        let count = values.filter { range.contains($0) }.count
        return HistogramBin(label: label, count: count)
    }
}

func formatOptional(_ value: Double?) -> String {
    guard let value else { return "n/a" }
    return String(format: "%.3f°", value)
}

func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

func buildHTML(report: ReviewReport) throws -> String {
    let jsonData = try JSONEncoder().encode(report)
    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

    return """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Partsmith Deskew Review</title>
  <style>
    :root {
      --bg: #f4f1e8;
      --panel: #fffdf8;
      --ink: #1f1d1a;
      --muted: #6f675e;
      --accent: #0f766e;
      --accent-2: #b45309;
      --border: #d9d1c5;
      --good: #166534;
      --bad: #b91c1c;
      --skip: #475569;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Iowan Old Style", "Palatino Linotype", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(15,118,110,0.08), transparent 28%),
        radial-gradient(circle at top right, rgba(180,83,9,0.08), transparent 24%),
        var(--bg);
    }
    main {
      width: min(1880px, calc(100vw - 28px));
      margin: 24px auto 80px;
    }
    h1, h2, h3 {
      margin: 0;
      font-weight: 700;
      letter-spacing: 0.01em;
    }
    p { margin: 0; line-height: 1.45; }
    .hero, .panel {
      background: rgba(255,253,248,0.92);
      backdrop-filter: blur(8px);
      border: 1px solid var(--border);
      border-radius: 18px;
      box-shadow: 0 18px 45px rgba(63,52,39,0.08);
    }
    .hero {
      padding: 24px;
      display: grid;
      grid-template-columns: 2fr 1fr;
      gap: 20px;
      align-items: start;
    }
    .hero h1 {
      font-size: clamp(2rem, 3vw, 3.4rem);
    }
    .subtle {
      color: var(--muted);
      margin-top: 10px;
      max-width: 72ch;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
      margin-top: 18px;
    }
    .stat {
      padding: 14px;
      background: rgba(255,255,255,0.8);
      border-radius: 14px;
      border: 1px solid rgba(217,209,197,0.9);
    }
    .stat .label {
      display: block;
      font-size: 0.82rem;
      color: var(--muted);
      margin-bottom: 4px;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .stat .value {
      font-size: 1.45rem;
      font-weight: 700;
    }
    .stat .note {
      font-size: 0.85rem;
      color: var(--muted);
      margin-top: 6px;
    }
    .section {
      margin-top: 18px;
      padding: 20px;
    }
    .histograms {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 16px;
    }
    .bars {
      display: grid;
      gap: 10px;
      margin-top: 14px;
    }
    .bar-row {
      display: grid;
      grid-template-columns: 120px 1fr 42px;
      align-items: center;
      gap: 10px;
      font-size: 0.92rem;
    }
    .bar {
      height: 12px;
      background: rgba(15,118,110,0.12);
      border-radius: 999px;
      overflow: hidden;
    }
    .bar > span {
      display: block;
      height: 100%;
      background: linear-gradient(90deg, var(--accent), #14b8a6);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 14px;
      font-size: 0.95rem;
    }
    th, td {
      text-align: left;
      padding: 10px 8px;
      border-bottom: 1px solid rgba(217,209,197,0.7);
    }
    th {
      color: var(--muted);
      font-size: 0.82rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .controls {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      align-items: center;
      margin-top: 14px;
    }
    .controls select, .controls button {
      border-radius: 999px;
      border: 1px solid var(--border);
      background: white;
      color: var(--ink);
      padding: 10px 14px;
      font: inherit;
    }
    .pdf-group {
      margin-top: 18px;
    }
    details {
      border: 1px solid rgba(217,209,197,0.9);
      border-radius: 16px;
      background: rgba(255,255,255,0.76);
      overflow: hidden;
    }
    details + details {
      margin-top: 14px;
    }
    summary {
      list-style: none;
      cursor: pointer;
      padding: 16px 18px;
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: center;
      background: linear-gradient(90deg, rgba(15,118,110,0.08), rgba(255,255,255,0));
    }
    summary::-webkit-details-marker { display: none; }
    .page-grid {
      padding: 16px;
      display: grid;
      grid-template-columns: 1fr;
      gap: 18px;
    }
    .page-card {
      border: 1px solid rgba(217,209,197,0.85);
      border-radius: 16px;
      padding: 18px;
      background: rgba(255,255,255,0.92);
      display: grid;
      gap: 14px;
    }
    .page-card.no-estimate {
      background: rgba(245,245,244,0.92);
    }
    .page-header {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: baseline;
    }
    .page-meta {
      color: var(--muted);
      font-size: 0.88rem;
    }
    .angle-badge, .rating-badge {
      border-radius: 999px;
      padding: 6px 10px;
      font-size: 0.8rem;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      white-space: nowrap;
    }
    .angle-badge {
      background: rgba(180,83,9,0.12);
      color: var(--accent-2);
    }
    .angle-badge.none {
      background: rgba(71,85,105,0.12);
      color: var(--skip);
    }
    .visuals {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 14px;
      align-items: start;
    }
    .visual {
      position: relative;
      background: #fff;
      border: 1px solid rgba(217,209,197,0.9);
      border-radius: 14px;
      overflow: hidden;
    }
    .visual img {
      display: block;
      width: 100%;
      height: auto;
      background: white;
    }
    .visual svg {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 1;
    }
    .guide-overlay line.minor {
      stroke: rgba(20,184,166,0.34);
      stroke-width: 1.05;
    }
    .guide-overlay line.major {
      stroke: rgba(249,115,22,0.46);
      stroke-width: 1.3;
    }
    .quad-overlay line {
      stroke: rgba(15,118,110,0.62);
      stroke-width: 1.5;
    }
    .quad-overlay {
      z-index: 2;
    }
    .visual-label {
      position: absolute;
      left: 10px;
      top: 10px;
      background: rgba(31,29,26,0.85);
      color: white;
      border-radius: 999px;
      padding: 4px 9px;
      font-size: 0.72rem;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      z-index: 3;
    }
    .placeholder {
      min-height: 220px;
      display: grid;
      place-items: center;
      text-align: center;
      color: var(--muted);
      padding: 16px;
      background: linear-gradient(180deg, rgba(255,255,255,0.95), rgba(244,241,232,0.95));
    }
    .review-buttons {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
    }
    .review-buttons button {
      border-radius: 999px;
      border: 1px solid var(--border);
      background: white;
      padding: 8px 12px;
      font: inherit;
      cursor: pointer;
    }
    .review-buttons button.active[data-rating="accept"] {
      background: rgba(22,101,52,0.12);
      color: var(--good);
      border-color: rgba(22,101,52,0.35);
    }
    .review-buttons button.active[data-rating="needs-work"] {
      background: rgba(185,28,28,0.1);
      color: var(--bad);
      border-color: rgba(185,28,28,0.28);
    }
    .review-buttons button.active[data-rating="skip"] {
      background: rgba(71,85,105,0.12);
      color: var(--skip);
      border-color: rgba(71,85,105,0.3);
    }
    .footer-note {
      margin-top: 10px;
      color: var(--muted);
      font-size: 0.88rem;
    }
    @media (max-width: 980px) {
      .hero, .histograms, .visuals { grid-template-columns: 1fr; }
      .stats { grid-template-columns: 1fr 1fr; }
    }
    @media (max-width: 640px) {
      main { width: min(100vw - 20px, 100%); margin-top: 12px; }
      .hero, .section { padding: 16px; }
      .stats { grid-template-columns: 1fr; }
      .page-grid { grid-template-columns: 1fr; padding: 12px; }
      .bar-row { grid-template-columns: 92px 1fr 34px; font-size: 0.84rem; }
    }
  </style>
</head>
<body>
  <main id="app"></main>
  <script>
    const report = \(jsonString);
    const ratingsKey = "partsmith-deskew-review-ratings";

    function loadRatings() {
      try {
        return JSON.parse(localStorage.getItem(ratingsKey) || "{}");
      } catch {
        return {};
      }
    }

    function saveRatings(ratings) {
      localStorage.setItem(ratingsKey, JSON.stringify(ratings));
    }

    const ratings = loadRatings();

    function formatAngle(value) {
      return value == null ? "No auto correction" : `${value.toFixed(3)}°`;
    }

    function formatPercent(value) {
      return `${(value * 100).toFixed(1)}%`;
    }

    function histogramMarkup(title, bins) {
      const max = Math.max(1, ...bins.map(bin => bin.count));
      return `
        <div class="panel section">
          <h3>${title}</h3>
          <div class="bars">
            ${bins.map(bin => `
              <div class="bar-row">
                <span>${bin.label}</span>
                <div class="bar"><span style="width:${(bin.count / max) * 100}%"></span></div>
                <strong>${bin.count}</strong>
              </div>
            `).join("")}
          </div>
        </div>
      `;
    }

    function guideMarkup(page) {
      if (!page.pageWidth || !page.pageHeight) return "";
      const guideCount = 24;
      const lines = [];
      for (let index = 1; index < guideCount; index += 1) {
        const y = (page.pageHeight / guideCount) * index;
        const lineClass = index % 4 === 0 ? "major" : "minor";
        lines.push(`<line class="${lineClass}" x1="0" y1="${y}" x2="${page.pageWidth}" y2="${y}" />`);
      }
      return `<svg class="guide-overlay" viewBox="0 0 ${page.pageWidth} ${page.pageHeight}" preserveAspectRatio="none">${lines.join("")}</svg>`;
    }

    function overlayMarkup(page) {
      if (!page.rectification || !page.overlayLines.length) return "";
      const lineMarkup = page.overlayLines.map(line => {
        const [start, end] = line;
        return `<line x1="${start.x}" y1="${start.y}" x2="${end.x}" y2="${end.y}" />`;
      }).join("");
      return `<svg class="quad-overlay" viewBox="0 0 ${page.pageWidth} ${page.pageHeight}" preserveAspectRatio="none">${lineMarkup}</svg>`;
    }

    function pageCardMarkup(page) {
      const rating = ratings[page.id] || "";
      const angleClass = page.angleDegrees == null ? "angle-badge none" : "angle-badge";
      return `
        <article class="page-card ${page.angleDegrees == null ? "no-estimate" : "estimated"}" data-page-id="${page.id}" data-rating-state="${rating}" data-estimated="${page.angleDegrees == null ? "0" : "1"}">
          <div class="page-header">
            <div>
              <h3>Page ${page.pageNumber}</h3>
              <div class="page-meta">${page.pdfName}</div>
            </div>
            <span class="${angleClass}">${page.angleDegrees == null ? "No-op" : formatAngle(page.angleDegrees)}</span>
          </div>
          <div class="visuals">
            <div class="visual">
              <span class="visual-label">Source</span>
              <img loading="lazy" src="${page.sourceImage}" alt="Source page ${page.pageNumber} from ${page.pdfName}">
              ${guideMarkup(page)}
              ${overlayMarkup(page)}
            </div>
            <div class="visual">
              ${page.rectifiedImage ? `
                <span class="visual-label">Rectified</span>
                <img loading="lazy" src="${page.rectifiedImage}" alt="Rectified page ${page.pageNumber} from ${page.pdfName}">
                ${guideMarkup(page)}
              ` : `
                <div class="placeholder">
                  <div>
                    <strong>No automatic correction</strong>
                    <p>Estimated angle stayed under the current threshold.</p>
                  </div>
                </div>
              `}
            </div>
          </div>
          <div class="review-buttons">
            <button data-rating="accept" class="${rating === "accept" ? "active" : ""}">Accept</button>
            <button data-rating="needs-work" class="${rating === "needs-work" ? "active" : ""}">Needs Work</button>
            <button data-rating="skip" class="${rating === "skip" ? "active" : ""}">Skip</button>
            <button data-rating="clear">Clear</button>
          </div>
        </article>
      `;
    }

    function pdfDetailMarkup(summary) {
      const pages = report.pages.filter(page => page.pdfName === summary.pdfName);
      return `
        <details class="pdf-group" open>
          <summary>
            <div>
              <strong>${summary.pdfName}</strong>
              <div class="page-meta">${summary.pageCount} pages, ${summary.estimatedCount} corrected, median |angle| ${summary.medianAbsoluteAngle == null ? "n/a" : `${summary.medianAbsoluteAngle.toFixed(3)}°`}</div>
            </div>
            <div class="page-meta">P90 |angle| ${summary.p90AbsoluteAngle == null ? "n/a" : `${summary.p90AbsoluteAngle.toFixed(3)}°`}</div>
          </summary>
          <div class="page-grid">
            ${pages.map(pageCardMarkup).join("")}
          </div>
        </details>
      `;
    }

    function render() {
      const app = document.getElementById("app");
      app.innerHTML = `
        <section class="hero">
          <div>
            <h1>Deskew Review</h1>
            <p class="subtle">This report batches the current automatic rectification prototype across the local <code>lightly_skewed</code> set. Each card shows the source page with the estimated quad overlay and the resulting rectified preview. Ratings are stored locally in your browser.</p>
            <div class="stats">
              <div class="stat">
                <span class="label">PDFs</span>
                <div class="value">${report.overall.totalPDFs}</div>
                <div class="note">${report.overall.totalPages} pages total</div>
              </div>
              <div class="stat">
                <span class="label">Auto-Corrected</span>
                <div class="value">${report.overall.estimatedPages}</div>
                <div class="note">${formatPercent(report.overall.estimatedShare)} of all pages</div>
              </div>
              <div class="stat">
                <span class="label">Median |Angle|</span>
                <div class="value">${report.overall.medianAbsoluteAngle == null ? "n/a" : `${report.overall.medianAbsoluteAngle.toFixed(3)}°`}</div>
                <div class="note">P95 ${report.overall.p95AbsoluteAngle == null ? "n/a" : `${report.overall.p95AbsoluteAngle.toFixed(3)}°`}</div>
              </div>
              <div class="stat">
                <span class="label">Mean Signed</span>
                <div class="value">${report.overall.meanSignedAngle == null ? "n/a" : `${report.overall.meanSignedAngle.toFixed(3)}°`}</div>
                <div class="note">Median ${report.overall.medianSignedAngle == null ? "n/a" : `${report.overall.medianSignedAngle.toFixed(3)}°`}</div>
              </div>
              <div class="stat">
                <span class="label">Max |Angle|</span>
                <div class="value">${report.overall.maxAbsoluteAngle == null ? "n/a" : `${report.overall.maxAbsoluteAngle.toFixed(3)}°`}</div>
                <div class="note">Largest correction currently proposed</div>
              </div>
              <div class="stat">
                <span class="label">Generated</span>
                <div class="value" style="font-size:1rem">${new Date(report.generatedAt).toLocaleString()}</div>
                <div class="note">${report.sourceDirectory}</div>
              </div>
            </div>
          </div>
          <div class="panel section">
            <h3>Review Notes</h3>
            <p class="subtle" style="margin-top:12px">The current estimator is intentionally conservative. Pages under the correction threshold are left alone. Ratings persist in local storage, so you can close the file and keep working through it later.</p>
            <div class="footer-note">Accepted pages should look straighter without obvious content drift or bad cropping. “Needs Work” is the right choice when the quad is pointed the wrong way, too aggressive, or visibly misaligned with the staff field.</div>
          </div>
        </section>
        <section class="histograms">
          ${histogramMarkup("Signed Angle Distribution", report.overall.signedHistogram)}
          ${histogramMarkup("Absolute Angle Distribution", report.overall.absoluteHistogram)}
        </section>
        <section class="panel section">
          <h2>Per-PDF Summary</h2>
          <table>
            <thead>
              <tr>
                <th>PDF</th>
                <th>Pages</th>
                <th>Estimated</th>
                <th>Mean Signed</th>
                <th>Median |Angle|</th>
                <th>P90 |Angle|</th>
                <th>Max |Angle|</th>
              </tr>
            </thead>
            <tbody>
              ${report.perPDF.map(summary => `
                <tr>
                  <td>${summary.pdfName}</td>
                  <td>${summary.pageCount}</td>
                  <td>${summary.estimatedCount} (${formatPercent(summary.estimatedShare)})</td>
                  <td>${summary.meanSignedAngle == null ? "n/a" : `${summary.meanSignedAngle.toFixed(3)}°`}</td>
                  <td>${summary.medianAbsoluteAngle == null ? "n/a" : `${summary.medianAbsoluteAngle.toFixed(3)}°`}</td>
                  <td>${summary.p90AbsoluteAngle == null ? "n/a" : `${summary.p90AbsoluteAngle.toFixed(3)}°`}</td>
                  <td>${summary.maxAbsoluteAngle == null ? "n/a" : `${summary.maxAbsoluteAngle.toFixed(3)}°`}</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
          <div class="controls">
            <button id="expand-all">Expand All</button>
            <button id="collapse-all">Collapse All</button>
            <button id="show-all">Show All</button>
            <button id="show-estimated">Only Auto-Corrected</button>
          </div>
        </section>
        <section class="section" id="pages">
          ${report.perPDF.map(pdfDetailMarkup).join("")}
        </section>
      `;

      document.querySelectorAll(".review-buttons button").forEach(button => {
        button.addEventListener("click", event => {
          const target = event.currentTarget;
          const card = target.closest(".page-card");
          const pageId = card.dataset.pageId;
          const rating = target.dataset.rating;

          if (rating === "clear") {
            delete ratings[pageId];
          } else {
            ratings[pageId] = rating;
          }

          saveRatings(ratings);
          card.dataset.ratingState = ratings[pageId] || "";
          card.querySelectorAll(".review-buttons button").forEach(buttonEl => {
            buttonEl.classList.toggle("active", buttonEl.dataset.rating && ratings[pageId] === buttonEl.dataset.rating);
          });
        });
      });

      document.getElementById("expand-all").addEventListener("click", () => {
        document.querySelectorAll("details").forEach(detail => { detail.open = true; });
      });
      document.getElementById("collapse-all").addEventListener("click", () => {
        document.querySelectorAll("details").forEach(detail => { detail.open = false; });
      });
      document.getElementById("show-all").addEventListener("click", () => {
        document.querySelectorAll(".page-card").forEach(card => { card.style.display = ""; });
      });
      document.getElementById("show-estimated").addEventListener("click", () => {
        document.querySelectorAll(".page-card").forEach(card => {
          card.style.display = card.dataset.estimated === "1" ? "" : "none";
        });
      });
    }

    render();
  </script>
</body>
</html>
"""
}
