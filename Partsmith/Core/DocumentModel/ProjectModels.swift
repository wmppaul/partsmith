import AppKit
import CoreGraphics
import SwiftUI

struct ProjectData: Codable, Equatable {
    var id: UUID
    var projectName: String
    var createdAt: Date
    var modifiedAt: Date
    var sourceFilename: String?
    var pageCount: Int
    var projectSettings: ProjectSettings
    var parts: [PartModel]
    var bands: [BandModel]
    var pageRectifications: [PageRectification]

    static let empty = ProjectData(
        id: UUID(),
        projectName: "Untitled Partsmith Project",
        createdAt: .now,
        modifiedAt: .now,
        sourceFilename: nil,
        pageCount: 0,
        projectSettings: .default,
        parts: [],
        bands: [],
        pageRectifications: []
    )

    private enum CodingKeys: String, CodingKey {
        case id
        case projectName
        case createdAt
        case modifiedAt
        case sourceFilename
        case pageCount
        case projectSettings
        case parts
        case bands
        case pageRectifications
    }

    init(
        id: UUID,
        projectName: String,
        createdAt: Date,
        modifiedAt: Date,
        sourceFilename: String?,
        pageCount: Int,
        projectSettings: ProjectSettings,
        parts: [PartModel],
        bands: [BandModel],
        pageRectifications: [PageRectification]
    ) {
        self.id = id
        self.projectName = projectName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sourceFilename = sourceFilename
        self.pageCount = pageCount
        self.projectSettings = projectSettings
        self.parts = parts
        self.bands = bands
        self.pageRectifications = pageRectifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectName = try container.decode(String.self, forKey: .projectName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        sourceFilename = try container.decodeIfPresent(String.self, forKey: .sourceFilename)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        projectSettings = try container.decodeIfPresent(ProjectSettings.self, forKey: .projectSettings) ?? .default
        parts = try container.decodeIfPresent([PartModel].self, forKey: .parts) ?? []
        bands = try container.decodeIfPresent([BandModel].self, forKey: .bands) ?? []
        pageRectifications = try container.decodeIfPresent([PageRectification].self, forKey: .pageRectifications) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectName, forKey: .projectName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(sourceFilename, forKey: .sourceFilename)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(projectSettings, forKey: .projectSettings)
        try container.encode(parts, forKey: .parts)
        try container.encode(bands, forKey: .bands)
        try container.encode(pageRectifications, forKey: .pageRectifications)
    }
}

struct FractionPoint: Codable, Equatable {
    var x: Double
    var y: Double

    func normalized() -> FractionPoint {
        FractionPoint(
            x: max(0, min(x, 1)),
            y: max(0, min(y, 1))
        )
    }
}

struct PageRectification: Codable, Equatable, Identifiable {
    var id: Int { pageIndex }

    var pageIndex: Int
    var topLeft: FractionPoint
    var topRight: FractionPoint
    var bottomRight: FractionPoint
    var bottomLeft: FractionPoint

    func normalized() -> PageRectification {
        var copy = self
        copy.topLeft = topLeft.normalized()
        copy.topRight = topRight.normalized()
        copy.bottomRight = bottomRight.normalized()
        copy.bottomLeft = bottomLeft.normalized()
        return copy
    }

    static func `default`(pageIndex: Int) -> PageRectification {
        PageRectification(
            pageIndex: pageIndex,
            topLeft: FractionPoint(x: 0.08, y: 0.08),
            topRight: FractionPoint(x: 0.92, y: 0.08),
            bottomRight: FractionPoint(x: 0.92, y: 0.92),
            bottomLeft: FractionPoint(x: 0.08, y: 0.92)
        )
    }
}

enum HeaderDisplayMode: String, Codable, CaseIterable, Identifiable {
    case typed
    case sourceSelection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .typed:
            return "Typed"
        case .sourceSelection:
            return "Source Header"
        }
    }
}

struct SourceHeaderSelection: Codable, Equatable {
    var pageIndex: Int
    var topFraction: Double
    var bottomFraction: Double
    var leftFraction: Double
    var rightFraction: Double

    func normalized() -> SourceHeaderSelection {
        var copy = self
        copy.topFraction = max(0, min(topFraction, 0.98))
        copy.bottomFraction = max(copy.topFraction + 0.02, min(bottomFraction, 1.0))
        copy.leftFraction = max(0, min(leftFraction, 0.95))
        copy.rightFraction = max(0, min(rightFraction, 0.95))

        if copy.leftFraction + copy.rightFraction > 0.97 {
            copy.rightFraction = max(0, 0.97 - copy.leftFraction)
        }

        return copy
    }

