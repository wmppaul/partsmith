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

    static func plan(_ project: ProjectData) throws -> PartRenderPlan {
        try PartLayoutEngine.makePlan(project: project,
                                      pageBoundsProvider: { (0..<3).contains($0) ? sourceBounds : nil },
                                      partID: project.parts[0].id)
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
        let margins = project.projectSettings.margins
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
