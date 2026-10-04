// Compile against the production model and layout engine from the repository root:
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
//   -module-cache-path /tmp/partsmith-swift-cache \
//   Partsmith/Core/DocumentModel/ProjectModels.swift \
//   Partsmith/Core/Layout/PartLayoutEngine.swift tools/test_layout.swift \
//   -o /tmp/partsmith-layout-tests
// /tmp/partsmith-layout-tests
import Foundation
import PDFKit

@main
struct LayoutRegressionTests {
    static let sourceBounds = CGRect(x: 12, y: -8, width: 600, height: 800)
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError(message) }
    }

    static func project() -> ProjectData {
        var project = ProjectData.empty
        // Historical fixtures use the original page margins explicitly, so a
        // new-document default does not rewrite their geometry expectations.
        project.projectSettings.margins = PageMargins(top: 48, leading: 48, bottom: 48, trailing: 48)
        let part = PartModel(id: UUID(), name: "Violin", color: ColorData(red: 0.2, green: 0.4, blue: 0.8),
                             layoutSettings: .default, createdAt: .now)
        project.parts = [part]
        project.pageCount = 3
        project.projectSettings.headerDisplayMode = .typed
        project.bands = [band(partID: part.id, page: 0, top: 0.2, bottom: 0.4)]
        return project
    }

    static func band(partID: UUID, page: Int, top: Double, bottom: Double) -> BandModel {
        BandModel(id: UUID(), pageIndex: page, partID: partID, topFraction: top, bottomFraction: bottom,
                  leftFraction: 0.08, rightFraction: 0.06, excluded: false, createdAt: .now,
                  barNumberMode: .hidden)
    }

    static func plan(_ project: ProjectData, horizontalBounds: ((BandModel, CGRect) -> CGRect?)? = nil) throws -> PartRenderPlan {
        try PartLayoutEngine.makePlan(project: project,
                                      pageBoundsProvider: { (0..<3).contains($0) ? sourceBounds : nil },
                                      partID: project.parts[0].id, horizontalContentBoundsProvider: horizontalBounds)
    }

    static func expectError(_ project: ProjectData, matches: (PartLayoutError) -> Bool, _ message: String) {
        do {
            _ = try plan(project)
            fatalError("Expected error: \(message)")
        } catch let error as PartLayoutError {
            check(matches(error), message)
        } catch {
            fatalError("Unexpected error: \(error)")
        }
    }

    static func verifyGeometry(_ plan: PartRenderPlan, project: ProjectData) {
        var margins = project.projectSettings.margins
        if let side = project.parts[0].layoutSettings.sideMarginPoints {
            margins.leading = side; margins.trailing = side
        }
        let content = CGRect(x: margins.leading, y: margins.bottom,
                             width: plan.pageSize.width - margins.leading - margins.trailing,
                             height: plan.pageSize.height - margins.top - margins.bottom)
        let expected = project.sortedBands(for: plan.part.id).filter { !$0.excluded }.map(\.id)
        check(plan.pages.flatMap(\.placements).map(\.bandID) == expected, "Every included band appears once, in score order")
        for page in plan.pages {
            var previousBottom = plan.partNameRect?.minY ?? content.maxY
            if page.drawsTitle {
                previousBottom = plan.headerPlacement?.destinationRect.minY ?? plan.titleBlockRect?.minY ?? previousBottom
            }
            for placement in page.placements {
                let rect = placement.destinationRect
                if let labelRect = placement.editorialLabelRect {
                    check(content.insetBy(dx: -0.001, dy: -0.001).contains(labelRect), "Editorial labels stay inside margins")
                    check(labelRect.maxY <= previousBottom + 0.001 && labelRect.minY >= rect.maxY,
                          "Editorial labels never overlap previous bands or their own music")
                }
                check(rect.width > 0 && rect.height > 0, "All output crops have positive area")
                check(content.insetBy(dx: -0.001, dy: -0.001).contains(rect), "Music must remain within all four margins")
                check(rect.maxY <= previousBottom + 0.001, "Music must not overlap headers or preceding bands")
                check(abs(rect.width / rect.height - placement.sourceRect.width / placement.sourceRect.height) < 0.00001,
                      "Music must retain its aspect ratio")
                previousBottom = rect.minY
            }
        }
        if let header = plan.headerPlacement {
            check(content.insetBy(dx: -0.001, dy: -0.001).contains(header.destinationRect), "Source header stays inside margins")
        }
    }

    static func main() throws {
        let freshMargins = ProjectData.empty.projectSettings.margins
        check(freshMargins == PageMargins(top: 48, leading: 18, bottom: 48, trailing: 18),
              "New projects use 18-point side margins and retain 48-point vertical margins")
        var fresh = project()
        fresh.projectSettings.margins = freshMargins
        let freshPlan = try plan(fresh)
        check(freshPlan.pages[0].placements[0].destinationRect.minX == 18 &&
              freshPlan.pages[0].placements[0].destinationRect.maxX == 594,
              "New-project margins provide the full 576-point music width on Letter paper")
        verifyGeometry(freshPlan, project: fresh)
        let savedMargins = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(project()))
        check(savedMargins.projectSettings.margins == PageMargins(top: 48, leading: 48, bottom: 48, trailing: 48),
              "Saved 48-point project margins remain unchanged by new defaults")
        var standard = project()
        verifyGeometry(try plan(standard), project: standard)

        standard.projectSettings.margins = PageMargins(top: 12, leading: 83, bottom: 61, trailing: 19)
        standard.projectSettings.showPartNameInHeader = true
        standard.parts[0].layoutSettings.scale = 1.4
        verifyGeometry(try plan(standard), project: standard)

        var tall = standard
        tall.bands[0].topFraction = 0
        tall.bands[0].bottomFraction = 1
        tall.bands[0].leftFraction = 0.45
        tall.bands[0].rightFraction = 0.45
        verifyGeometry(try plan(tall), project: tall)

        tall.projectSettings.headerDisplayMode = .sourceSelection
        tall.projectSettings.headerSelection = SourceHeaderSelection(pageIndex: 0, topFraction: 0, bottomFraction: 1,
                                                                    leftFraction: 0, rightFraction: 0)
        verifyGeometry(try plan(tall), project: tall)

        var invalid = project()
        invalid.bands[0].pageIndex = 99
        expectError(invalid, matches: { if case .missingSourcePage(99) = $0 { return true }; return false }, "Missing bands cannot be silently omitted")
        invalid.bands[0].pageIndex = -1
        expectError(invalid, matches: { if case .missingSourcePage(-1) = $0 { return true }; return false }, "Negative page indices fail before querying PDFKit")
        invalid = project()
        invalid.bands[0].leftFraction = 0.6
        invalid.bands[0].rightFraction = 0.5
        expectError(invalid, matches: { if case .invalidBand = $0 { return true }; return false }, "Crossed crop sides are rejected")
        invalid = project()
        invalid.bands[0].topFraction = .nan
        expectError(invalid, matches: { if case .invalidBand = $0 { return true }; return false }, "Nonfinite crop geometry is rejected")
        invalid = project()
        invalid.projectSettings.margins.leading = 700
        expectError(invalid, matches: { if case .invalidLayoutSettings = $0 { return true }; return false }, "Impossible margins are rejected")
        invalid = project()
        invalid.projectSettings.headerDisplayMode = .sourceSelection
        invalid.projectSettings.headerSelection = SourceHeaderSelection(pageIndex: 99, topFraction: 0, bottomFraction: 0.2,
                                                                       leftFraction: 0, rightFraction: 0)
        expectError(invalid, matches: { if case .missingSourcePage(99) = $0 { return true }; return false }, "Missing source headers are not silently substituted")
        invalid.projectSettings.showTitleBlock = false
        verifyGeometry(try plan(invalid), project: invalid)

        var thin = project()
        thin.bands[0].topFraction = 0.992
        thin.bands[0].bottomFraction = 0.999
        check(thin.bands[0].normalized() == thin.bands[0], "Dense-score crop normalization preserves sub-2% band heights")
        let thinPlan = try plan(thin)
        check(abs(thinPlan.pages[0].placements[0].sourceRect.height - sourceBounds.height * 0.007) < 0.0001,
              "Validated imported crop coordinates must not be expanded to a neighboring staff")

        var masked = project()
        masked.bands[0].exclusions = [BandExclusion(topFraction: 0.25, bottomFraction: 0.30,
                                                   leftFraction: 0.20, rightFraction: 0.70)]
        let maskPlan = try plan(masked)
        let maskRect = maskPlan.pages[0].placements[0].exclusionRects[0]
        check(abs(maskRect.minX - 120) < 0.00001 && abs(maskRect.minY - 604) < 0.00001
              && abs(maskRect.width - 60) < 0.00001 && abs(maskRect.height - 40) < 0.00001,
              "Whiteouts transform from full source-page coordinates, preserving PDF y orientation")
        let encodedMask = try JSONEncoder().encode(masked.bands[0])
        let decodedMask = try JSONDecoder().decode(BandModel.self, from: encodedMask)
        check(decodedMask == masked.bands[0],
              "Whiteout geometry and stable identity survive project roundtrip")
        masked.bands[0].exclusions[0].topFraction = 0.19
        expectError(masked, matches: { if case .invalidExclusion = $0 { return true }; return false }, "Masks outside the crop must fail export")
        masked.bands[0].exclusions[0].topFraction = .infinity
        expectError(masked, matches: { if case .invalidExclusion = $0 { return true }; return false }, "Nonfinite mask geometry must fail export")

        var annotated = project()
        annotated.bands[0].pageBreakBefore = true
        annotated.bands[0].editorialLabel = "Tempo primo - verified source direction"
        var second = band(partID: annotated.parts[0].id, page: 1, top: 0.2, bottom: 0.4)
        second.pageBreakBefore = true
        second.editorialLabel = String(repeating: "Keep this complete editorial instruction when wrapping. ", count: 8)
        annotated.bands.append(second)
        let annotatedPlan = try plan(annotated)
        check(annotatedPlan.pages.count == 2 && annotatedPlan.pages.allSatisfy { $0.placements.count == 1 },
              "Explicit breaks start new pages but never insert a blank page before the first band")
        check(annotatedPlan.pages[1].placements[0].editorialLabelRect!.height > 14,
              "Long editorial text reserves multiple lines instead of clipping")
        check(annotatedPlan.pages[1].placements[0].editorialLabel == second.editorialLabel.trimmingCharacters(in: .whitespacesAndNewlines),
              "All editorial text reaches the render plan")
        verifyGeometry(annotatedPlan, project: annotated)
        let annotatedRoundtrip = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(annotated))
        check(annotatedRoundtrip == annotated, "Editorial labels and explicit page breaks survive persistence")
        annotated.bands[0].editorialLabel = String(repeating: "This direction must not be silently dropped. ", count: 400)
        expectError(annotated, matches: { if case .editorialLabelDoesNotFit = $0 { return true }; return false },
                    "Impossible label layout reports an error instead of cutting text")

        var balanced = project()
        balanced.bands = (0..<5).map { index in
            band(partID: balanced.parts[0].id, page: index % 3, top: 0.2, bottom: 0.3625)
        }
        let balancedPlan = try plan(balanced)
        check(balancedPlan.pages.count == 2 && balancedPlan.pages.allSatisfy { $0.placements.count >= 2 },
              "Balanced pagination avoids a lone final system without adding a page")
        check(balancedPlan.pages.flatMap(\.placements).allSatisfy { abs($0.destinationRect.height - 130) < 0.00001 },
              "Page balancing never shrinks notation")
        balanced.parts[0].layoutSettings.balancePages = false
        let greedyPlan = try plan(balanced)
        check(greedyPlan.pages.map { $0.placements.count } == [4, 1], "Greedy pagination remains available")
        balanced.parts[0].layoutSettings.balancePages = true
        let lastID = balanced.sortedBands(for: balanced.parts[0].id)[3].id
        balanced.bands[balanced.bands.firstIndex { $0.id == lastID }!].pageBreakBefore = true
        let sectionPlan = try plan(balanced)
        check(sectionPlan.pages.map { $0.placements.count } == [3, 2], "Explicit musical section breaks remain hard boundaries")

        var compact = project()
        compact.bands = (0..<6).map { index in
            band(partID: compact.parts[0].id, page: index % 3, top: 0.2, bottom: 0.31875)
        }
        let compactPlan = try plan(compact)
        check(compactPlan.pages.count == 1, "A four-point gap reduction avoids an unnecessary second page")
        check(compactPlan.pages[0].placements.allSatisfy { abs($0.destinationRect.height - 95) < 0.00001 },
              "Compact page packing retains requested notation scale")

        var choir = project()
        choir.projectSettings.showPartNameInHeader = true
        choir.bands = (0..<8).map { index in
            band(partID: choir.parts[0].id, page: index % 3, top: 0.2, bottom: 0.2 + 64.5 / 800)
        }
        let firstChoirBandID = choir.sortedBands(for: choir.parts[0].id)[0].id
        choir.bands[choir.bands.firstIndex { $0.id == firstChoirBandID }!].editorialLabel = "Adagio"
        let choirPlan = try plan(choir)
        check(choirPlan.pages.count == 1, "An eight-system choir part avoids a page turn by using a gap below twelve points")
        let choirPlacements = choirPlan.pages[0].placements
        let choirGap = choirPlacements[0].destinationRect.minY - choirPlacements[1].destinationRect.maxY
        check(choirGap > 11.7 && choirGap < 11.72, "The chosen gap is the largest gap reaching the minimum page count: \(choirGap)")
        check(choirPlacements.allSatisfy { abs($0.destinationRect.height - 64.5) < 0.00001 },
              "Gap optimization never reduces source scale")

        var pianoPacking = project()
        pianoPacking.projectSettings.showPartNameInHeader = true
        pianoPacking.bands = (0..<20).map { index in
            band(partID: pianoPacking.parts[0].id, page: index % 3, top: 0.2, bottom: 0.2 + 118.4 / 800)
        }
        let pianoPlan = try plan(pianoPacking)
        check(pianoPlan.pages.count == 4 && pianoPlan.pages.allSatisfy { $0.placements.count == 5 },
              "Twenty piano systems fit four balanced pages using the full safe gap range")
        check(pianoPlan.pages.flatMap(\.placements).allSatisfy { abs($0.destinationRect.height - 118.4) < 0.00001 },
              "Twenty-system packing preserves notation scale")

        var spacious = project()
        spacious.projectSettings.showTitleBlock = false
        spacious.parts[0].layoutSettings.balancePages = false
        spacious.parts[0].layoutSettings.interSystemGap = 200
        spacious.bands = (0..<5).map { index in
            band(partID: spacious.parts[0].id, page: index % 3, top: 0.2, bottom: 0.4)
        }
        let spaciousPlan = try plan(spacious)
        let spaciousGaps = spaciousPlan.pages.flatMap { page in
            zip(page.placements, page.placements.dropFirst()).map { $0.destinationRect.minY - $1.destinationRect.maxY }
        }
        check(!spaciousGaps.isEmpty && spaciousGaps.allSatisfy { abs($0 - 200) < 0.00001 },
              "With balancing off, 200-point gaps remain 200 points in the rendered layout")
        verifyGeometry(spaciousPlan, project: spacious)
        spacious.parts[0].layoutSettings.balancePages = true
        let balancedSpacious = try plan(spacious)
        check(balancedSpacious.pages.count < spaciousPlan.pages.count,
              "Balancing retains its documented ability to reduce large gaps and avoid extra pages")
        verifyGeometry(balancedSpacious, project: spacious)

        var uniform = project()
        var narrow = uniform.bands[0]
        narrow.id = UUID()
        narrow.pageIndex = 1
        narrow.leftFraction = 0.51
        uniform.bands.append(narrow)
        let uniformPlacements = try plan(uniform).pages.flatMap(\.placements)
        check(abs(uniformPlacements[0].destinationRect.height - uniformPlacements[1].destinationRect.height) < 0.00001,
              "Narrow short systems retain the same source scale as full-width systems")

        var shared = project()
        shared.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.05, bottomFraction: 0.075,
                                                          leftFraction: 0.4, rightFraction: 0.5)]
        let sharedPlan = try plan(shared)
        let sharedBand = sharedPlan.pages[0].placements[0]
        let marking = sharedBand.sourceMarkings[0]
        check(abs(marking.destinationRect.height - 20) < 0.00001 && marking.destinationRect.minY >= sharedBand.destinationRect.maxY + 4,
              "Shared original glyphs reserve a separate row above the target notes")
        check(abs(marking.destinationRect.minX - sharedBand.destinationRect.minX -
                  (marking.sourceRect.minX - sharedBand.sourceRect.minX)) < 0.00001,
              "Shared markings preserve their original horizontal bar position")
        let sharedRoundtrip = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(shared))
        check(sharedRoundtrip == shared,
              "Shared source markings persist with their exact source coordinates")
        var below = shared
        below.bands[0].sourceMarkings[0].isBelow = true
        let belowBand = try plan(below).pages[0].placements[0]
        let belowMark = belowBand.sourceMarkings[0]
        check(belowMark.destinationRect.maxY <= belowBand.destinationRect.minY - 4,
              "End-of-system navigation stays below the target music")
        check(belowMark.sourceRect == marking.sourceRect && belowMark.destinationRect.size == marking.destinationRect.size,
              "Changing direction placement preserves complete source glyphs and scale")
        check(abs(belowMark.destinationRect.minX - belowBand.destinationRect.minX -
                  (belowMark.sourceRect.minX - belowBand.sourceRect.minX)) < 0.00001,
              "Below-system directions retain their horizontal bar position")
        let belowRoundtrip = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(below))
        check(belowRoundtrip == below,
              "Below-system placement survives project persistence")
        let oldMarking = Data(#"{"topFraction":0.05,"bottomFraction":0.075,"leftFraction":0.4,"rightFraction":0.5}"#.utf8)
        let legacyMarking = try JSONDecoder().decode(BandSourceMarking.self, from: oldMarking)
        check(legacyMarking.isBelow == nil,
              "Existing projects retain above-system placement without migration")
        var bothSides = shared
        bothSides.bands[0].sourceMarkings.append(below.bands[0].sourceMarkings[0])
        let bothPlacement = try plan(bothSides).pages[0].placements[0]
        check(bothPlacement.sourceMarkings[0].destinationRect.minY >= bothPlacement.destinationRect.maxY + 4
              && bothPlacement.sourceMarkings[1].destinationRect.maxY <= bothPlacement.destinationRect.minY - 4,
              "Directions can share a bar position on opposite sides without overlap")
        var crowdedDirections = bothSides
        for i in 1..<18 {
            var next = bothSides.bands[0]; next.id = UUID(); next.pageIndex = i % 3
            crowdedDirections.bands.append(next)
        }
        let crowdedPlan = try plan(crowdedDirections)
        check(crowdedPlan.pages.flatMap(\.placements).count == 18, "Pagination retains every annotated system")
        for page in crowdedPlan.pages {
            var previousBottom = crowdedPlan.pageSize.height
            for placement in page.placements {
                let boxes = [placement.destinationRect] + placement.sourceMarkings.map(\.destinationRect)
                let top = boxes.map(\.maxY).max()!, bottom = boxes.map(\.minY).min()!
                check(top <= previousBottom + 0.00001 && bottom >= crowdedDirections.projectSettings.margins.bottom - 0.00001,
                      "Pagination reserves both annotation rows inside the page and before the next system")
                previousBottom = bottom
            }
        }
        var overlappingMarkings = shared
        overlappingMarkings.bands[0].sourceMarkings.append(BandSourceMarking(
            topFraction: 0.1, bottomFraction: 0.125, leftFraction: 0.45, rightFraction: 0.45))
        expectError(overlappingMarkings, matches: { if case .overlappingSourceMarkings = $0 { return true }; return false },
                    "Separate source rows cannot silently overpaint shared directions in the output row")
        overlappingMarkings.bands[0].sourceMarkings[1] = overlappingMarkings.bands[0].sourceMarkings[0]
        expectError(overlappingMarkings, matches: { if case .overlappingSourceMarkings = $0 { return true }; return false },
                    "Duplicate source fragments require explicit resolution before export")
        var adjacentMarkings = shared
        adjacentMarkings.bands[0].sourceMarkings.append(BandSourceMarking(
            topFraction: 0.1, bottomFraction: 0.125, leftFraction: 0.5, rightFraction: 0.4))
        let adjacentPlacement = try plan(adjacentMarkings).pages[0].placements[0]
        check(adjacentPlacement.sourceMarkings[1].destinationRect.minX >= adjacentPlacement.sourceMarkings[0].destinationRect.maxX,
              "Touching source spans remain valid and render without overlapping")
        check(adjacentPlacement.destinationRect == sharedBand.destinationRect && adjacentPlacement.sourceMarkings[0].destinationRect == marking.destinationRect,
              "Valid nonoverlapping fragments keep the existing staff and marking geometry")
        shared.bands[0].sourceMarkings[0].leftFraction = 0.01
        expectError(shared, matches: { if case .invalidSourceMarking = $0 { return true }; return false },
                    "A shared marking outside the horizontal crop fails instead of being clipped")

        let insetInk: (BandModel, CGRect) -> CGRect? = { _, rect in rect.insetBy(dx: 80, dy: 0) }
        var enlarged = project()
        var providerCalls = 0
        let unchanged = try plan(enlarged, horizontalBounds: { _, rect in
            providerCalls += 1; return rect.insetBy(dx: 80, dy: 0)
        })
        check(providerCalls == 0, "Scale one avoids analysis and preserves historical source crops")
        let originalPlacement = unchanged.pages[0].placements[0]
        for multiplier in [0.6, 0.85, 1.0] {
            enlarged.parts[0].layoutSettings.scale = multiplier
            let legacy = try plan(enlarged)
            let withProvider = try plan(enlarged, horizontalBounds: insetInk)
            check(legacy.pages.map { $0.placements.map(\.sourceRect) } == withProvider.pages.map { $0.placements.map(\.sourceRect) }
                  && legacy.pages.map { $0.placements.map(\.destinationRect) } == withProvider.pages.map { $0.placements.map(\.destinationRect) },
                  "Scale <= one preserves exact historical source and destination geometry")
        }
        for multiplier in [1.05, 1.25, 1.4] {
            enlarged.parts[0].layoutSettings.scale = multiplier
            let result = try plan(enlarged, horizontalBounds: insetInk)
            let placement = result.pages[0].placements[0]
            check(abs(placement.destinationRect.height / originalPlacement.destinationRect.height - multiplier) < 0.00001,
                  "Requested scale \(multiplier) enlarges the notation when blank edges provide room")
            check(placement.sourceRect.minY == originalPlacement.sourceRect.minY && placement.sourceRect.height == originalPlacement.sourceRect.height,
                  "Horizontal enlargement never changes top or bottom crop edges")
            check(abs(result.scaleInfo.appliedScale - multiplier) < 0.00001 && !result.scaleInfo.isWidthLimited,
                  "Scale metadata reports the visible enlargement")
            verifyGeometry(result, project: enlarged)
        }
        let limited = try plan(enlarged, horizontalBounds: { _, rect in rect.insetBy(dx: 30, dy: 0) })
        check(limited.scaleInfo.isWidthLimited && abs(limited.scaleInfo.appliedScale - 516.0 / 456) < 0.00001,
              "A crop with little blank space stops at its actual safe width and reports the limit")
        var limitedAt130 = enlarged
        limitedAt130.parts[0].layoutSettings.scale = 1.3
        let plateau = try plan(limitedAt130, horizontalBounds: { _, rect in rect.insetBy(dx: 30, dy: 0) })
        check(plateau.pages[0].placements[0].destinationRect == limited.pages[0].placements[0].destinationRect &&
              plateau.scaleInfo.appliedScale == limited.scaleInfo.appliedScale,
              "Requests of 1.30 and 1.40 share the same real size after reaching the ink-preserving width limit")
        limitedAt130.parts[0].layoutSettings.sideMarginPoints = 18
        let widerAt18 = try plan(limitedAt130, horizontalBounds: { _, rect in rect.insetBy(dx: 30, dy: 0) })
        check(abs(widerAt18.pages[0].placements[0].destinationRect.width - 576) < 0.00001 &&
              widerAt18.scaleInfo.maximumSafeScale == plateau.scaleInfo.maximumSafeScale &&
              widerAt18.pages[0].placements[0].sourceRect == plateau.pages[0].placements[0].sourceRect,
              "18-point margins enlarge physical notation at the plateau without changing crops or the relative scale limit")
        let noBounds = try plan(enlarged)
        check(noBounds.scaleInfo.isWidthLimited && noBounds.pages[0].placements[0].destinationRect == originalPlacement.destinationRect,
              "Unavailable content bounds safely preserve the original crop")
        for bad in [CGRect(x: -.infinity, y: 0, width: 10, height: 10), CGRect.zero,
                    originalPlacement.sourceRect.insetBy(dx: -2, dy: 0)] {
            let rejected = try plan(enlarged, horizontalBounds: { _, _ in bad })
            check(rejected.pages[0].placements[0].sourceRect == originalPlacement.sourceRect,
                  "Invalid, empty, and outward content bounds never change a source crop")
        }
        var withMarks = enlarged
        withMarks.bands[0].sourceMarkings = [BandSourceMarking(topFraction: 0.05, bottomFraction: 0.075,
                                                            leftFraction: 0.09, rightFraction: 0.85)]
        let markedPlan = try plan(withMarks, horizontalBounds: insetInk)
        let markedPlacement = markedPlan.pages[0].placements[0]
        let retainedMark = markedPlacement.sourceMarkings[0]
        check(markedPlacement.sourceRect.minX <= retainedMark.sourceRect.minX
              && retainedMark.destinationRect.minX >= 48 && retainedMark.destinationRect.maxX <= 564,
              "Copied directions outside the staff's ink envelope remain fully preserved")
        check(markedPlan.scaleInfo.isWidthLimited, "An edge direction contributes to the actual width limit")
        var mixedWidths = enlarged
        var short = mixedWidths.bands[0]; short.id = UUID(); short.pageIndex = 1; short.leftFraction = 0.40
        mixedWidths.bands.append(short)
        let uniformEnlargement = try plan(mixedWidths, horizontalBounds: insetInk).pages.flatMap(\.placements)
        check(abs(uniformEnlargement[0].destinationRect.height - uniformEnlargement[1].destinationRect.height) < 0.00001,
              "Safe enlargement preserves consistent notation sizes across different crop widths")
        mixedWidths.parts[0].layoutSettings.useConsistentScale = false
        let independentEnlargement = try plan(mixedWidths, horizontalBounds: insetInk).pages.flatMap(\.placements)
        check(independentEnlargement[1].destinationRect.height > independentEnlargement[0].destinationRect.height,
              "Independent system scaling still uses each original crop's own fit-to-width baseline")
        var restAndMusic = enlarged
        var rest = restAndMusic.bands[0]; rest.id = UUID(); rest.pageIndex = 1
        rest.restReplacement = BandRestReplacement(barCount: 12)
        restAndMusic.bands.append(rest)
        let restPlan = try plan(restAndMusic, horizontalBounds: insetInk)
        check(abs(restPlan.scaleInfo.appliedScale - 1.4) < 0.00001,
              "Full-width synthetic rest lines do not prevent music enlargement")
        let restPlacement = restPlan.pages.flatMap(\.placements).first { $0.restBarCount != nil }!
        check(restPlacement.destinationRect.width <= 516.00001 && abs(restPlacement.destinationRect.height - 48 * 1.4) < 0.00001,
              "Synthetic rest notation grows while its drawn staff remains within page margins")
        restAndMusic.bands[1].restReplacement = nil
        restAndMusic.bands[1].generatedRest = BandGeneratedRest(barCount: 3, startBarNumber: 20, sourceSystemIndex: 1)
        let generatedRestPlan = try plan(restAndMusic, horizontalBounds: insetInk)
        check(abs(generatedRestPlan.scaleInfo.appliedScale - 1.4) < 0.00001,
              "Generated silent-system rests also preserve the requested music enlargement")
        var contextRest = enlarged
        contextRest.bands[0].restReplacement = BandRestReplacement(barCount: 12,
            sourceContext: BandRestSourceContext(
                prefix: BandSourceMarking(topFraction: 0.2, bottomFraction: 0.4, leftFraction: 0.08, rightFraction: 0.75),
                suffix: BandSourceMarking(topFraction: 0.2, bottomFraction: 0.4, leftFraction: 0.90, rightFraction: 0.06),
                staffLineFractions: [0.27, 0.28, 0.29, 0.30, 0.31], skewDegrees: 0,
                staffLeftFraction: 0.15, staffRightFraction: 0.93))
        let contextPlan = try plan(contextRest, horizontalBounds: insetInk)
        let contextPlacement = contextPlan.pages[0].placements[0]
        check(abs(contextPlacement.sourceRect.minX - originalPlacement.sourceRect.minX) < 0.00001
              && abs(contextPlacement.sourceRect.maxX - originalPlacement.sourceRect.maxX) < 0.00001
              && contextPlan.scaleInfo.isWidthLimited,
              "An automatic rest keeps its entire source clef, signature and final barline context")
        check(contextPlacement.restSourcePlacement!.fragments.allSatisfy {
            $0.destinationRect.minX >= 48 && $0.destinationRect.maxX <= 564
        }, "Preserved automatic-rest fragments remain on the output page")
        var closerMargins = project()
        closerMargins.parts[0].layoutSettings.sideMarginPoints = 12
        let closerPlan = try plan(closerMargins)
        check(closerPlan.pages[0].placements[0].destinationRect.width == 588,
              "Per-part side margins make the notation wider without changing stored source crops")
        verifyGeometry(closerPlan, project: closerMargins)
        closerMargins.parts[0].layoutSettings.sideMarginPoints = .nan
        expectError(closerMargins, matches: { if case .invalidLayoutSettings = $0 { return true }; return false },
                    "Invalid part side margins fail before layout")

        // Exercise page breaks, sparse pages, exclusions, narrow/tall crops, high zoom, and asymmetric margins together.
        for index in 0..<80 {
            var generated = project()
            generated.projectSettings.outputPageSize = index.isMultiple(of: 2) ? .letter : .a4
            generated.projectSettings.margins = PageMargins(top: Double(index % 55), leading: Double(index % 73),
                                                           bottom: Double(index % 61), trailing: Double(index % 29))
            generated.projectSettings.showTitleBlock = !index.isMultiple(of: 3)
            generated.projectSettings.showPartNameInHeader = index.isMultiple(of: 2)
            generated.parts[0].layoutSettings.scale = 0.6 + Double(index % 9) / 10
            generated.bands = (0..<19).reversed().map { bandIndex in
                let top = Double(bandIndex % 6) / 7
                var band = band(partID: generated.parts[0].id, page: bandIndex % 3, top: top,
                                bottom: top + Double((index + bandIndex) % 4 + 1) / 30)
                band.leftFraction = Double(index % 40) / 100
                band.rightFraction = Double(bandIndex % 30) / 100
                band.excluded = bandIndex.isMultiple(of: 7)
                return band
            }
            verifyGeometry(try plan(generated), project: generated)
        }

        struct Envelope: Decodable { var project: ProjectData }
        let fixtureURL = URL(fileURLWithPath: "Partsmith/Resources/Fixtures/SampleProject.partsmithproject")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(Envelope.self, from: Data(contentsOf: fixtureURL.appendingPathComponent("project.json"))).project
        check(fixture.bands.allSatisfy { $0.editorialLabel.isEmpty && !$0.pageBreakBefore },
              "Historical project files open with empty labels and automatic pagination")
        guard let pdf = PDFDocument(url: fixtureURL.appendingPathComponent("source.pdf")) else { fatalError("Fixture PDF missing") }
        for part in fixture.parts {
            let fixturePlan = try PartLayoutEngine.makePlan(project: fixture,
                                                           pageBoundsProvider: { pdf.page(at: $0)?.bounds(for: .mediaBox) },
                                                           partID: part.id)
            verifyGeometry(fixturePlan, project: fixture)
        }
        print("PASS: \(checks) layout assertions, including the saved project fixture and 80 varied layouts")
    }
}