    func cropRect(in pageBounds: CGRect) -> CGRect {
        let normalized = normalized()
        let minX = pageBounds.minX + pageBounds.width * normalized.leftFraction
        let maxX = pageBounds.maxX - pageBounds.width * normalized.rightFraction
        let maxY = pageBounds.maxY - pageBounds.height * normalized.topFraction
        let minY = pageBounds.maxY - pageBounds.height * normalized.bottomFraction
        return CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
    }
}

struct ProjectSettings: Codable, Equatable {
    var outputPageSize: OutputPageSize
    var margins: PageMargins
    var defaultScale: Double
    var interSystemGap: Double
    var showTitleBlock: Bool
    var showPartNameInHeader: Bool
    var headerDisplayMode: HeaderDisplayMode
    var headerSelection: SourceHeaderSelection?
    var defaultTitleText: String
    var defaultComposerText: String

    init(
        outputPageSize: OutputPageSize,
        margins: PageMargins,
        defaultScale: Double,
        interSystemGap: Double,
        showTitleBlock: Bool = true,
        showPartNameInHeader: Bool = false,
        headerDisplayMode: HeaderDisplayMode = .sourceSelection,
        headerSelection: SourceHeaderSelection? = nil,
        defaultTitleText: String = "",
        defaultComposerText: String = ""
    ) {
        self.outputPageSize = outputPageSize
        self.margins = margins
        self.defaultScale = defaultScale
        self.interSystemGap = interSystemGap
        self.showTitleBlock = showTitleBlock
        self.showPartNameInHeader = showPartNameInHeader
        self.headerDisplayMode = headerDisplayMode
        self.headerSelection = headerSelection
        self.defaultTitleText = defaultTitleText
        self.defaultComposerText = defaultComposerText
    }

    static let `default` = ProjectSettings(
        outputPageSize: .letter,
        margins: .standard,
        defaultScale: 1.0,
        interSystemGap: 16,
        showTitleBlock: true,
        showPartNameInHeader: false,
        headerDisplayMode: .sourceSelection,
        headerSelection: nil,
        defaultTitleText: "",
        defaultComposerText: ""
    )

    private enum CodingKeys: String, CodingKey {
        case outputPageSize
        case margins
        case defaultScale
        case interSystemGap
        case showTitleBlock
        case showPartNameInHeader
        case headerDisplayMode
        case headerSelection
        case defaultTitleText
        case defaultComposerText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputPageSize = try container.decodeIfPresent(OutputPageSize.self, forKey: .outputPageSize) ?? .letter
        margins = try container.decodeIfPresent(PageMargins.self, forKey: .margins) ?? .standard
        defaultScale = try container.decodeIfPresent(Double.self, forKey: .defaultScale) ?? 1.0
        interSystemGap = try container.decodeIfPresent(Double.self, forKey: .interSystemGap) ?? 16
        showTitleBlock = try container.decodeIfPresent(Bool.self, forKey: .showTitleBlock) ?? true
        showPartNameInHeader = try container.decodeIfPresent(Bool.self, forKey: .showPartNameInHeader) ?? false
        headerDisplayMode = try container.decodeIfPresent(HeaderDisplayMode.self, forKey: .headerDisplayMode) ?? .sourceSelection
        headerSelection = try container.decodeIfPresent(SourceHeaderSelection.self, forKey: .headerSelection)
        defaultTitleText = try container.decodeIfPresent(String.self, forKey: .defaultTitleText) ?? ""
        defaultComposerText = try container.decodeIfPresent(String.self, forKey: .defaultComposerText) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(outputPageSize, forKey: .outputPageSize)
        try container.encode(margins, forKey: .margins)
        try container.encode(defaultScale, forKey: .defaultScale)
        try container.encode(interSystemGap, forKey: .interSystemGap)
        try container.encode(showTitleBlock, forKey: .showTitleBlock)
        try container.encode(showPartNameInHeader, forKey: .showPartNameInHeader)
        try container.encode(headerDisplayMode, forKey: .headerDisplayMode)
        try container.encodeIfPresent(headerSelection, forKey: .headerSelection)
        try container.encode(defaultTitleText, forKey: .defaultTitleText)
        try container.encode(defaultComposerText, forKey: .defaultComposerText)
    }
}

enum OutputPageSize: String, Codable, CaseIterable, Identifiable {
    case letter = "Letter"
    case a4 = "A4"

    var id: String { rawValue }

    var pointsSize: CGSize {
        switch self {
        case .letter:
            return CGSize(width: 612, height: 792)
        case .a4:
            return CGSize(width: 595, height: 842)
        }
    }
}

struct PageMargins: Codable, Equatable {
    var top: Double
    var leading: Double
    var bottom: Double
    var trailing: Double

