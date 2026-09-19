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
