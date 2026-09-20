import AppKit
import SwiftUI

struct ScoreExtractionView: View {
    @ObservedObject var document: PartsmithDocument
    @Environment(\.dismiss) private var dismiss
    @State private var profile = ScoreExtractionProfile(parts: [
        ScorePartDefinition(id: "violin1", name: "Violin I", staffCount: 1),
        ScorePartDefinition(id: "violin2", name: "Violin II", staffCount: 1),
        ScorePartDefinition(id: "viola", name: "Viola", staffCount: 1),
        ScorePartDefinition(id: "cello", name: "Cello", staffCount: 1)
    ], cropMode: "compact")
    @State private var review: ScoreDetectionReview?
    @State private var selectedPage = 0
    @State private var pageImage: CGImage?
    @State private var selectedStaves = Set<Int>()
    @State private var correctionSystem = 1
    @State private var correctionPart = ""
    @State private var correctionReason = ""
    @State private var movementTitle = ""
    @State private var confirmedReview = false
    @State private var showingDetectorNotes = true
    @State private var focusedCropID: String?
    @State private var errorMessage: String?

    private var isRunning: Bool { document.scoreDetectionProgress != nil }
    private var currentAnalysis: ScorePageAnalysis? { review?.analyses.first { $0.pageIndex == selectedPage } }
    private var currentPlan: ScorePagePlan? { review?.plan.pages.first { $0.pageIndex == selectedPage } }
    private struct DetectorNote: Identifiable {
        var id: String
        var title: String
        var warnings: [String]
    }
    private var currentDetectorNotes: [DetectorNote] {
        let staves = currentAnalysis?.staves ?? []
        let assignments = currentPlan?.assignments ?? []
        var notes = assignments.compactMap { band -> DetectorNote? in
            // Reviewed assignments still inherit detector evidence for their staves.
            let warnings = Array(Set(band.warnings + staves.filter { band.candidateIDs.contains($0.id) }.flatMap(\.warnings))).sorted()
            return warnings.isEmpty ? nil : DetectorNote(id: band.id,
                title: "\(partName(band.partID)) · System \(band.systemIndex + 1)", warnings: warnings)
        }
        let assignedIDs = Set(assignments.flatMap(\.candidateIDs))
        notes += staves.filter { !assignedIDs.contains($0.id) && !$0.warnings.isEmpty }.map {
            DetectorNote(id: "staff-\($0.id)", title: "Unassigned staff \($0.id + 1)", warnings: Array(Set($0.warnings)).sorted())
        }
        return notes
    }
    private var profileValid: Bool {
        let cropValues = [profile.topPaddingStaffSpaces, profile.bottomPaddingStaffSpaces,
                          profile.leftTrimPoints, profile.rightTrimPoints]
            + profile.parts.flatMap { [$0.topPaddingStaffSpaces, $0.bottomPaddingStaffSpaces] }
        return !profile.parts.isEmpty && profile.parts.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.staffCount > 0 }
            && Set(profile.parts.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count == profile.parts.count
            && cropValues.compactMap { $0 }.allSatisfy { $0.isFinite && $0 >= 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Extract Parts").font(.title2.bold())
                    Text("Set the instrument order, then find and assign staves throughout the score. Runs entirely on this Mac.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if review != nil {
                    Button("Change Setup") { review = nil; confirmedReview = false; errorMessage = nil }
                }
            }
            if let progress = document.scoreDetectionProgress {
                VStack(spacing: 14) {
                    ProgressView(value: Double(progress.completedPages), total: Double(max(progress.totalPages, 1)))
                    Text("Analyzed \(progress.completedPages) of \(progress.totalPages) pages")
                    Text("Instrument names come from your setup. Uncertain page layouts will be flagged for review.")
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let review {
                HSplitView {
                    pagePreview(review).frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                    reviewControls(review).frame(minWidth: 340, idealWidth: 390, maxWidth: 450)
                }
            } else {
                setupControls
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack {
                Button("Cancel") { document.cancelScoreDetection(); dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if let review {
                    Text("\(review.plan.parts.count) parts · \(review.plan.bands.count) bands")
                        .foregroundStyle(.secondary)
                    Button("Add Reviewed Parts", action: applyReview)
                        .buttonStyle(.borderedProminent)
                        .disabled(!review.plan.canApply || !confirmedReview || review.plan.bands.isEmpty)
                } else {
                    Button("Auto", action: runAuto).buttonStyle(.borderedProminent)
                        .disabled(!profileValid || isRunning)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 960, idealWidth: 1100, minHeight: 740, idealHeight: 860)
        .onAppear {
            if let saved = document.savedScoreProfile {
                profile = saved
            } else if !document.project.parts.isEmpty {
                profile.parts = document.project.parts.map { ScorePartDefinition(id: $0.id.uuidString, name: $0.name,
                    staffCount: $0.name.localizedCaseInsensitiveContains("piano") ? 2 : 1) }
            }
            correctionPart = profile.parts.first?.id ?? ""
        }
        .onDisappear { document.cancelScoreDetection() }
        .onChange(of: selectedPage) { updatePageImage() }
    }

    private var setupControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Instrumentation, from top to bottom in each system").font(.headline)
                Text("Names and staff counts are your reviewed setup, not automatic instrument recognition. Use two staves for a piano grand staff. A changed or missing staff order needs page review.")
                    .foregroundStyle(.secondary)
                Menu("Use a Starting Profile") {
                    Button("String Quartet") { setProfile([("Violin I", 1), ("Violin II", 1), ("Viola", 1), ("Cello", 1)]) }
                    Button("Clarinet Trio") { setProfile([("Clarinet in A", 1), ("Cello", 1), ("Piano", 2)]) }
                    Button("Voice and Piano") { setProfile([("Voice", 1), ("Piano", 2)], lyricIndices: [0]) }
                    Button("SATB Choir") { setProfile([("Soprano", 1), ("Alto", 1), ("Tenor", 1), ("Bass", 1)], lyricIndices: [0, 1, 2, 3]) }
                }
                ForEach(profile.parts.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).").frame(width: 24)
                        TextField("Instrument name", text: $profile.parts[index].name).textFieldStyle(.roundedBorder)
                        Stepper("\(profile.parts[index].staffCount) staff\(profile.parts[index].staffCount == 1 ? "" : "s")",
                                value: $profile.parts[index].staffCount, in: 1...4).frame(width: 140)
                        Toggle("Lyrics", isOn: Binding(get: { profile.parts[index].hasLyrics ?? false },
                            set: { profile.parts[index].hasLyrics = $0 })).toggleStyle(.checkbox)
                            .help("Search below this part for lyric rows and keep their complete letters. Review additional verses and shared directions.")
                        Button { profile.parts.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                            .disabled(index == 0).help("Move this instrument up in the source score order")
                        Button { profile.parts.remove(at: index) } label: { Image(systemName: "minus.circle") }
                            .disabled(profile.parts.count == 1).help("Remove instrument")
                    }
                }
                Button("Add Instrument", systemImage: "plus") {
                    profile.parts.append(ScorePartDefinition(id: UUID().uuidString, name: "New Instrument", staffCount: 1))
                }
                Picker("Crop mode", selection: Binding(get: { profile.cropMode ?? "fixed" }, set: { profile.cropMode = $0 })) {
                    Text("Compact — follow notation").tag("compact")
                    Text("Fixed padding").tag("fixed")
                }.pickerStyle(.segmented)
                Text(profile.cropMode == "compact"
                    ? "Compact crops follow nearby connected ink and lyric rows. Review detached directions and ink touching neighboring staves; uncertain ownership is flagged. Check Lyrics for vocal staves; multiple verses may need extra lower padding."
                    : "Fixed padding uses the space set below for every staff. It may include neighboring staves.")
                    .font(.caption).foregroundStyle(.secondary)
                cropContextControls
                Text("Auto processes all \(document.pdfDocument?.pageCount ?? 0) source pages. Review assignments, changed layouts, shared directions and crop edges before adding. Some neighboring notation may remain.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Your instrumentation setup is saved with the project when you run Auto.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(10)
        }
    }

    private var cropContextControls: some View {
        DisclosureGroup("Crop Context — Padding and Source Margins") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Padding is measured from the outer staff lines in staff spaces. Compact mode follows detected ink; enter optional minimum padding here for extra context. Zero uses the ink bounds. Fixed mode uses these distances directly. Increase them for detached directions, multiple verses or figured bass.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    cropNumberField("Above all parts", value: Binding(
                        get: { profile.topPaddingStaffSpaces ?? defaultTopPadding },
                        set: { profile.topPaddingStaffSpaces = $0 }), unit: "spaces")
                    cropNumberField("Below all parts", value: Binding(
                        get: { profile.bottomPaddingStaffSpaces ?? defaultBottomPadding },
                        set: { profile.bottomPaddingStaffSpaces = $0 }), unit: "spaces")
                }
                HStack(spacing: 16) {
                    cropNumberField("Trim left margin", value: Binding(
                        get: { profile.leftTrimPoints ?? 0 },
                        set: { profile.leftTrimPoints = $0 }), unit: "pt")
                    cropNumberField("Trim right margin", value: Binding(
                        get: { profile.rightTrimPoints ?? 0 },
                        set: { profile.rightTrimPoints = $0 }), unit: "pt")
                }
                Text("Trims use source-page points. Review the horizontal edges for clefs, key signatures, final barlines, and directions.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Optional padding for individual instruments").font(.subheadline.weight(.semibold))
                ForEach(profile.parts.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Custom padding for \(profile.parts[index].name)", isOn: Binding(
                            get: { profile.parts[index].topPaddingStaffSpaces != nil || profile.parts[index].bottomPaddingStaffSpaces != nil },
                            set: { enabled in
                                profile.parts[index].topPaddingStaffSpaces = enabled ? (profile.parts[index].topPaddingStaffSpaces ?? profile.topPaddingStaffSpaces ?? defaultTopPadding) : nil
                                profile.parts[index].bottomPaddingStaffSpaces = enabled ? (profile.parts[index].bottomPaddingStaffSpaces ?? profile.bottomPaddingStaffSpaces ?? defaultBottomPadding) : nil
                            }))
                            .toggleStyle(.checkbox)
                        if profile.parts[index].topPaddingStaffSpaces != nil || profile.parts[index].bottomPaddingStaffSpaces != nil {
                            HStack(spacing: 16) {
                                cropNumberField("Above", value: Binding(
                                    get: { profile.parts[index].topPaddingStaffSpaces ?? profile.topPaddingStaffSpaces ?? defaultTopPadding },
                                    set: { profile.parts[index].topPaddingStaffSpaces = $0 }), unit: "spaces")
                                cropNumberField("Below", value: Binding(
                                    get: { profile.parts[index].bottomPaddingStaffSpaces ?? profile.bottomPaddingStaffSpaces ?? defaultBottomPadding },
                                    set: { profile.parts[index].bottomPaddingStaffSpaces = $0 }), unit: "spaces")
                            }.padding(.leading, 20)
                        }
                    }
                }
            }.padding(.top, 10)
        }
    }

    private var defaultTopPadding: Double { profile.cropMode == "compact" ? 0 : 7 }
    private var defaultBottomPadding: Double { profile.cropMode == "compact" ? 0 : 7 }

    private func cropNumberField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder).frame(width: 70)
                .accessibilityLabel(title)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func pagePreview(_ review: ScoreDetectionReview) -> some View {
        GeometryReader { geometry in
            if let image = pageImage {
                let aspect = Double(image.width) / Double(image.height)
                let width = min(geometry.size.width, geometry.size.height * aspect)
                let height = width / aspect
                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1).resizable().frame(width: width, height: height)
                    ForEach(currentPlan?.assignments ?? []) { band in
                        let color = bandColor(band.partID)
                        Rectangle().fill(color.opacity(focusedCropID == band.id ? 0.18 : 0.06))
                            .overlay(Rectangle().stroke(color, lineWidth: focusedCropID == band.id ? 3 : 1))
                            .overlay(alignment: .topLeading) {
                                Text("\(partName(band.partID)) · \(band.systemIndex + 1)")
                                    .font(.system(size: 9, weight: .semibold)).padding(2).background(.regularMaterial)
                            }
                            .frame(width: width * (1 - band.leftFraction - band.rightFraction),
                                   height: height * (band.bottomFraction - band.topFraction))
                            .offset(x: width * band.leftFraction, y: height * band.topFraction)
                            .allowsHitTesting(false)
                    }
                    ForEach(currentAnalysis?.staves ?? []) { staff in
                        let center = (staff.staffLineFractions.first! + staff.staffLineFractions.last!) / 2
                        Button { toggleStaff(staff.id) } label: {
                            Text("\(staff.id + 1)").font(.caption2.bold()).foregroundStyle(.white)
                                .padding(3).background(selectedStaves.contains(staff.id) ? Color.orange : Color.blue, in: Capsule())
                        }.buttonStyle(.plain).offset(x: 0, y: height * center - 8)
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height)
            } else { Text("Source page could not be rendered.").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.background(Color(nsColor: .underPageBackgroundColor)).clipped()
    }

    private func reviewControls(_ review: ScoreDetectionReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Stepper("Source page \(selectedPage + 1) of \(review.analyses.count)", value: $selectedPage,
                        in: 0...max(0, review.analyses.count - 1))
                let unresolved = review.plan.pages.filter { !$0.unresolvedReasons.isEmpty }
                Text(unresolved.isEmpty ? "All pages have assignments or explicit exclusions." : "\(unresolved.count) pages need layout corrections.")
                    .font(.headline).foregroundStyle(unresolved.isEmpty ? Color.primary : .orange)
                if let next = unresolved.first(where: { $0.pageIndex != selectedPage }) {
                    Button("Go to Flagged Page \(next.pageIndex + 1)") { selectedPage = next.pageIndex }
                }
                if let excluded = review.excludedPageReasons[selectedPage] {
                    Text("Excluded: \(excluded)").foregroundStyle(.secondary)
                    Button("Restore Page") { changeReview { $0.excludedPageReasons.removeValue(forKey: selectedPage) } }
                }
                ForEach(currentPlan?.unresolvedReasons ?? [], id: \.self) { Text($0).font(.callout).foregroundStyle(.orange) }
                if !currentDetectorNotes.isEmpty {
                    DisclosureGroup("Detector notes (\(currentDetectorNotes.count))", isExpanded: $showingDetectorNotes) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(currentDetectorNotes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title).font(.caption.bold())
                                    ForEach(note.warnings, id: \.self) { Text($0).font(.caption).fixedSize(horizontal: false, vertical: true) }
                                }
                            }
                        }.padding(.top, 6)
                    }.foregroundStyle(.orange)
                }
                ForEach(profile.parts) { part in
                    let count = (currentPlan?.assignments ?? []).filter { $0.partID == part.id }.count
                    HStack { Text(part.name); Spacer(); Text("\(count) systems").foregroundStyle(.secondary) }
                }
                Text("Check every target note, ledger line, slur, lyric and shared tempo/rehearsal mark. Neighboring ink is allowed. After adding, crop expansion and source-marking review remain available in the Inspector.")
                    .font(.caption).foregroundStyle(.secondary)
                if !(currentPlan?.assignments.isEmpty ?? true), let analysis = currentAnalysis {
                    DisclosureGroup("Adjust crop edges on this page") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Source-page points measured down from the top. Decrease Top or increase Bottom to retain more notation. Check complete notes and detached marks before tightening an edge.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(currentPlan?.assignments ?? []) { band in
                                VStack(alignment: .leading, spacing: 6) {
                                    Button("\(partName(band.partID)) · System \(band.systemIndex + 1)") { focusedCropID = band.id }
                                        .buttonStyle(.link).help("Highlight this crop on the source page")
                                    HStack {
                                        cropNumberField("Top", value: cropEdgeBinding(band, height: analysis.pageHeight, top: true), unit: "pt")
                                        cropNumberField("Bottom", value: cropEdgeBinding(band, height: analysis.pageHeight, top: false), unit: "pt")
                                    }
                                    Button("Restore Automatic Edges") { editCrop(band.id, top: nil, bottom: nil) }
                                        .font(.caption)
                                }
                            }
                        }.padding(.top, 8)
                    }
                }
                Divider()
                DisclosureGroup("Correct this page's staff assignments") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select numbered staves on the source, then assign them as a group. Piano staves belong to the same system and part.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Selected: \(selectedStaves.sorted().map { String($0 + 1) }.joined(separator: ", "))")
                            .font(.caption)
                        Stepper("System \(correctionSystem)", value: $correctionSystem, in: 1...32)
                        Picker("Part", selection: $correctionPart) {
                            ForEach(profile.parts) { Text($0.name).tag($0.id) }
                        }
                        Button("Assign Selected Staves", action: assignSelected).disabled(selectedStaves.isEmpty)
                        TextField("Reason for omission or exclusion", text: $correctionReason).textFieldStyle(.roundedBorder)
                        Button("No Printed Staff for This Part", action: omitPart).disabled(correctionReason.isEmpty)
                        Button("Ignore Selected False Detections", action: ignoreSelected)
                            .disabled(correctionReason.isEmpty || selectedStaves.isEmpty)
                        Button("Exclude Page Without Score Music") {
                            changeReview { $0.excludedPageReasons[selectedPage] = correctionReason }
                        }.disabled(correctionReason.isEmpty)
                        Button("Restore Automatic Assignments") {
                            changeReview { $0.overrides.removeAll { $0.pageIndex == selectedPage } }
                        }
                        Divider()
                        TextField("Movement or song heading from the score", text: $movementTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("Start This System on a New Page") {
                            editOverride { correction in
                                correction.systems[correctionSystem - 1].movementLabel = movementTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                for index in correction.systems[correctionSystem - 1].bands.indices {
                                    correction.systems[correctionSystem - 1].bands[index].pageBreakBefore = true
                                }
                            }
                        }.disabled(movementTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.padding(.top, 8)
                }
                Divider()
                Toggle("I reviewed the assignments and crop edges", isOn: $confirmedReview)
                    .toggleStyle(.checkbox)
                Text("Adding is one undoable edit. Existing populated parts with the same names must be resolved first.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.leading, 12)
        }
    }

    private func setProfile(_ parts: [(String, Int)], lyricIndices: Set<Int> = []) {
        profile.parts = parts.enumerated().map { index, part in
            ScorePartDefinition(id: UUID().uuidString, name: part.0, staffCount: part.1, hasLyrics: lyricIndices.contains(index))
        }
        correctionPart = profile.parts.first?.id ?? ""
    }

    private func runAuto() {
        errorMessage = nil
        confirmedReview = false
        correctionPart = profile.parts.first?.id ?? ""
        document.saveScoreProfile(profile)
        document.detectScore(profile: profile) { result in
            guard let result else { errorMessage = "The source or rectification changed. Run Auto again."; return }
            review = result
            selectedPage = result.plan.pages.first(where: { !$0.unresolvedReasons.isEmpty })?.pageIndex ?? 0
            updatePageImage()
        }
    }

    private func updatePageImage() {
        selectedStaves.removeAll()
        focusedCropID = nil
        correctionSystem = 1
        pageImage = document.scoreReviewImage(pageIndex: selectedPage)
    }

    private func toggleStaff(_ id: Int) {
        if selectedStaves.contains(id) { selectedStaves.remove(id) } else { selectedStaves.insert(id) }
    }

    private func partName(_ id: String) -> String { profile.parts.first { $0.id == id }?.name ?? id }
    private func bandColor(_ id: String) -> Color {
        let colors: [Color] = [.blue, .red, .green, .purple, .orange, .teal]
        return colors[(profile.parts.firstIndex { $0.id == id } ?? 0) % colors.count]
    }

    private func changeReview(_ change: (inout ScoreDetectionReview) -> Void) {
        guard var value = review else { return }
        change(&value)
        value.replan()
        review = value
        confirmedReview = false
        errorMessage = nil
    }

    private func cropEdgeBinding(_ band: ScorePlannedBand, height: Double, top: Bool) -> Binding<Double> {
        Binding(get: {
            let current = review?.plan.bands.first { $0.id == band.id } ?? band
            return (top ? current.topFraction : current.bottomFraction) * height
        }, set: { value in
            guard let current = review?.plan.bands.first(where: { $0.id == band.id }) else { return }
            editCrop(band.id, top: top ? value : current.topFraction * height,
                     bottom: top ? current.bottomFraction * height : value)
        })
    }

    private func editCrop(_ bandID: String, top: Double?, bottom: Double?) {
        guard var value = review else { return }
        do {
            if let top, let bottom { try value.setCropEdges(for: bandID, top: top, bottom: bottom) }
            else { try value.resetCropEdges(for: bandID) }
            review = value
            confirmedReview = false
            focusedCropID = bandID
            errorMessage = nil
        } catch {
            confirmedReview = false
            errorMessage = error.localizedDescription
        }
    }

    private func pageOverride(_ review: ScoreDetectionReview) -> ScorePageOverride {
        if let existing = review.overrides.first(where: { $0.pageIndex == selectedPage }) { return existing }
        let assignments = review.plan.pages.first { $0.pageIndex == selectedPage }?.assignments ?? []
        let systems = Set(assignments.map(\.systemIndex)).sorted().map { system in
            ScoreSystemOverride(systemIndex: system, label: nil, movementLabel: nil,
                bands: assignments.filter { $0.systemIndex == system }.map {
                    ScoreBandOverride(partID: $0.partID, candidateIDs: $0.candidateIDs, rect: nil,
                                      label: nil, kind: nil, pageBreakBefore: nil)
                }, omittedParts: nil)
        }
        return ScorePageOverride(pageIndex: selectedPage, reason: "Instrument assignments reviewed in Auto Extract.", systems: systems)
    }

    private func editOverride(_ edit: (inout ScorePageOverride) -> Void) {
        changeReview { value in
            var correction = pageOverride(value)
            while correction.systems.count < correctionSystem {
                correction.systems.append(ScoreSystemOverride(systemIndex: correction.systems.count,
                    label: nil, movementLabel: nil, bands: [], omittedParts: []))
            }
            edit(&correction)
            value.overrides.removeAll { $0.pageIndex == selectedPage }
            value.overrides.append(correction)
        }
    }

    private func assignSelected() {
        editOverride { correction in
            for system in correction.systems.indices {
                for index in correction.systems[system].bands.indices {
                    correction.systems[system].bands[index].candidateIDs?.removeAll { selectedStaves.contains($0) }
                }
                correction.systems[system].bands.removeAll { ($0.candidateIDs ?? []).isEmpty && $0.rect == nil }
            }
            correction.ignoredCandidateIDs?.removeAll { selectedStaves.contains($0) }
            correction.systems[correctionSystem - 1].bands.removeAll { $0.partID == correctionPart }
            correction.systems[correctionSystem - 1].omittedParts?.removeAll { $0.partID == correctionPart }
            correction.systems[correctionSystem - 1].bands.append(ScoreBandOverride(partID: correctionPart,
                candidateIDs: selectedStaves.sorted(), rect: nil, label: nil, kind: nil, pageBreakBefore: nil))
            correction.systems[correctionSystem - 1].bands.sort { lhs, rhs in
                (profile.parts.firstIndex { $0.id == lhs.partID } ?? 0) < (profile.parts.firstIndex { $0.id == rhs.partID } ?? 0)
            }
        }
        selectedStaves.removeAll()
    }

    private func omitPart() {
        editOverride { correction in
            correction.systems[correctionSystem - 1].bands.removeAll { $0.partID == correctionPart }
            var omissions = correction.systems[correctionSystem - 1].omittedParts ?? []
            omissions.removeAll { $0.partID == correctionPart }
            omissions.append(ScorePartOmission(partID: correctionPart, reason: correctionReason))
            correction.systems[correctionSystem - 1].omittedParts = omissions
        }
    }

    private func ignoreSelected() {
        editOverride { correction in
            correction.reason = correctionReason
            correction.ignoredCandidateIDs = Array(Set(correction.ignoredCandidateIDs ?? []).union(selectedStaves)).sorted()
            for system in correction.systems.indices {
                for index in correction.systems[system].bands.indices {
                    correction.systems[system].bands[index].candidateIDs?.removeAll { selectedStaves.contains($0) }
                }
                correction.systems[system].bands.removeAll { ($0.candidateIDs ?? []).isEmpty && $0.rect == nil }
            }
        }
        selectedStaves.removeAll()
    }

    private func applyReview() {
        guard let review, confirmedReview else { return }
        guard document.addScoreParts(from: review) != nil else {
            errorMessage = "The review is stale, incomplete, or a populated part already has one of these names. Resolve it before adding."
            return
        }
        dismiss()
    }
}
