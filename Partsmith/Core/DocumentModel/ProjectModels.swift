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

    static let empty = ProjectData(
        id: UUID(),
        projectName: "Untitled Partsmith Project",
        createdAt: .now,
        modifiedAt: .now,
        sourceFilename: nil,
        pageCount: 0,
        projectSettings: .default,
        parts: [],
        bands: []
    )
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
    var headerDisplayMode: HeaderDisplayMode
    var headerSelection: SourceHeaderSelection?
    var defaultTitleText: String
    var defaultComposerText: String

    init(
        outputPageSize: OutputPageSize,
        margins: PageMargins,
        defaultScale: Double,
        interSystemGap: Double,
        headerDisplayMode: HeaderDisplayMode = .sourceSelection,
        headerSelection: SourceHeaderSelection? = nil,
        defaultTitleText: String = "",
        defaultComposerText: String = ""
    ) {
        self.outputPageSize = outputPageSize
        self.margins = margins
        self.defaultScale = defaultScale
        self.interSystemGap = interSystemGap
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
            .sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                return $0.createdAt < $1.createdAt
            }
    }

    func bands(on pageIndex: Int) -> [BandModel] {
        bands
            .filter { $0.pageIndex == pageIndex }
            .sorted {
                if $0.partID != $1.partID {
                    return $0.partID.uuidString < $1.partID.uuidString
                }
                return $0.createdAt < $1.createdAt
            }
    }
}
