import AppKit
import PDFKit
import SwiftUI

/// Reuse an explicitly assigned instrument layout, with every proposed source
/// system still accessible on the enlarged score before applying the selection.
struct ScoreSystemTemplatePanel: View {
    @Binding var review: ScoreDetectionReview?
    var onReveal: (ScoreSystemTemplateMatcher.Suggestion) -> Void
    var onApplied: (Int) -> Void

    @State private var expanded = true
    @State private var result: ScoreSystemTemplateMatcher.Result?
    @State private var snapshot: ScoreDetectionReview?
    @State private var selected = Set<String>()
    @State private var counts: [String: String] = [:]
    @State private var starts: [String: String] = [:]
    @State private var status: String?
    @State private var error: String?
    @State private var worker: Task<ScoreSystemTemplateMatcher.Result, Never>?
    @State private var applyWorker: Task<ScoreDetectionReview, Error>?
    @State private var isApplying = false
    @State private var runID: UUID?

    private var suggestions: [ScoreSystemTemplateMatcher.Suggestion] { result?.suggestions ?? [] }
    private var selectedSuggestions: [ScoreSystemTemplateMatcher.Suggestion] {
        suggestions.filter { selected.contains($0.id) }
    }
    private var readyToApply: Bool {
        !selectedSuggestions.isEmpty && selectedSuggestions.allSatisfy {
            validNumber(starts[$0.id] ?? "", required: false, maximum: Int.max) &&
                validNumber(counts[$0.id] ?? "", required: $0.requiresMeasureCount, maximum: 999)
        }
    }
    private var hasTemplate: Bool {
        review?.overrides.contains { $0.nonMusicReason == nil && $0.systems.contains {
            !$0.bands.isEmpty && $0.requiresAssignmentReview != true
        }} == true
    }

