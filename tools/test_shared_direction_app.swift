import AppKit
import Foundation
import PDFKit

/// Independent user-behavior tests. OCR is injected only for deterministic
/// timing/failure; real source rendering and staff-analysis workers still run.
@main enum SharedDirectionAppTests {
    static var checks = 0
    static let checkLock = NSLock()
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        checkLock.lock(); checks += 1; checkLock.unlock()
        guard condition() else {
            FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
        }
    }
    static func wait(_ done: () -> Bool) {
        let deadline = Date().addingTimeInterval(30)
        while !done(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        check(done(), "Deterministic worker reaches its expected event before timeout")
    }
    static var profile: ScoreExtractionProfile {
        .init(parts: [.init(id: "violin", name: "Violin", staffCount: 1),
                      .init(id: "cello", name: "Cello", staffCount: 1)], cropMode: "compact")
    }
    static func sourcePDF() -> Data {
        let data = NSMutableData(); var media = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        for page in 0..<5 {
            context.beginPDFPage(nil); context.setFillColor(gray: 1, alpha: 1); context.fill(media)
            context.setStrokeColor(gray: 0, alpha: 1); context.setFillColor(gray: 0, alpha: 1)
            context.setLineWidth(0.7)
            for top in [100.0, 180, 430, 510] {
                for line in 0..<5 {
                    let y = 800 - top - Double(line) * 6
                    context.move(to: CGPoint(x: 55, y: y)); context.addLine(to: CGPoint(x: 555, y: y))
                }
                context.strokePath()
                context.fillEllipse(in: CGRect(x: 100 + Double(page), y: 800 - top - 14, width: 8, height: 5))
            }
            context.endPDFPage()
        }
        context.closePDF(); return data as Data
    }
    static func document(_ source: Data) -> PartsmithDocument {
        var project = ProjectData.empty; project.pageCount = 5; project.sourceFilename = "direction-worker-fixture.pdf"
        return PartsmithDocument(project: project, sourcePDFData: source)
    }
    static func manualPage(_ index: Int) -> ScorePageAnalysis {
        let tops = [0.20, 0.32, 0.60, 0.72]
        return .init(pageIndex: index, pageWidth: 600, pageHeight: 800, imageWidth: 1800, imageHeight: 2400,
            staves: tops.enumerated().map { item in
                ScoreObservedStaff(StaffBandCandidate(id: item.offset,
                    staffLineFractions: (0..<5).map { item.element + Double($0) * 0.006 },
                    topFraction: item.element - 0.02, bottomFraction: item.element + 0.05,
                    confidence: 1, warnings: []))
            }, warnings: [], sharedHeadings: [.init(anchorStaffID: 0, bounds: [0.2, 0.13, 0.4, 0.17], recognizedText: "Andante")],
            sharedNavigation: [.init(anchorStaffID: 1, bounds: [0.45, 0.355, 0.8, 0.39], recognizedText: "Da Capo", isBelow: true)])
    }
    static func review(_ source: Data) -> ScoreDetectionReview {
        .initial(profile: profile, analyses: [manualPage(0), manualPage(2)], selectedPageIndices: [0,2],
                 sourcePDFData: source, rectifications: [])
    }
    static func edges(_ band: ScorePlannedBand) -> [Double] {
        [band.leftFraction, band.topFraction, 1 - band.rightFraction, band.bottomFraction]
    }
    final class Gate {
        private let lock = NSLock()
        private var didEnter = false
        private var cancelled = false
        let release = DispatchSemaphore(value: 0)
        func enter() { lock.lock(); didEnter = true; lock.unlock() }
        var entered: Bool { lock.lock(); defer { lock.unlock() }; return didEnter }
        func sawCancellation(_ value: Bool) { lock.lock(); cancelled = value; lock.unlock() }
        var cancellationObserved: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    static func reviewEdits(_ source: Data) throws {
        var value = review(source)
        check(value.plan.canApply && value.plan.bands.count == 8, "Review fixture has complete fixed-layout assignments")
        let target = value.plan.bands.first { $0.pageIndex == 0 && $0.systemIndex == 0 && $0.partID == "violin" }!
        let recipientIndex = target.sourceMarkings.firstIndex { $0.isBelow == true }!
        let otherPage = value.plan.bands.filter { $0.pageIndex == 2 }
        let originalSource = value.sourcePDFData
        try value.removeSourceMarking(from: target.id, at: recipientIndex)
        let afterRemove = value.plan.bands.first { $0.id == target.id }!
        check(afterRemove.sourceMarkings.count == target.sourceMarkings.count - 1
              && !afterRemove.sourceMarkings.contains { $0.isBelow == true }, "Remove affects exactly the selected recipient copy")
        check(edges(afterRemove) == edges(target), "Removing an optional copy does not change music crop edges")
        check(value.plan.bands.filter { $0.pageIndex == 2 } == otherPage, "Removal leaves another source page exact")
        check(value.sourcePDFData == originalSource && value.plan.canApply, "Removing a direction leaves acceptance available and source immutable")
        let unrelated = value.plan.bands.first { $0.pageIndex == 0 && $0.systemIndex == 1 }!
        try value.setCropEdges(for: unrelated.id, top: unrelated.topFraction * 800, bottom: unrelated.bottomFraction * 800)
        try value.resetCropEdges(for: target.id)
        value.replan()
        check(value.plan.bands.first { $0.id == target.id }?.sourceMarkings == afterRemove.sourceMarkings,
              "Removed copy stays removed through unrelated editing, crop reset and replanning")
        let restoredOverrides = try JSONDecoder().decode([ScorePageOverride].self, from: JSONEncoder().encode(value.overrides))
        var restored = ScoreDetectionReview.initial(profile: profile, analyses: value.analyses, overrides: restoredOverrides,
            selectedPageIndices: [0,2], sourcePDFData: source, rectifications: [])
        check(restored.plan.bands.first { $0.id == target.id }?.sourceMarkings == afterRemove.sourceMarkings,
              "Reviewed removal survives override serialization")
        let beforeInvalidRemove = restored.plan
        for index in [-1, 999] {
            do { try restored.removeSourceMarking(from: target.id, at: index); check(false, "Invalid removal index must be rejected") }
            catch { check(restored.plan == beforeInvalidRemove, "Invalid removal leaves review unchanged") }
        }
        let doc = document(source); let undo = UndoManager(); undo.groupsByEvent = false; doc.undoManager = undo
        let beforeApply = doc.project
        undo.beginUndoGrouping(); let added = doc.addScoreParts(from: value); undo.endUndoGrouping()
        check(added == 8, "An optional direction removal does not prevent applying all parts")
        let saved = try JSONDecoder().decode(ProjectData.self, from: JSONEncoder().encode(doc.project))
        check(saved.bands.map(\.sourceMarkings) == doc.project.bands.map(\.sourceMarkings), "Copy geometry and placement persist in the project")
        undo.undo(); check(doc.project == beforeApply, "Apply including copy removals is one undoable change")
        undo.redo(); check(doc.project.bands.map(\.sourceMarkings) == saved.bands.map(\.sourceMarkings), "Redo restores reviewed copy choices")

        var invalidated = review(source)
        let before = invalidated.plan
        invalidated.invalidateAutomaticDirections(on: 0)
        let page = invalidated.analyses.first { $0.pageIndex == 0 }!
        check((page.sharedHeadings ?? []).isEmpty && (page.sharedNavigation ?? []).isEmpty,
              "Assignment invalidation clears raw automatic heading and navigation ownership")
        check(invalidated.plan.bands.filter { $0.pageIndex == 0 }.allSatisfy { $0.sourceMarkings.isEmpty },
              "Invalidated page cannot retain derived copies under a new staff mapping")
        check(invalidated.plan.bands.filter { $0.pageIndex == 2 } == before.bands.filter { $0.pageIndex == 2 },
              "Direction invalidation is local to its edited source page")
        check(invalidated.plan.canApply, "Needing a new direction scan does not create an acceptance barrier")
        check(invalidated.directionIssues.contains { $0.pageIndex == 0 }, "Invalidation is visible as an optional review issue")

        var edited = review(source)
        let originalPlan = edited.plan
        edited.replan()
        check(edited.plan == originalPlan, "An unchanged replan does not invalidate recognized directions")
        let cropTarget = edited.plan.bands.first!
        try edited.setCropEdges(for: cropTarget.id, top: max(0, cropTarget.topFraction * 800 - 1),
                               bottom: cropTarget.bottomFraction * 800)
        check(edited.analyses.first!.sharedHeadings?.isEmpty == false
              && edited.analyses.first!.sharedNavigation?.isEmpty == false,
              "A crop edge edit alone retains staff-to-direction identity")
        let keepOtherPage = edited.plan.bands.filter { $0.pageIndex == 2 }
        var mapping = ScoreSystemAssignment.pageOverride(page: edited.analyses[0], pagePlan: edited.plan.pages[0],
            existingOverride: edited.overrides.first { $0.pageIndex == 0 })
        let manualRect = [30.0, 12, 70, 22]
        var markings = mapping.systems[0].bands[0].sourceMarkings ?? []
        var sides = mapping.systems[0].bands[0].sourceMarkingsBelow ?? Array(repeating: false, count: markings.count)
        markings.append(manualRect); sides.append(false)
        mapping.systems[0].bands[0].sourceMarkings = markings
        mapping.systems[0].bands[0].sourceMarkingsBelow = sides
        mapping.systems[0].bands[0].partID = "cello"
        mapping.systems[0].bands[1].partID = "violin"
        edited.overrides.removeAll { $0.pageIndex == 0 }; edited.overrides.append(mapping)
        edited.replan()
        check(edited.plan.canApply, "A complete reassignment remains acceptable without mandatory direction review")
        check((edited.analyses[0].sharedHeadings ?? []).isEmpty && (edited.analyses[0].sharedNavigation ?? []).isEmpty,
              "Replan itself detects changed staff ownership and clears stale raw anchors")
        let remaining = edited.plan.bands.filter { $0.pageIndex == 0 }.flatMap(\.sourceMarkings)
        check(remaining.count == 1 && remaining[0].leftFraction * 600 == manualRect[0]
              && remaining[0].topFraction * 800 == manualRect[1],
              "Reassignment removes derived automatic copies but preserves a distinct custom source rectangle")
        check(edited.plan.bands.filter { $0.pageIndex == 2 } == keepOtherPage,
              "A mapping change leaves other pages and their recognized directions intact")
        for band in edited.plan.bands where band.pageIndex == 0 {
            let frozen = mapping.systems[band.systemIndex].bands.first { $0.partID == band.partID }!.rect!
            let actual = [band.leftFraction * 600, band.topFraction * 800,
                          (1 - band.rightFraction) * 600, band.bottomFraction * 800]
            check(zip(actual, frozen).allSatisfy { abs($0 - $1) < 1e-9 },
                  "Clearing stale direction metadata does not shrink reviewed music crops")
        }
        var changedProfile = review(source)
        changedProfile.profile.parts.reverse()
        changedProfile.replan()
        check(changedProfile.analyses.allSatisfy { ($0.sharedHeadings ?? []).isEmpty && ($0.sharedNavigation ?? []).isEmpty },
              "A changed profile order invalidates old direction ownership on every page")
        check(changedProfile.plan.canApply, "Changing a complete fixed profile adds no direction acceptance gate")
        var movedSystem = review(source)
        var movedMapping = ScoreSystemAssignment.pageOverride(page: movedSystem.analyses[0], pagePlan: movedSystem.plan.pages[0], existingOverride: nil)
        movedMapping.systems.swapAt(0, 1)
        movedMapping.systems[0].systemIndex = 0; movedMapping.systems[1].systemIndex = 1
        movedSystem.overrides = [movedMapping]; movedSystem.replan()
        check((movedSystem.analyses[0].sharedHeadings ?? []).isEmpty && (movedSystem.analyses[0].sharedNavigation ?? []).isEmpty,
              "Reordering complete systems invalidates old source direction anchors")
        check(movedSystem.plan.bands.filter { $0.pageIndex == 0 }.allSatisfy { $0.sourceMarkings.isEmpty },
              "Automatic source copies cannot move silently into a different system index")

        // A saved/manual override can be present before review initialization;
        // it must not be mislabeled as an automatic detection merely because
        // it was included in the first displayed plan.
        var sourceReview = review(source)
        var existing = ScoreSystemAssignment.pageOverride(page: sourceReview.analyses[0],
            pagePlan: sourceReview.plan.pages[0], existingOverride: nil)
        existing.systems[0].bands[0].sourceMarkings!.append(manualRect)
        var existingSides = existing.systems[0].bands[0].sourceMarkingsBelow
            ?? Array(repeating: false, count: existing.systems[0].bands[0].sourceMarkings!.count - 1)
        existingSides.append(false); existing.systems[0].bands[0].sourceMarkingsBelow = existingSides
        sourceReview = .initial(profile: profile, analyses: sourceReview.analyses, overrides: [existing],
            selectedPageIndices: [0,2], sourcePDFData: source, rectifications: [])
        let suppliedMarkings = sourceReview.plan.bands.filter { $0.pageIndex == 0 }.map(\.sourceMarkings)
        sourceReview.invalidateAutomaticDirections(on: 0)
        let savedManual = sourceReview.plan.bands.filter { $0.pageIndex == 0 }.flatMap(\.sourceMarkings)
        check(savedManual.contains { $0.leftFraction * 600 == manualRect[0] && $0.topFraction * 800 == manualRect[1] },
              "Invalidation preserves pre-existing manual markings supplied during review initialization")
        check(sourceReview.plan.bands.filter { $0.pageIndex == 0 }.map(\.sourceMarkings) == suppliedMarkings,
              "Every pre-existing authoritative override list remains a manual reviewed choice")

        var trioPage = manualPage(0); trioPage.staves = Array(trioPage.staves.prefix(3))
        trioPage.sharedNavigation = [.init(anchorStaffID: 2, bounds: [0.45,0.635,0.8,0.69], recognizedText: "Da Capo", isBelow: true)]
        var trioProfile = profile; trioProfile.parts.insert(.init(id: "violin2", name: "Violin II", staffCount: 1), at: 1)
        let trioPlan = ScoreExtractionPlanner.plan(pages: [trioPage], profile: trioProfile)
        var mixed = ScoreSystemAssignment.pageOverride(page: trioPage, pagePlan: trioPlan.pages[0], existingOverride: nil)
        let firstIndex = mixed.systems[0].bands.firstIndex { $0.partID == "violin" }!
        let secondIndex = mixed.systems[0].bands.firstIndex { $0.partID == "violin2" }!
        let nav = trioPlan.bands.first { $0.partID == "violin" }!.sourceMarkings.first { $0.isBelow == true }!
        let sameRect = [nav.leftFraction * 600, nav.topFraction * 800, (1 - nav.rightFraction) * 600, nav.bottomFraction * 800]
        mixed.systems[0].bands[firstIndex].sourceMarkings = [sameRect]
        mixed.systems[0].bands[firstIndex].sourceMarkingsBelow = [true]
        mixed.systems[0].bands[secondIndex].sourceMarkings = nil
        mixed.systems[0].bands[secondIndex].sourceMarkingsBelow = nil
        var perRecipient = ScoreDetectionReview.initial(profile: trioProfile, analyses: [trioPage], overrides: [mixed],
            selectedPageIndices: [0], sourcePDFData: source, rectifications: [])
        check(perRecipient.plan.bands.filter { ["violin","violin2"].contains($0.partID) }
            .allSatisfy { $0.sourceMarkings.contains(nav) }, "Same source rectangle can be manual for one recipient and automatic for another")
        var swappedRecipients = perRecipient
        swappedRecipients.overrides[0].systems[0].bands[firstIndex].partID = "violin2"
        swappedRecipients.overrides[0].systems[0].bands[secondIndex].partID = "violin"
        swappedRecipients.replan()
        check(swappedRecipients.plan.bands.first { $0.partID == "violin2" }!.sourceMarkings == [nav],
              "An authoritative manual copy follows its original staff when recipient names swap")
        check(swappedRecipients.plan.bands.first { $0.partID == "violin" }!.sourceMarkings.isEmpty,
              "An automatic copy clears even when it inherits the manual recipient's old part ID")
        perRecipient.invalidateAutomaticDirections(on: 0)
        check(perRecipient.plan.bands.first { $0.partID == "violin" }!.sourceMarkings == [nav],
              "An identical automatic copy on another part cannot erase a manual reviewed copy")
        check(perRecipient.plan.bands.first { $0.partID == "violin2" }!.sourceMarkings.isEmpty,
              "The automatic recipient still clears its stale copy independently")
    }

    static func workerLifecycle(_ source: Data) {
        let baseline = document(source); var baselineDone = false; var baseReview: ScoreDetectionReview?
        var disabledCalls = 0
        let trap: ScoreSharedDirectionRunner = { _, pages, _, _, _, _ in
            disabledCalls += 1; return .init(analyses: pages, issues: [])
        }
        baseline.detectScore(profile: profile, pageIndices: [1,3], copySharedDirections: false, directionRunner: trap) {
            baseReview = $0; baselineDone = true
        }
        wait { baselineDone }
        check(disabledCalls == 0 && baseReview?.plan.canApply == true, "Opt-out makes no direction calls and preserves valid staff extraction")
        check(baseReview?.analyses.map(\.pageIndex) == [1,3], "Sparse input selection retains absolute source page indices")

        let selected = document(source); let original = selected.project
        var selectedDone = false; var selectedReview: ScoreDetectionReview?; var workerWasBackground = false
        let injected: ScoreSharedDirectionRunner = { pdf, pages, supplied, corrections, progress, isCancelled in
            workerWasBackground = !Thread.isMainThread
            check(pdf.pageCount == 5 && pages.map(\.pageIndex) == [1,3], "Runner receives a worker-owned source and only selected analyses")
            check(supplied == profile && corrections.isEmpty && !isCancelled(), "Runner captures the selected fixed profile and correction snapshot")
            progress(.init(phase: .headings, completedPages: 1, totalPages: 2))
            return .init(analyses: pages, issues: [.init(pageIndex: 3, message: "Injected optional OCR failure")])
        }
        selected.detectScore(profile: profile, pageIndices: [1,3], copySharedDirections: true, directionRunner: injected) {
            check(Thread.isMainThread, "Review completion publishes on the main thread")
            selectedReview = $0; selectedDone = true
        }
        wait { selectedDone }
        check(workerWasBackground, "Direction recognition executes off the main thread")
        check(selectedReview?.plan == baseReview?.plan, "Optional recognition failure retains the exact base staff/crop plan")
        check(selectedReview?.directionIssues.contains { $0.pageIndex == 3 && $0.message.contains("optional OCR failure") } == true,
              "Runtime failure is visible and distinct from a successful zero-match scan")
        check(selectedReview?.plan.canApply == true && selected.project == original && selected.scoreDetectionProgress == nil,
              "Failure adds no acceptance barrier, implicit document mutation or stuck progress")

        for phase: ScoreDirectionPhase in [.headings, .navigation, .references, .destinations] {
            let doc = document(source), gate = Gate()
            var oldCompletions = 0; var newDone = false; var newReview: ScoreDetectionReview?
            let blocked: ScoreSharedDirectionRunner = { _, pages, _, _, progress, cancelled in
                progress(.init(phase: phase, completedPages: 0, totalPages: pages.count)); gate.enter()
                _ = gate.release.wait(timeout: .now() + 20)
                gate.sawCancellation(cancelled())
                progress(.init(phase: .destinations, completedPages: 999, totalPages: 999))
                return .init(analyses: pages, issues: [.init(pageIndex: -1, message: "STALE-RUN")])
            }
            doc.detectScore(profile: profile, pageIndices: [1], copySharedDirections: true, directionRunner: blocked) { _ in oldCompletions += 1 }
            wait { gate.entered }
            wait { doc.scoreDetectionProgress?.directionPhase == phase }
            doc.cancelScoreDetection()
            check(doc.scoreDetectionProgress == nil, "Cancellation immediately clears direction-phase progress")
            doc.detectScore(profile: profile, pageIndices: [3], copySharedDirections: false, directionRunner: trap) {
                newReview = $0; newDone = true
            }
            gate.release.signal(); wait { newDone }
            check(gate.cancellationObserved, "Every worker phase receives cooperative cancellation")
            check(oldCompletions == 0 && newReview?.analyses.map(\.pageIndex) == [3], "Canceled results cannot replace a subsequent run")
            check(newReview?.directionIssues.isEmpty == true && doc.scoreDetectionProgress == nil,
                  "Late canceled progress and warnings cannot leak into the replacement review")
            check(doc.project.parts.isEmpty && doc.project.bands.isEmpty, "Canceled preview recognition never applies partial output")
        }
        for changeGeometry in [false, true] {
            let doc = document(source), gate = Gate(); var done = false; var result: ScoreDetectionReview?
            let blocked: ScoreSharedDirectionRunner = { _, pages, _, _, _, _ in
                gate.enter(); _ = gate.release.wait(timeout: .now() + 20)
                return .init(analyses: pages, issues: [])
            }
            doc.detectScore(profile: profile, pageIndices: [1], copySharedDirections: true, directionRunner: blocked) { result = $0; done = true }
            wait { gate.entered }
            if changeGeometry { doc.updatePageRectification(.default(pageIndex: 1)) }
            else { doc.sourcePDFData = source + Data([0x20]) }
            gate.release.signal(); wait { done }
            check(result == nil && doc.scoreDetectionProgress == nil, "Source or correction changes reject stale direction review")
            check(doc.project.bands.isEmpty, "Stale direction results never mutate parts")
        }
    }
    static func coordinator() {
        let input = [manualPage(0), manualPage(2)]
        let ctx = CGContext(data: nil, width: 12, height: 18, bitsPerComponent: 8, bytesPerRow: 12,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 18))
        let image = ctx.makeImage()!
        let heading = ScoreSharedHeading(anchorStaffID: 0, bounds: [0.20,0.13,0.4,0.17], recognizedText: "New heading")
        let instruction = ScoreSharedNavigation(anchorStaffID: 1, bounds: [0.45,0.355,0.8,0.39], recognizedText: "Da Capo", isBelow: true)
        let glyph = ScoreSharedNavigation(anchorStaffID: 0, bounds: [0.12,0.14,0.17,0.18], recognizedText: "", isBelow: false)
        let reference = ScoreSharedDestinationDetector.Template(sourcePageIndex: 2, sourceBounds: instruction.bounds, pixels: [0,1])
        var events: [String] = []
        var renders: [String] = []
        var progress: [ScoreDirectionProgress] = []
        let services = ScoreSharedDirectionServices(headings: { _, page, _, _ in
            events.append("heading:\(page.pageIndex)"); return [heading]
        }, navigation: { _, page, _, _ in
            events.append("navigation:\(page.pageIndex)"); return page.pageIndex == 2 ? [instruction] : []
        }, references: { _, page, _, _ in
            events.append("reference:\(page.pageIndex)"); return [reference]
        }, destinations: { _, page, _, templates, _ in
            events.append("destination:\(page.pageIndex)")
            check(templates.count == 1 && templates[0].sourcePageIndex == 2,
                  "Earlier pages receive references collected from later selected pages")
            return page.pageIndex == 0 ? ([glyph], [.init(anchorStaffID: 0, bounds: glyph.bounds,
                correlation: 1, templatePageIndex: 2, templateBounds: reference.sourceBounds)]) : ([], [])
        })
        let result = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: profile, render: { page, phase in
            renders.append("\(phase.rawValue):\(page.pageIndex)"); return image
        }, services: services, progress: { progress.append($0) }, isCancelled: { false })
        check(events == ["heading:0","heading:2","navigation:0","navigation:2","reference:2","destination:0","destination:2"],
              "Coordinator finishes every instruction page before collecting references and scanning destinations")
        check(result.analyses.map(\.pageIndex) == [0,2] && result.analyses.map(\.staves) == input.map(\.staves),
              "Coordinator preserves selected source indices and detected physical staffs")
        check(result.analyses.allSatisfy { $0.sharedHeadings?.map(\.recognizedText) == ["New heading"] },
              "Fresh recognition replaces old metadata instead of appending to it")
        check(result.analyses[0].sharedNavigation == [glyph] && result.analyses[1].sharedNavigation == [instruction],
              "Linked destination stays on its observed page while the original instruction stays on its page")
        check(result.references.count == 1 && result.references[0].pageIndex == 0
              && result.references[0].match.templatePageIndex == 2, "Destination provenance preserves the actual reference page")
        check(Set(renders) == ["headings:0","headings:2","navigation:0","navigation:2","references:2","destinations:0","destinations:2"],
              "Coordinator renders only selected eligible pages for their required phase")
        check(progress.last?.phase == .destinations && progress.last?.completedPages == 2,
              "Recognition progress reaches the completed destination phase")

        var variable = profile; variable.requiresSystemAssignment = true
        events = []; renders = []
        let skipped = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: variable, render: { page, phase in
            renders.append("unexpected"); return image
        }, services: services, progress: { _ in }, isCancelled: { false })
        check(events.isEmpty && renders.isEmpty && skipped.issues.count == 2,
              "Variable layout is explicitly skipped without OCR calls or forced fixed-cadence ownership")
        check(skipped.analyses.allSatisfy { $0.sharedHeadings == nil && $0.sharedNavigation == nil },
              "Skipped layout cannot retain previous scan metadata as a fresh result")

        events = []
        var failing = services
        failing.navigation = { _, page, _, _ in
            if page.pageIndex == 0 { throw NSError(domain: "IndependentOCRFailure", code: 1) }
            return [instruction]
        }
        let failed = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: profile, render: { _,_ in image },
            services: failing, progress: { _ in }, isCancelled: { false })
        check(failed.analyses[0].sharedHeadings == [heading] && failed.analyses[0].sharedNavigation == nil,
              "A failed navigation module retains successful headings but clears stale instructions")
        check(!events.contains("destination:0") && events.contains("destination:2"),
              "Failed instruction OCR cannot classify that page's inline symbol as a destination")
        check(failed.issues.contains { $0.pageIndex == 0 && $0.message.contains("failed") }
              && ScoreExtractionPlanner.plan(pages: failed.analyses, profile: profile).canApply,
              "Module errors are visible without blocking valid staff crops")

        let renderFailure = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: profile, render: { page, phase in
            page.pageIndex == 0 && phase == .headings ? nil : image
        }, services: services, progress: { _ in }, isCancelled: { false })
        check(renderFailure.analyses[0].sharedHeadings == nil
              && renderFailure.issues.contains { $0.pageIndex == 0 && $0.message.contains("render") },
              "A failed phase render is reported separately and cannot leave a stale heading")

        var noReferences = services; noReferences.references = { _,_,_,_ in [] }; events = []
        let unsupported = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: profile,
            render: { _,_ in image }, services: noReferences, progress: { _ in }, isCancelled: { false })
        check(!events.contains { $0.hasPrefix("destination:") }
              && unsupported.issues.contains { $0.pageIndex == -1 && $0.message.contains("reference") },
              "Missing symbol reference is visible rather than reported as a successful no-match destination scan")

        for phase: ScoreDirectionPhase in [.headings,.navigation,.references,.destinations] {
            var stopped = false
            var cancelServices = services
            cancelServices.headings = { _,_,_,_ in if phase == .headings { stopped = true }; return [heading] }
            cancelServices.navigation = { _,_,_,_ in if phase == .navigation { stopped = true }; return [instruction] }
            cancelServices.references = { _,_,_,_ in if phase == .references { stopped = true }; return [reference] }
            cancelServices.destinations = { _,_,_,_,_ in if phase == .destinations { stopped = true }; return ([glyph], []) }
            let cancelled = ScoreSharedDirectionWorkflow.analyze(analyses: input, profile: profile,
                render: { _,_ in image }, services: cancelServices, progress: { _ in }, isCancelled: { stopped })
            check(cancelled.analyses == input && cancelled.issues.isEmpty && cancelled.references.isEmpty,
                  "Cancellation in each coordinator phase discards partial newly recognized metadata")
        }
    }
    static func main() throws {
        let source = sourcePDF()
        coordinator()
        try reviewEdits(source)
        workerLifecycle(source)
        print("\(checks) shared direction app checks passed")
    }
}
