import AppKit
import PDFKit
import SwiftUI

struct ScoreExtractionView: View {
    @ObservedObject var document: PartsmithDocument
    var onClose: () -> Void
    var onShowScore: () -> Void
    @State private var profile = ScoreExtractionProfile(parts: [], cropMode: "compact")
    @State private var review: ScoreDetectionReview?
    @State private var selectedPage = 0
    @State private var pageImage: CGImage?
    @State private var selectedStaves = Set<Int>()
    @State private var correctionSystem = 1
    @State private var correctionPart = ""
    @State private var assigningSystems = false
    @State private var previewFitsWidth = false
    @State private var previewZoom = 1.0
    @State private var selectionAnchor: Int?
    @State private var printedPartIDs = Set<String>()
    @State private var systemFirstBar = ""
    @State private var systemBarCount = ""
    @State private var assignmentStatus: String?
    @State private var movementTitle = ""
    @State private var replaceListOnNextPick = false
    @State private var pickedInstrumentList = ScoreInstrumentPickList()
    @State private var pickStatus: String?
    @State private var deskewRunID: UUID?
    @State private var deskewStatus: String?
    @State private var showingDetectorNotes = false
    @State private var focusedCropID: String?
    @State private var errorMessage: String?
    @State private var findPrintedHeader = true
    @AppStorage("automaticallyCompressRestStrips") private var compressRests = true
    @State private var includeSuggestedHeader = true
    @State private var headerPreviewImage: CGImage?
    @State private var headerSourceImage: CGImage?
    @State private var headerSourcePageIndex: Int?
    @State private var usesAllPages = true
    @State private var selectedInputPages = Set<Int>()
    @State private var pageRangeText = ""
    @State private var pageRangeInvalid = false
    @StateObject private var thumbnails = ScoreInputThumbnails()

    private var sourcePageCount: Int { document.pdfDocument?.pageCount ?? 0 }
    private var inputPages: Set<Int> { usesAllPages ? Set(0..<sourcePageCount) : selectedInputPages }
    private var inputPagesValid: Bool { (usesAllPages || !pageRangeInvalid) && !inputPages.isEmpty }

    private var proposedHeader: SourceHeaderSelection? {
        guard let review, let header = review.suggestedSourceHeader,
              review.excludedPageReasons[header.pageIndex] == nil else { return nil }
        return header
    }
    private var displayedHeader: SourceHeaderSelection? { document.headerSelection ?? proposedHeader }