    var body: some View {
        DisclosureGroup("Reuse Assigned Layouts", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Assign one example of each printed layout, then find similar systems throughout the selected pages.")
                    .font(.caption).foregroundStyle(.secondary)
                if runID != nil {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(isApplying ? "Assigning layouts…" : "Comparing printed layouts…").font(.caption)
                        Spacer()
                        Button("Stop", action: cancel).controlSize(.small)
                    }
                } else {
                    Button("Find Similar Systems", systemImage: "wand.and.stars", action: findMatches)
                        .disabled(!hasTemplate)
                }
                if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                if !suggestions.isEmpty {
                    Text("Select the layouts to reuse. Show highlights the proposed staves on the score.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Select Matches") {
                            selected = Set(suggestions.filter { $0.confidence == .sourceSupported }.map(\.id))
                        }
                        Button("Clear") { selected.removeAll() }
                    }.controlSize(.small).disabled(isApplying)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 7) {
                            ForEach(suggestions) { suggestion in suggestionRow(suggestion) }
                        }
                    }.frame(maxHeight: 320).disabled(isApplying)
                    Button("Use Selected Layouts", action: apply)
                        .buttonStyle(.borderedProminent).disabled(!readyToApply || runID != nil)
                    if selectedSuggestions.contains(where: { $0.requiresMeasureCount && !validNumber(counts[$0.id] ?? "", required: true, maximum: 999) }) {
                        Text("Enter each selected system’s bar count so absent instruments keep the correct amount of rest.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let diagnostics = result?.diagnostics, !diagnostics.isEmpty {
                    DisclosureGroup("Matching details") {
                        ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, item in
                            Text(item.pageIndex < 0 ? item.message : "Page \(item.pageIndex + 1): \(item.message)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(.top, 7)
        }
        .onDisappear(perform: cancel)
        .onChange(of: review?.overrides) { invalidateMatches() }
        .onChange(of: review?.excludedPageReasons) { invalidateMatches() }
        .onChange(of: review?.profile) { invalidateMatches() }
        .onChange(of: review?.sourcePDFData) { invalidateMatches() }
        .onChange(of: review?.rectifications) { invalidateMatches() }
    }

    private func suggestionRow(_ suggestion: ScoreSystemTemplateMatcher.Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Toggle(isOn: Binding(get: { selected.contains(suggestion.id) }, set: { checked in
                    if checked {
                        // Competing templates for one physical system are alternatives.
                        for other in suggestions where other.pageIndex == suggestion.pageIndex && other.systemIndex == suggestion.systemIndex {
                            selected.remove(other.id)
                        }
                        selected.insert(suggestion.id)
                    } else { selected.remove(suggestion.id) }
                })) {
                    Text("Page \(suggestion.pageIndex + 1) · System \(suggestion.systemIndex + 1)")
                        .font(.caption.bold())
                }.toggleStyle(.checkbox)
                Spacer(minLength: 3)
                Button("Show") { onReveal(suggestion) }.controlSize(.small)
            }
            Text((review?.profile.parts ?? []).filter { suggestion.presentPartIDs.contains($0.id) }.map { part in
                let count = suggestion.staffCounts[part.id] ?? part.staffCount
                return "\(part.name) (\(count) \(count == 1 ? "staff" : "staves"))"
            }.joined(separator: ", "))
                .font(.caption)
            Text("Uses page \(suggestion.templatePageIndex + 1), system \(suggestion.templateSystemIndex + 1)")
                .font(.caption2).foregroundStyle(.secondary)
            if suggestion.confidence == .needsReview {
                Text(suggestion.reasons.joined(separator: " ")).font(.caption2).foregroundStyle(.orange)
            }
            if selected.contains(suggestion.id) && suggestion.requiresMeasureCount {
                HStack {
                    TextField("First bar (optional)", text: textBinding(suggestion.id, in: $starts))
                    TextField("Bars", text: textBinding(suggestion.id, in: $counts)).frame(width: 60)
                }.textFieldStyle(.roundedBorder).font(.caption)
                Text("Absent instruments receive counted rests.").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }

    private func textBinding(_ id: String, in values: Binding<[String: String]>) -> Binding<String> {
        Binding(get: { values.wrappedValue[id] ?? "" }, set: { values.wrappedValue[id] = $0 })
    }

    private func validNumber(_ value: String, required: Bool, maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return !required }
        return Int(trimmed).map { $0 > 0 && $0 <= maximum } ?? false
    }

    private func stillMatches(_ before: ScoreDetectionReview, _ after: ScoreDetectionReview) -> Bool {
        before.profile == after.profile && before.sourcePDFData == after.sourcePDFData &&
            before.rectifications == after.rectifications && before.analyses == after.analyses &&
            before.overrides == after.overrides && before.selectedPageIndices == after.selectedPageIndices &&
            before.excludedPageReasons == after.excludedPageReasons
    }

    private func findMatches() {
        guard let captured = review, hasTemplate else { return }
        cancel()
        result = nil; selected.removeAll(); counts.removeAll(); starts.removeAll()
        error = nil; status = nil; snapshot = captured
        let id = UUID()
        runID = id
        let task = Task.detached(priority: .userInitiated) {
            guard let pdf = PDFDocument(data: captured.sourcePDFData) else {
                return ScoreSystemTemplateMatcher.Result(suggestions: [], diagnostics: [], cancelled: false)
            }
            let pages = captured.analyses.filter {
                captured.excludedPageReasons[$0.pageIndex] == nil && captured.selectedPageIndices?.contains($0.pageIndex) != false
            }
            return ScoreSystemTemplateMatcher.suggest(pages: pages, profile: captured.profile,
                reviewedOverrides: captured.overrides, imageForPage: { index in
                    guard !Task.isCancelled, let page = pdf.page(at: index) else { return nil }
                    return autoreleasepool {
                        if let rectification = captured.rectifications.first(where: { $0.pageIndex == index }) {
                            // A failed corrected raster must not fall back to raw coordinates.
                            // Match detectScore's corrected analysis raster exactly.
                            return SourcePageRenderCache(pdfDocument: pdf, rasterScale: 2.5)
                                .rectifiedDisplayImage(for: index, rectification: rectification)
                        }
                        return NativeScorePageAnalyzer.render(page)
                    }
                }, isCancelled: { Task.isCancelled })
        }
        worker = task
        Task { @MainActor in
            let found = await task.value
            guard runID == id else { return }
            runID = nil; worker = nil
            guard !found.cancelled, let current = review, stillMatches(captured, current) else {
                status = "The setup changed. Find matching systems again."
                return
            }
            result = found
            selected = Set(found.suggestions.filter { $0.confidence == .sourceSupported && !$0.requiresMeasureCount }.map(\.id))
            let count = Set(found.suggestions.map { "\($0.pageIndex):\($0.systemIndex)" }).count
            status = count == 0 ? "No unassigned systems matched these examples. Assign another printed layout to add an example." : "Found \(count) systems with similar printed layouts."
        }
    }

    private func apply() {
        guard let before = snapshot, let current = review, stillMatches(before, current) else {
            invalidateMatches()
            error = "Assignments or source pages changed. Find matching systems again."
            return
        }
        let choices = selectedSuggestions.map {
            ScoreSystemAssignmentChoice(pageIndex: $0.pageIndex, systemIndex: $0.systemIndex,
                candidateIDs: $0.candidateIDs, presentPartIDs: $0.presentPartIDs,
                startBarNumber: Int((starts[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
                barCount: Int((counts[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
                staffCounts: $0.staffCounts)
        }
        let id = UUID()
        runID = id; isApplying = true; error = nil
        let task = Task.detached(priority: .userInitiated) {
            try ScoreSystemAssignmentBatch.applying(choices, to: current, isCancelled: { Task.isCancelled })
        }
        applyWorker = task
        Task { @MainActor in
            do {
                let updated = try await task.value
                guard runID == id else { return }
                runID = nil; applyWorker = nil; isApplying = false
                guard let latest = review, stillMatches(current, latest) else {
                    invalidateMatches()
                    error = "Assignments changed while applying. Find matching systems again."
                    return
                }
                result = nil; snapshot = nil; selected.removeAll()
                review = updated
                status = "Assigned \(choices.count) systems."
                onApplied(choices.count)
            } catch {
                guard runID == id else { return }
                runID = nil; applyWorker = nil; isApplying = false
                self.error = error.localizedDescription
            }
        }
    }

    private func cancel() {
        worker?.cancel(); applyWorker?.cancel()
        worker = nil; applyWorker = nil; runID = nil; isApplying = false
    }

    private func invalidateMatches() {
        let hadResults = result != nil || runID != nil
        cancel()
        result = nil; snapshot = nil; selected.removeAll()
        if hadResults { status = "Assignments changed. Find matching systems again." }
    }
}