    static let standard = PageMargins(top: 48, leading: 48, bottom: 48, trailing: 48)
}

struct PartModel: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var color: ColorData
    var layoutSettings: PartLayoutSettings
    var createdAt: Date

    var swiftUIColor: Color {
        color.swiftUIColor
    }

    var nsColor: NSColor {
        color.nsColor
    }
}

struct PartLayoutSettings: Codable, Equatable {
    var showTitle: Bool
    var titleText: String
    var composerText: String
    var scale: Double
    var interSystemGap: Double
    var showPartNameLabel: Bool

    init(
        showTitle: Bool,
        titleText: String,
        composerText: String,
        scale: Double,
        interSystemGap: Double,
        showPartNameLabel: Bool = false
    ) {
        self.showTitle = showTitle
        self.titleText = titleText
        self.composerText = composerText
        self.scale = scale
        self.interSystemGap = interSystemGap
        self.showPartNameLabel = showPartNameLabel
    }

    static let `default` = PartLayoutSettings(
        showTitle: true,
        titleText: "",
        composerText: "",
        scale: 1.0,
        interSystemGap: 16,
        showPartNameLabel: false
    )

    private enum CodingKeys: String, CodingKey {
        case showTitle
        case titleText
        case composerText
        case scale
        case interSystemGap
        case showPartNameLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showTitle = try container.decodeIfPresent(Bool.self, forKey: .showTitle) ?? true
        titleText = try container.decodeIfPresent(String.self, forKey: .titleText) ?? ""
        composerText = try container.decodeIfPresent(String.self, forKey: .composerText) ?? ""
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        interSystemGap = try container.decodeIfPresent(Double.self, forKey: .interSystemGap) ?? 16
        showPartNameLabel = try container.decodeIfPresent(Bool.self, forKey: .showPartNameLabel) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showTitle, forKey: .showTitle)
        try container.encode(titleText, forKey: .titleText)
        try container.encode(composerText, forKey: .composerText)
        try container.encode(scale, forKey: .scale)
        try container.encode(interSystemGap, forKey: .interSystemGap)
        try container.encode(showPartNameLabel, forKey: .showPartNameLabel)
    }
}

enum BarNumberMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Auto"
        case .manual:
            return "Manual"
        case .hidden:
            return "Hidden"
        }
    }
}

enum BarNumberDetectionMethod: String, Codable {
    case pdfText
    case ocr
    case nearbyBand

    var title: String {
        switch self {
        case .pdfText:
            return "PDF Text"
        case .ocr:
            return "OCR"
        case .nearbyBand:
            return "Nearby System"
        }
    }
}

struct BandModel: Codable, Identifiable, Equatable {
    var id: UUID
    var pageIndex: Int
    var partID: UUID
    var topFraction: Double
    var bottomFraction: Double
    var leftFraction: Double
    var rightFraction: Double
    var excluded: Bool
    var createdAt: Date
    var barNumberMode: BarNumberMode
    var barNumberValue: Int?
    var barNumberConfidence: Double?
    var barNumberDetectionMethod: BarNumberDetectionMethod?

    private enum CodingKeys: String, CodingKey {
        case id
        case pageIndex
        case partID
        case topFraction
        case bottomFraction
        case leftFraction
        case rightFraction
        case excluded
        case createdAt
        case barNumberMode
        case barNumberValue
        case barNumberConfidence
        case barNumberDetectionMethod
    }