    private var hasSourceCrops: Bool { !document.project.bands.isEmpty || document.project.projectSettings.headerSelection != nil }
    private var isRunning: Bool { document.scoreDetectionProgress != nil || document.isAutoEstimatingPageRectifications }
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
                    Button("Change Setup") { review = nil; errorMessage = nil }
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
                    if assigningSystems {
                        systemAssignmentControls(review).frame(minWidth: 270, idealWidth: 290, maxWidth: 330)
                    } else {
                        reviewControls(review).frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
                    }
                }
            } else {
                HSplitView {
                    inputPagePicker.frame(minWidth: 240, idealWidth: 260, maxWidth: 320)
                    setupControls.frame(minWidth: 460, maxWidth: .infinity)
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack {
                Button("Cancel") { cancelWork(); onClose() }.keyboardShortcut(.cancelAction)
                Spacer()
                if let review {
                    Text("\(review.plan.parts.count) parts · \(review.plan.bands.count) bands")
                        .foregroundStyle(.secondary)
                    Button("Add Parts", action: applyReview)
                        .buttonStyle(.borderedProminent)
                        .disabled(!review.plan.canApply || review.plan.bands.isEmpty)
                } else {
                    Button("Auto", action: runAuto).buttonStyle(.borderedProminent)
                        .disabled(!profileValid || !inputPagesValid || isRunning)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 800, idealWidth: 1200, minHeight: 580, idealHeight: 820)
        .onAppear {
            if let saved = document.savedScoreProfile {
                profile = saved
            } else if !document.project.parts.isEmpty {
                profile.parts = document.project.parts.map { ScorePartDefinition(id: $0.id.uuidString, name: $0.name,
                    staffCount: $0.name.localizedCaseInsensitiveContains("piano") ? 2 : 1) }
            }
            correctionPart = profile.parts.first?.id ?? ""
            findPrintedHeader = document.headerSelection == nil && document.project.projectSettings.headerDisplayMode == .sourceSelection
            updateHeaderPreview()
            resetInputPages()
        }
        .onDisappear(perform: cancelWork)
        .onChange(of: document.instrumentNamePick?.id) { receiveInstrumentNamePick() }
        .onChange(of: document.sourcePDFData) { invalidateSourceReview(); resetInputPages() }
        .onChange(of: document.project.pageRectifications) { invalidateSourceReview(); refreshThumbnails() }
        .onChange(of: selectedPage) { updatePageImage() }
        .onChange(of: document.headerSelection) { updateHeaderPreview() }
    }

    private var inputPagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pages to extract").font(.headline)
            Picker("Pages to extract", selection: $usesAllPages) {
                Text("All Pages").tag(true)
                Text("Selected Pages").tag(false)
            }.pickerStyle(.segmented)
            if !usesAllPages {
                TextField("For example: 1-8, 12", text: $pageRangeText)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Page range")
                    .onChange(of: pageRangeText) {
                        if let pages = ScoreInputPageSelection.parse(pageRangeText, pageCount: sourcePageCount) {
                            selectedInputPages = pages
                            pageRangeInvalid = false
                        } else { pageRangeInvalid = true }
                    }
                if pageRangeInvalid {
                    Text("Use page numbers from 1 to \(sourcePageCount), such as 1-4, 7.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            HStack {
                Button("Current Page") { setInputPages([document.currentPageIndex]) }
                Button("Clear") { setInputPages([]) }
                Spacer()
            }.controlSize(.small)
            Text("\(inputPages.count) of \(sourcePageCount) pages selected")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<sourcePageCount, id: \.self) { page in
                        inputThumbnail(page)
                    }
                }.padding(5).id(thumbnails.generation)
            }
            Text("Click previews to include or leave out pages. Deskew and Auto use this selection.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.trailing, 12).disabled(isRunning)
    }

    private func inputThumbnail(_ page: Int) -> some View {
        let included = inputPages.contains(page)
        return Button {
            var pages = inputPages
            if included { pages.remove(page) } else { pages.insert(page) }
            setInputPages(pages)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Rectangle().fill(.white)
                    if let image = thumbnails.images[page] {
                        Image(decorative: image, scale: 1).resizable().scaledToFit()
                    } else if thumbnails.failedPages.contains(page) {
                        Image(systemName: "doc").foregroundStyle(.gray)
                    } else { ProgressView().controlSize(.small) }
                }.frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(included ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: included ? 3 : 1))
                    .opacity(included ? 1 : 0.55)
                Label("Page \(page + 1)", systemImage: included ? "checkmark.circle.fill" : "circle")
                    .font(.caption).foregroundStyle(included ? Color.accentColor : .secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("Source page \(page + 1)")
            .accessibilityValue(included ? "Included" : "Not included")
            .help(included ? "Leave page \(page + 1) out of extraction" : "Include page \(page + 1)")
            .onAppear { thumbnails.request(page) }
    }

    private func setInputPages(_ pages: Set<Int>) {
        usesAllPages = false
        selectedInputPages = pages
        pageRangeText = ScoreInputPageSelection.formatted(pages)
        pageRangeInvalid = false
    }

    private func resetInputPages() {
        usesAllPages = true
        selectedInputPages = Set(0..<sourcePageCount)
        pageRangeText = ScoreInputPageSelection.formatted(selectedInputPages)
        pageRangeInvalid = false
        refreshThumbnails()
    }

    private func refreshThumbnails() {
        thumbnails.configure(data: document.sourcePDFData, rectifications: document.project.pageRectifications)
    }

    private var setupControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Straighten scanned pages (optional)").font(.headline)
                    Text("Deskew and align the pages before identifying instruments and staves. Existing page corrections are kept.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Deskew & Align Pages", systemImage: "viewfinder", action: deskewPages)
                            .disabled(isRunning || hasSourceCrops || !inputPagesValid)
                        if let progress = document.rectificationAutoProgress {
                            ProgressView(value: progress.fractionComplete).frame(width: 140)
                            Text("\(progress.completedPageCount) of \(progress.totalPageCount) pages").foregroundStyle(.secondary)
                        }
                    }
                    if hasSourceCrops {
                        Text("This project already has crops or a selected header. Page alignment can be adjusted in the Inspector.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let deskewStatus { Text(deskewStatus).font(.callout).foregroundStyle(.secondary) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text("2. Instruments, from top to bottom in each system").font(.headline)
                Text("Type names, choose a starting profile, or click the printed names on the score. Use two staves for a piano grand staff. You can edit every name and staff count.")
                    .foregroundStyle(.secondary)
                Menu("Use a Starting Profile") {
                    Button("String Quartet") { setProfile([("Violin I", 1), ("Violin II", 1), ("Viola", 1), ("Cello", 1)]) }
                    Button("Clarinet Trio") { setProfile([("Clarinet in A", 1), ("Cello", 1), ("Piano", 2)]) }
                    Button("Voice and Piano") { setProfile([("Voice", 1), ("Piano", 2)], lyricIndices: [0]) }
                    Button("SATB Choir") { setProfile([("Soprano", 1), ("Alto", 1), ("Tenor", 1), ("Bass", 1)], lyricIndices: [0, 1, 2, 3]) }
                }
                HStack {
                    Menu("Pick Names from Score", systemImage: "cursorarrow.click") {
                        Button("Start a New List") { startPickingNames(replacingList: true) }
                        Button("Add to This List") { startPickingNames(replacingList: false) }
                    }.disabled(isRunning)
                    if document.isPickingInstrumentNames {
                        Button("Show Score", action: onShowScore)
                        Button("Done Picking") { document.cancelInstrumentNamePicking() }
                    }
                }
                if document.isPickingInstrumentNames {
                    Text("Click a printed instrument name, or drag around its full label. Work from top to bottom; repeated names become separate numbered parts.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let pickStatus { Text(pickStatus).font(.callout).foregroundStyle(.secondary) }
                ForEach(profile.parts.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).").frame(width: 24)
                        TextField("Instrument name", text: $profile.parts[index].name).textFieldStyle(.roundedBorder)
                        Stepper(profile.parts[index].staffCount == 1 ? "1 staff" : "\(profile.parts[index].staffCount) staves",
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
                Toggle("Instrument layout changes between systems", isOn: Binding(
                    get: { profile.requiresSystemAssignment ?? false },
                    set: { profile.requiresSystemAssignment = $0 }))
                    .toggleStyle(.checkbox)
                Text("For scores that hide silent instruments, Auto finds the staves, then you choose the printed instruments for each system and enter its bar count. Absent instruments receive counted rests.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("3. Printed score header").font(.headline)
                if document.headerSelection != nil {
                    Text("Your existing header selection will be kept.").foregroundStyle(.secondary)
                    Button("Adjust Header on Score") { editHeaderOnScore() }
                } else {
                    Toggle("Find the printed title and composer automatically", isOn: $findPrintedHeader)
                        .toggleStyle(.checkbox)
                    Text("Auto finds a header above the first music system and shows a preview. The original score image will appear on the first page of each part.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Toggle("Count and compress full-bar rests automatically", isOn: $compressRests)
                    .toggleStyle(.checkbox)
                Text("After adding parts, Partsmith checks for rest-only strips and keeps their printed opening and ending context. Uncertain passages stay as source notation.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Picker("Crop mode", selection: Binding(get: { profile.cropMode ?? "fixed" }, set: { profile.cropMode = $0 })) {
                    Text("Compact — follow notation").tag("compact")
                    Text("Fixed padding").tag("fixed")
                }.pickerStyle(.segmented)
                Text(profile.cropMode == "compact"
                    ? "Compact crops follow nearby connected ink and lyric rows. Review detached directions and ink touching neighboring staves; uncertain ownership is flagged. Check Lyrics for vocal staves; multiple verses may need extra lower padding."
                    : "Fixed padding uses the space set below for every staff. It may include neighboring staves.")
                    .font(.caption).foregroundStyle(.secondary)
                cropContextControls
                Text("Auto processes the \(inputPages.count) selected source pages. Pages with no detected staves are skipped automatically. You can review assignments and crop edges before adding; some neighboring notation may remain.")
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

    private func pageNavigation(_ review: ScoreDetectionReview) -> some View {
        let pages = review.analyses.map(\.pageIndex).sorted()
        let position = pages.firstIndex(of: selectedPage) ?? 0
        return HStack(spacing: 8) {
            Button {
                guard position > 0 else { return }
                selectedPage = pages[position - 1]
            } label: { Image(systemName: "chevron.left") }
                .disabled(position == 0).accessibilityLabel("Previous selected page")
            Picker("Page", selection: $selectedPage) {
                ForEach(pages, id: \.self) { Text("\($0 + 1)").tag($0) }
            }.frame(maxWidth: 135)
            Button {
                guard position + 1 < pages.count else { return }
                selectedPage = pages[position + 1]
            } label: { Image(systemName: "chevron.right") }
                .disabled(position + 1 >= pages.count).accessibilityLabel("Next selected page")
        }
    }

    private func pagePreview(_ review: ScoreDetectionReview) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                pageNavigation(review)
                Spacer(minLength: 0)
                Button("Fit Page") { previewFitsWidth = false; previewZoom = 1 }
                Button("Fit Width") { previewFitsWidth = true; previewZoom = 1 }
                Button { previewZoom = max(0.5, previewZoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    .accessibilityLabel("Zoom out")
                Button { previewZoom = min(4, previewZoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                    .accessibilityLabel("Zoom in")
            }.controlSize(.small)
            GeometryReader { geometry in
                if let image = pageImage {
                    let aspect = Double(image.width) / Double(image.height)
                    let availableWidth = max(100, geometry.size.width - 28)
                    let fitWidth = previewFitsWidth ? availableWidth : min(availableWidth, geometry.size.height * aspect)
                    let width = fitWidth * previewZoom
                    let height = width / aspect
                    ScrollView([.horizontal, .vertical]) {
                        scorePageOverlay(image: image, width: width, height: height)
                            .padding(.leading, 28)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }.id(selectedPage)
                } else {
                    Text("Source page could not be rendered.").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.background(Color(nsColor: .underPageBackgroundColor)).clipped()
            HStack {
                Text(assigningSystems ? "Click staves to select. Shift-click selects a range." : "Zoom or choose Assign Instruments to change the staff layout.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(assigningSystems ? "Crop Review" : "Assign Instruments") { toggleAssignmentMode() }
            }
        }
    }

    private func scorePageOverlay(image: CGImage, width: Double, height: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Image(decorative: image, scale: 1).resizable().frame(width: width, height: height)
            ForEach((currentPlan?.assignments ?? []).filter { $0.generatedRest == nil }) { band in
                let color = bandColor(band.partID)
                Rectangle().fill(color.opacity(focusedCropID == band.id ? 0.18 : 0.04))
                    .overlay(Rectangle().stroke(color, lineWidth: focusedCropID == band.id ? 3 : 1))
                    .overlay(alignment: .topLeading) {
                        if !assigningSystems {
                            Text("\(partName(band.partID)) · \(band.systemIndex + 1)")
                                .font(.system(size: 10, weight: .semibold)).padding(2).background(.regularMaterial)
                        }
                    }
                    .frame(width: width * (1 - band.leftFraction - band.rightFraction),
                           height: height * (band.bottomFraction - band.topFraction))
                    .offset(x: width * band.leftFraction, y: height * band.topFraction)
                    .allowsHitTesting(false)
            }
            ForEach(currentAnalysis?.staves ?? []) { staff in
                staffSelectionRow(staff, width: width, height: height)
            }
        }.frame(width: width, height: height)
    }

    private func staffSelectionRow(_ staff: ScoreObservedStaff, width: Double, height: Double) -> some View {
        let top = staff.staffLineFractions.first ?? staff.topFraction
        let bottom = staff.staffLineFractions.last ?? staff.bottomFraction
        let selected = selectedStaves.contains(staff.id)
        let assignment = staffAssignment(staff.id)
        let color = selected ? Color.orange : assignment.map { bandColor($0.partID) } ?? Color.blue
        let rowHeight = max(12, height * (bottom - top))
        return Button { toggleStaff(staff.id) } label: {
            HStack(spacing: 0) {
                Text("\(staff.id + 1)").font(.caption2.bold()).foregroundStyle(.white)
                    .frame(width: 24, height: 20).background(color, in: Capsule())
                Rectangle().fill(selected ? Color.orange.opacity(0.22) : .clear)
                    .overlay(Rectangle().stroke(selected ? Color.orange : .clear, lineWidth: 2))
                    .frame(width: width, height: rowHeight)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
            .frame(width: width + 24, height: rowHeight)
            .offset(x: -24, y: height * top)
            .accessibilityLabel("Staff \(staff.id + 1)" + (assignment.map { ", \(partName($0.partID)), system \($0.system + 1)" } ?? ", unassigned"))
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .help(assignment.map { "\(partName($0.partID)) · System \($0.system + 1). Click to select." } ?? "Click to select this staff")
    }

    private func staffAssignment(_ id: Int) -> (partID: String, system: Int)? {
        if let correction = review?.overrides.first(where: { $0.pageIndex == selectedPage }) {
            for system in correction.systems {
                if let band = system.bands.first(where: { ($0.candidateIDs ?? []).contains(id) }) {
                    return (band.partID, system.systemIndex)
                }
            }
            return nil
        }
        return currentPlan?.assignments.first(where: { $0.candidateIDs.contains(id) }).map { ($0.partID, $0.systemIndex) }
    }

    private func toggleAssignmentMode() {
        assigningSystems.toggle()
        if assigningSystems {
            previewFitsWidth = true
            previewZoom = 1
            if printedPartIDs.isEmpty { printedPartIDs = Set(profile.parts.map(\.id)) }
        }
    }

    private func systemAssignmentControls(_ review: ScoreDetectionReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Assign a System").font(.headline)
                Text("Select every printed staff in one system. Check the instruments shown, in score order. The same choices stay ready for the next system.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Stepper("System \(correctionSystem)", value: $correctionSystem, in: 1...32)
                    Button("Load") { loadSystemAssignment() }.help("Select this system's current staves and instrument choices")
                }
                HStack {
                    Text("\(selectedStaves.count) staves selected")
                    Spacer()
                    Button("Clear") { selectedStaves.removeAll(); selectionAnchor = nil }
                }.font(.caption)
                Text("Instruments printed in this system").font(.subheadline.bold())
                ForEach(profile.parts) { part in
                    Toggle(isOn: Binding(get: { printedPartIDs.contains(part.id) }, set: { included in
                        if included { printedPartIDs.insert(part.id) } else { printedPartIDs.remove(part.id) }
                    })) {
                        HStack {
                            Text(part.name)
                            Spacer()
                            Text("\(part.staffCount)").foregroundStyle(.secondary).font(.caption)
                        }
                    }.toggleStyle(.checkbox)
                }
                HStack {
                    Button("All") { printedPartIDs = Set(profile.parts.map(\.id)) }
                    Button("None") { printedPartIDs.removeAll() }
                    Spacer()
                    Text("\(expectedSelectedStaffCount) staves expected").font(.caption).foregroundStyle(.secondary)
                }.controlSize(.small)
                Divider()
                HStack {
                    Text("First bar")
                    TextField("Optional", text: $systemFirstBar).textFieldStyle(.roundedBorder).frame(width: 80)
                }
                HStack {
                    Text("Bars in system")
                    TextField("Count", text: $systemBarCount).textFieldStyle(.roundedBorder).frame(width: 80)
                }
                if printedPartIDs.count < profile.parts.count {
                    Text("Unchecked instruments receive this many bars of rest. Confirm they are silent, and keep any tempo, meter or rehearsal changes at their original bar.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("The bar count is required when silent instruments are omitted.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Assign System", action: assignSystemSelection)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedStaves.isEmpty || selectedStaves.count != expectedSelectedStaffCount || printedPartIDs.isEmpty)
                if let assignmentStatus { Text(assignmentStatus).font(.caption).foregroundStyle(.secondary) }
                Divider()
                if let correction = review.overrides.first(where: { $0.pageIndex == selectedPage }) {
                    ForEach(correction.systems, id: \.systemIndex) { system in
                        Button {
                            correctionSystem = system.systemIndex + 1
                            loadSystemAssignment()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("System \(system.systemIndex + 1)").font(.subheadline.bold())
                                Text(system.bands.map { partName($0.partID) }.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.secondary)
                                if let count = system.barCount {
                                    if let first = system.startBarNumber, first <= Int.max - count + 1 {
                                        Text("Bars \(first)–\(first + count - 1)").font(.caption)
                                    } else {
                                        Text("\(count) bars").font(.caption)
                                    }
                                    if let omitted = system.omittedParts, !omitted.isEmpty {
                                        Text("\(count)-bar rest: " + omitted.map { partName($0.partID) }.joined(separator: ", "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
                ForEach(currentPlan?.unresolvedReasons ?? [], id: \.self) {
                    Text($0).font(.caption).foregroundStyle(.orange)
                }
                Button("Ignore Selected False Detections", action: ignoreSelected).disabled(selectedStaves.isEmpty)
                Button("Restore Automatic Assignments") {
                    changeReview { $0.overrides.removeAll { $0.pageIndex == selectedPage } }
                    selectedStaves.removeAll(); assignmentStatus = nil
                }
                Button("Show Score Window", action: onShowScore)
            }.padding(.leading, 12).padding(.bottom, 8)
        }
    }

    private var expectedSelectedStaffCount: Int {
        profile.parts.filter { printedPartIDs.contains($0.id) }.reduce(0) { $0 + $1.staffCount }
    }

    private func loadSystemAssignment() {
        guard let review else { return }
        let correction = pageOverride(review)
        guard let system = correction.systems.first(where: { $0.systemIndex == correctionSystem - 1 }) else { return }
        selectedStaves = Set(system.bands.flatMap { $0.candidateIDs ?? [] })
        printedPartIDs = Set(system.bands.map(\.partID))
        systemFirstBar = system.startBarNumber.map(String.init) ?? ""
        systemBarCount = system.barCount.map(String.init) ?? ""
        selectionAnchor = nil
        assignmentStatus = nil
    }

    private func assignSystemSelection() {
        guard var value = review, let analysis = currentAnalysis else { return }
        let firstText = systemFirstBar.trimmingCharacters(in: .whitespacesAndNewlines)
        let countText = systemBarCount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard firstText.isEmpty || Int(firstText).map({ $0 > 0 }) == true,
              countText.isEmpty || Int(countText).map({ (1...999).contains($0) }) == true else {
            errorMessage = "Use a positive first bar and a bar count from 1 to 999."
            return
        }
        do {
            let correction = try ScoreSystemAssignment.assign(page: analysis, profile: profile,
                pagePlan: currentPlan, existingOverride: value.overrides.first(where: { $0.pageIndex == selectedPage }),
                systemIndex: correctionSystem - 1, candidateIDs: selectedStaves.sorted(), presentPartIDs: printedPartIDs,
                startBarNumber: Int(firstText), barCount: Int(countText))
            value.overrides.removeAll { $0.pageIndex == selectedPage }
            value.overrides.append(correction)
            value.replan()
            review = value
            let restParts = profile.parts.count - printedPartIDs.count
            assignmentStatus = "System \(correctionSystem) assigned." + (restParts > 0 ? " Added \(countText)-bar rests for \(restParts) absent instruments." : "")
            correctionSystem = min(32, correctionSystem + 1)
            selectedStaves.removeAll(); selectionAnchor = nil
            // A repeated instrument layout does not imply a repeated measure count.
            if let first = Int(firstText), let count = Int(countText), first <= Int.max - count {
                systemFirstBar = String(first + count)
            } else { systemFirstBar = "" }
            systemBarCount = ""
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func reviewControls(_ review: ScoreDetectionReview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button("Assign Instruments on Enlarged Score") { toggleAssignmentMode() }
                    .buttonStyle(.borderedProminent)
                let unresolved = review.plan.pages.filter { !$0.unresolvedReasons.isEmpty }
                let assignedCount = review.plan.pages.filter { !$0.assignments.isEmpty }.count
                Text("\(assignedCount) pages assigned · \(review.excludedPageReasons.count) excluded · \(unresolved.count) need review")
                    .font(.headline).foregroundStyle(unresolved.isEmpty ? Color.primary : .orange)
                if !review.autoSkippedPageIndices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(review.autoSkippedPageIndices.count) pages skipped — no staves found.")
                            .font(.subheadline.bold())
                        Text("These skipped pages won’t block adding parts. You can look through them if you’d like.")
                            .font(.caption).foregroundStyle(.secondary)
                        let skipped = review.autoSkippedPageIndices.sorted()
                        Button("View Skipped Pages") {
                            selectedPage = skipped.first(where: { $0 > selectedPage }) ?? skipped[0]
                        }
                    }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                if review.plan.bands.isEmpty && unresolved.isEmpty {
                    Text("No music was found in the selected pages. Choose Change Setup to select other pages.")
                        .foregroundStyle(.secondary)
                }
                if let next = review.nextPageNeedingReview(after: selectedPage), next != selectedPage {
                    Button("Go to Flagged Page \(next + 1)") { selectedPage = next }
                }
                if let excluded = review.excludedPageReasons[selectedPage] {
                    Text("Excluded: \(excluded)").foregroundStyle(.secondary)
                    Button("Restore Page") { changeReview { $0.restoreExcludedPage(selectedPage) } }
                }
                ForEach(currentPlan?.unresolvedReasons ?? [], id: \.self) { Text($0).font(.callout).foregroundStyle(.orange) }
                if currentAnalysis?.staves.isEmpty == true && review.excludedPageReasons[selectedPage] == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No staves detected — no part bands assigned on this page.").font(.subheadline.bold())
                        Text("This page can be skipped if it is blank or has no score music. If music is missing, check its orientation or alignment before rerunning Auto.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Exclude This Page") { excludeCurrentPage(reason: "Non-music page excluded in Auto Extract.") }
                    }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                if findPrintedHeader || document.headerSelection != nil {
                    sourceHeaderReview
                }
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
                if !(currentPlan?.assignments.isEmpty ?? true) {
                    ForEach(profile.parts) { part in
                        let count = (currentPlan?.assignments ?? []).filter { $0.partID == part.id }.count
                        let restingBars = (currentPlan?.assignments ?? []).filter { $0.partID == part.id }
                            .compactMap(\.generatedRest).reduce(0) { $0 + $1.barCount }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(part.name); Spacer(); Text("\(count) systems").foregroundStyle(.secondary) }
                            if restingBars > 0 {
                                Text("\(restingBars) bars of inserted rest").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Text("You can click through to check the notes, slurs, lyrics and shared markings. Crop edges remain editable after adding the parts.")
                    .font(.caption).foregroundStyle(.secondary)
                if !(currentPlan?.assignments.isEmpty ?? true), let analysis = currentAnalysis {
                    DisclosureGroup("Adjust crop edges on this page") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Source-page points measured down from the top. Decrease Top or increase Bottom to retain more notation. Check complete notes and detached marks before tightening an edge.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach((currentPlan?.assignments ?? []).filter { $0.generatedRest == nil }) { band in
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
                        Button("Set Absent Instruments & Rests") { toggleAssignmentMode(); loadSystemAssignment() }
                        Button("Ignore Selected False Detections", action: ignoreSelected)
                            .disabled(selectedStaves.isEmpty)
                        Button("Exclude Page Without Score Music") {
                            excludeCurrentPage(reason: "Non-music page excluded in Auto Extract.")
                        }
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
                Text("Adding is one undoable edit. Existing populated parts with the same names must be resolved first.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.leading, 12)
        }
    }

    private var sourceHeaderReview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header = displayedHeader {
                if document.headerSelection == nil {
                    Toggle("Use Printed Header", isOn: $includeSuggestedHeader).toggleStyle(.checkbox)
                } else {
                    Text("Printed Header").font(.subheadline.bold())
                    if document.project.projectSettings.headerDisplayMode != .sourceSelection || !document.project.projectSettings.showTitleBlock {
                        Text("This saved header is not currently shown in the parts.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Use This Header", action: activatePrintedHeader)
                    }
                }
                if let image = headerPreviewImage {
                    Image(decorative: image, scale: 1).resizable().scaledToFit()
                        .frame(maxHeight: 110).background(.white)
                        .accessibilityLabel("Printed score header from source page \(header.pageIndex + 1)")
                }
                HStack {
                    Text("Source page \(header.pageIndex + 1)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Adjust on Score") { editHeaderOnScore() }
                }
            } else {
                Text("No printed header found").font(.subheadline.bold())
                Button("Select Header on Score") { editHeaderOnScore() }
            }
        }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func updateHeaderPreview() {
        guard let header = displayedHeader else { headerPreviewImage = nil; return }
        if headerSourcePageIndex != header.pageIndex || headerSourceImage == nil {
            headerSourceImage = document.scoreReviewImage(pageIndex: header.pageIndex)
            headerSourcePageIndex = header.pageIndex
        }
        guard let image = headerSourceImage else { headerPreviewImage = nil; return }
        let rect = CGRect(x: header.leftFraction * Double(image.width),
            y: header.topFraction * Double(image.height),
            width: (1 - header.leftFraction - header.rightFraction) * Double(image.width),
            height: (header.bottomFraction - header.topFraction) * Double(image.height))
        headerPreviewImage = image.cropping(to: rect.integral)
    }

    private func activatePrintedHeader() {
        if document.project.projectSettings.headerDisplayMode != .sourceSelection {
            document.updateProjectHeaderDisplayMode(.sourceSelection)
        }
        if !document.project.projectSettings.showTitleBlock {
            document.updateProjectShowTitleBlock(true)
        }
    }

    private func editHeaderOnScore() {
        document.cancelInstrumentNamePicking()
        if document.headerSelection == nil, let header = proposedHeader {
            document.updateHeaderSelection(pageIndex: header.pageIndex,
                topFraction: header.topFraction, bottomFraction: header.bottomFraction,
                leftFraction: header.leftFraction, rightFraction: header.rightFraction)
        }
        if document.headerSelection == nil {
            document.currentPageIndex = review?.analyses.first(where: { !$0.staves.isEmpty })?.pageIndex ?? 0
        }
        activatePrintedHeader()
        document.setHeaderSelectionEditing(true)
        onShowScore()
    }

    private func setProfile(_ parts: [(String, Int)], lyricIndices: Set<Int> = []) {
        document.cancelInstrumentNamePicking()
        pickedInstrumentList.reset()
        replaceListOnNextPick = false
        pickStatus = nil
        profile.parts = parts.enumerated().map { index, part in
            ScorePartDefinition(id: UUID().uuidString, name: part.0, staffCount: part.1, hasLyrics: lyricIndices.contains(index))
        }
        correctionPart = profile.parts.first?.id ?? ""
    }

    private func deskewPages() {
        guard !isRunning, !hasSourceCrops, inputPagesValid else { return }
        document.cancelInstrumentNamePicking()
        document.setHeaderSelectionEditing(false)
        document.setPageRectificationEditing(false)
        deskewStatus = nil
        errorMessage = nil
        deskewRunID = document.autoEstimateAllPageRectifications(onlyUnrectified: true, pageIndices: inputPages) { result in
            deskewRunID = nil
            switch result {
            case .completed(let count):
                deskewStatus = count == 0 ? "Page preparation complete. No new alignment corrections were needed."
                    : "Aligned \(count) pages. Choose or click the instrument names next."
            case .cancelled: deskewStatus = "Page preparation cancelled."
            case .sourceChanged: errorMessage = "The source, page alignment, or crops changed. Run page preparation again."
            case .unavailable: errorMessage = "The source pages could not be prepared. You can continue with the original pages."
            }
        }
    }

    private func cancelWork() {
        document.cancelScoreDetection()
        document.cancelInstrumentNamePicking()
        if let deskewRunID { document.cancelAutoEstimateAllPageRectifications(runID: deskewRunID) }
    }

    private func startPickingNames(replacingList: Bool) {
        guard !isRunning else { return }
        document.cancelInstrumentNamePicking()
        document.setHeaderSelectionEditing(false)
        document.setPageRectificationEditing(false)
        replaceListOnNextPick = replacingList
        pickStatus = replacingList ? "The first name you select starts a new list." : "Selected names will be added to this list."
        document.isPickingInstrumentNames = true
        onShowScore()
    }

    private func receiveInstrumentNamePick() {
        guard document.isPickingInstrumentNames, let pick = document.instrumentNamePick else { return }
        var nextParts = replaceListOnNextPick ? [] : profile.parts
        var nextPickList = replaceListOnNextPick ? ScoreInstrumentPickList() : pickedInstrumentList
        guard let result = nextPickList.apply(pick, to: &nextParts) else { return }
        profile.parts = nextParts
        pickedInstrumentList = nextPickList
        replaceListOnNextPick = false
        correctionPart = profile.parts.first?.id ?? ""
        switch result {
        case .added(_, let name):
            document.updateInstrumentNameHighlight(id: pick.id, name: name)
            pickStatus = "Added \(name). Click or drag around the next name, or choose Done."
        case .updated(_, let name):
            document.updateInstrumentNameHighlight(id: pick.id, name: name)
            pickStatus = "Updated \(name). Click or drag around the next name, or choose Done."
        case .existing(_, let name):
            document.updateInstrumentNameHighlight(id: pick.id, name: name)
            pickStatus = "\(name) is already added. Click or drag around a different printed label to add another part."
        }
    }

    private func invalidateSourceReview() {
        let hadAnalysis = review != nil || isRunning
        document.cancelScoreDetection()
        document.cancelInstrumentNamePicking()
        pickedInstrumentList.reset()
        review = nil
        pageImage = nil
        headerPreviewImage = nil
        headerSourceImage = nil
        headerSourcePageIndex = nil
        selectedStaves.removeAll()
        if hadAnalysis { errorMessage = "The source or page alignment changed. Run Auto again to update the crops." }
    }

    private func runAuto() {
        guard profileValid, inputPagesValid, !isRunning else { return }
        document.cancelInstrumentNamePicking()
        errorMessage = nil
        correctionPart = profile.parts.first?.id ?? ""
        document.saveScoreProfile(profile)
        document.detectScore(profile: profile, findSourceHeader: findPrintedHeader && document.headerSelection == nil,
                             pageIndices: inputPages) { result in
            guard let result else { errorMessage = "The source or rectification changed. Run Auto again."; return }
            review = result
            if profile.requiresSystemAssignment == true {
                assigningSystems = true
                previewFitsWidth = true
                previewZoom = 1
                printedPartIDs = Set(profile.parts.map(\.id))
            }
            includeSuggestedHeader = true
            updateHeaderPreview()
            selectedPage = result.plan.pages.first(where: { !$0.unresolvedReasons.isEmpty })?.pageIndex
                ?? result.plan.pages.first?.pageIndex ?? result.analyses.first?.pageIndex ?? 0
            updatePageImage()
        }
    }

    private func updatePageImage() {
        selectedStaves.removeAll()
        focusedCropID = nil
        correctionSystem = 1
        selectionAnchor = nil
        systemFirstBar = ""
        systemBarCount = ""
        assignmentStatus = nil
        pageImage = document.scoreReviewImage(pageIndex: selectedPage)
    }

    private func toggleStaff(_ id: Int) {
        if NSEvent.modifierFlags.contains(.shift), let anchor = selectionAnchor {
            let lower = min(anchor, id), upper = max(anchor, id)
            selectedStaves.formUnion((currentAnalysis?.staves ?? []).filter { (lower...upper).contains($0.id) }.map(\.id))
        } else {
            if selectedStaves.contains(id) { selectedStaves.remove(id) } else { selectedStaves.insert(id) }
            selectionAnchor = id
        }
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
        updateHeaderPreview()
        errorMessage = nil
    }

    private func excludeCurrentPage(reason: String) {
        guard var value = review else { return }
        do {
            let next = try value.excludePageAsNonMusic(selectedPage, reason: reason)
            review = value
            updateHeaderPreview()
            errorMessage = nil
            if let next { selectedPage = next }
        } catch { errorMessage = error.localizedDescription }
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
            focusedCropID = bandID
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pageOverride(_ review: ScoreDetectionReview) -> ScorePageOverride {
        guard let page = review.analyses.first(where: { $0.pageIndex == selectedPage }) else {
            return ScorePageOverride(pageIndex: selectedPage, reason: "Instrument assignments reviewed in Auto Extract.", systems: [])
        }
        return ScoreSystemAssignment.pageOverride(page: page,
            pagePlan: review.plan.pages.first { $0.pageIndex == selectedPage },
            existingOverride: review.overrides.first { $0.pageIndex == selectedPage })
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

    private func ignoreSelected() {
        editOverride { correction in
            correction.reason = "False staff detections ignored in Auto Extract."
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
        guard let review else { return }
        let header = includeSuggestedHeader && document.headerSelection == nil ? proposedHeader : nil
        let previousBandIDs = Set(document.project.bands.map(\.id))
        guard document.addScoreParts(from: review, sourceHeader: header) != nil else {
            errorMessage = "The review is stale, incomplete, or a populated part already has one of these names. Resolve it before adding."
            return
        }
        document.setHeaderSelectionEditing(false)
        if compressRests {
            let addedBandIDs = Set(document.project.bands.map(\.id)).subtracting(previousBandIDs)
            document.autoDetectRestReplacements(bandIDs: addedBandIDs)
        }
        onClose()
    }
}

/// Small previews are made off the main thread with worker-owned PDFKit
/// objects. Full-size detection rasters never accumulate in the page picker.
private final class ScoreInputThumbnails: ObservableObject {
    @Published private(set) var images: [Int: CGImage] = [:]
    @Published private(set) var failedPages = Set<Int>()
    @Published private(set) var generation = UUID()
    private var sourceData: Data?
    private var rectifications: [PageRectification] = []
    private var requested = Set<Int>()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func configure(data: Data?, rectifications: [PageRectification]) {
        queue.cancelAllOperations()
        sourceData = data
        self.rectifications = rectifications
        requested = []
        images = [:]
        failedPages = []
        generation = UUID()
    }

    func request(_ pageIndex: Int) {
        guard !requested.contains(pageIndex), let data = sourceData else { return }
        requested.insert(pageIndex)
        let token = generation
        let rectification = rectifications.first { $0.pageIndex == pageIndex }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let image: CGImage? = autoreleasepool {
                guard let pdf = PDFDocument(data: data), let page = pdf.page(at: pageIndex) else { return nil }
                if let rectification {
                    let bounds = page.bounds(for: .mediaBox)
                    let scale = min(240 / max(bounds.width, 1), 340 / max(bounds.height, 1))
                    return SourcePageRenderCache(pdfDocument: pdf, rasterScale: scale)
                        .rectifiedDisplayImage(for: pageIndex, rectification: rectification)
                }
                return NativeScorePageAnalyzer.render(page, maximumWidth: 240, maximumHeight: 340)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, !operation.isCancelled, self.generation == token else { return }
                if let image { self.images[pageIndex] = image }
                else { self.failedPages.insert(pageIndex) }
            }
        }
        queue.addOperation(operation)
    }

    deinit { queue.cancelAllOperations() }
}