    init(
        id: UUID,
        pageIndex: Int,
        partID: UUID,
        topFraction: Double,
        bottomFraction: Double,
        leftFraction: Double,
        rightFraction: Double,
        excluded: Bool,
        createdAt: Date,
        barNumberMode: BarNumberMode = .automatic,
        barNumberValue: Int? = nil,
        barNumberConfidence: Double? = nil,
        barNumberDetectionMethod: BarNumberDetectionMethod? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.partID = partID
        self.topFraction = topFraction
        self.bottomFraction = bottomFraction
        self.leftFraction = leftFraction
        self.rightFraction = rightFraction
        self.excluded = excluded
        self.createdAt = createdAt
        self.barNumberMode = barNumberMode
        self.barNumberValue = barNumberValue
        self.barNumberConfidence = barNumberConfidence
        self.barNumberDetectionMethod = barNumberDetectionMethod
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pageIndex = try container.decode(Int.self, forKey: .pageIndex)
        partID = try container.decode(UUID.self, forKey: .partID)
        topFraction = try container.decode(Double.self, forKey: .topFraction)
        bottomFraction = try container.decode(Double.self, forKey: .bottomFraction)
        leftFraction = try container.decodeIfPresent(Double.self, forKey: .leftFraction) ?? 0
        rightFraction = try container.decodeIfPresent(Double.self, forKey: .rightFraction) ?? 0
        excluded = try container.decodeIfPresent(Bool.self, forKey: .excluded) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        barNumberMode = try container.decodeIfPresent(BarNumberMode.self, forKey: .barNumberMode) ?? .automatic
        barNumberValue = try container.decodeIfPresent(Int.self, forKey: .barNumberValue)
        barNumberConfidence = try container.decodeIfPresent(Double.self, forKey: .barNumberConfidence)
        barNumberDetectionMethod = try container.decodeIfPresent(
            BarNumberDetectionMethod.self,
            forKey: .barNumberDetectionMethod
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pageIndex, forKey: .pageIndex)
        try container.encode(partID, forKey: .partID)
        try container.encode(topFraction, forKey: .topFraction)
        try container.encode(bottomFraction, forKey: .bottomFraction)
        try container.encode(leftFraction, forKey: .leftFraction)
        try container.encode(rightFraction, forKey: .rightFraction)
        try container.encode(excluded, forKey: .excluded)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(barNumberMode, forKey: .barNumberMode)
        try container.encodeIfPresent(barNumberValue, forKey: .barNumberValue)
        try container.encodeIfPresent(barNumberConfidence, forKey: .barNumberConfidence)
        try container.encodeIfPresent(barNumberDetectionMethod, forKey: .barNumberDetectionMethod)
    }

    func normalized() -> BandModel {
        var copy = self
        copy.topFraction = max(0, min(topFraction, 0.98))
        copy.bottomFraction = max(copy.topFraction + 0.02, min(bottomFraction, 1.0))
        copy.leftFraction = max(0, min(leftFraction, 0.9))
        copy.rightFraction = max(0, min(rightFraction, 0.9))
        return copy
    }

    func cropRect(in pageBounds: CGRect) -> CGRect {
        let normalized = normalized()
        let minX = pageBounds.minX + pageBounds.width * normalized.leftFraction
        let maxX = pageBounds.maxX - pageBounds.width * normalized.rightFraction
        let maxY = pageBounds.maxY - pageBounds.height * normalized.topFraction
        let minY = pageBounds.maxY - pageBounds.height * normalized.bottomFraction
        return CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
    }

    var displayedBarNumber: Int? {
        switch barNumberMode {
        case .automatic, .manual:
            return barNumberValue
        case .hidden:
            return nil
        }
    }
}

struct ColorData: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let deviceColor = nsColor.usingColorSpace(.deviceRGB) ?? .controlAccentColor
        self.red = Double(deviceColor.redComponent)
        self.green = Double(deviceColor.greenComponent)
        self.blue = Double(deviceColor.blueComponent)
        self.alpha = Double(deviceColor.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }
}

enum CanvasMode: String, CaseIterable, Identifiable {
    case source
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source:
            return "Source"
        case .preview:
            return "Preview"
        }
    }
}

enum ZoomMode: String, CaseIterable, Identifiable {
    case fitWidth
    case fitPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fitWidth:
            return "Fit Width"
        case .fitPage:
            return "Fit Page"
        }
    }
}

extension ProjectData {
    func sortedBands(for partID: UUID) -> [BandModel] {
        bands
            .filter { $0.partID == partID }
            .sorted(by: Self.bandAppearsEarlierInScore(_:_:))
    }

    func bands(on pageIndex: Int) -> [BandModel] {
        bands
            .filter { $0.pageIndex == pageIndex }
            .sorted(by: Self.bandAppearsEarlierInScore(_:_:))
    }

    // Use score position instead of insertion time so backfilled staves land in the expected export order.
    private static func bandAppearsEarlierInScore(_ lhs: BandModel, _ rhs: BandModel) -> Bool {
        if lhs.pageIndex != rhs.pageIndex {
            return lhs.pageIndex < rhs.pageIndex
        }

        let lhsNormalized = lhs.normalized()
        let rhsNormalized = rhs.normalized()

        if lhsNormalized.topFraction != rhsNormalized.topFraction {
            return lhsNormalized.topFraction < rhsNormalized.topFraction
        }

        if lhsNormalized.bottomFraction != rhsNormalized.bottomFraction {
            return lhsNormalized.bottomFraction < rhsNormalized.bottomFraction
        }

        if lhsNormalized.leftFraction != rhsNormalized.leftFraction {
            return lhsNormalized.leftFraction < rhsNormalized.leftFraction
        }

        if lhsNormalized.rightFraction != rhsNormalized.rightFraction {
            return lhsNormalized.rightFraction < rhsNormalized.rightFraction
        }

        if lhs.partID != rhs.partID {
            return lhs.partID.uuidString < rhs.partID.uuidString
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}
