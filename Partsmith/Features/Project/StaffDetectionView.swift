import AppKit
import SwiftUI

struct StaffDetectionView: View {
    @ObservedObject var document: PartsmithDocument
    @Environment(\.dismiss) private var dismiss
    @State private var review: StaffDetectionPage?
    @State private var isDetecting = true
    @State private var selectedIDs = Set<Int>()
    @State private var partID: UUID?
    @State private var stavesPerBand = 1
    @State private var stavesPerSystem = 4
    @State private var firstStaff = 1
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find Staves — Page \(document.currentPageIndex + 1)")
                        .font(.title2.weight(.semibold))
                    Text("Runs locally. Review the whole page before adding bands.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDetecting { ProgressView().controlSize(.small) }
                if review != nil { Button("Find Again", action: runDetection) }
            }

            if let review {
                HSplitView {
                    pagePreview(review)
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                    selectionControls(review)
                        .frame(minWidth: 340, idealWidth: 370, maxWidth: 400)
                }
                Text("Suggested crop edges can omit target notation. Check ledger notes, slurs, dynamics, lyrics, and shared tempo or rehearsal markings. After adding, use Expand Crop in the Inspector to keep more context, including neighboring notation when needed. Missed staves and changing instrument order require manual review. Existing overlapping bands are skipped.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 12) {
                    if isDetecting {
                        Text("Looking for five-line staves…")
                        Text("Using the page’s current rectification.").foregroundStyle(.secondary)
                    } else {
                        Text(errorMessage ?? "This page could not be analyzed.")
                        Button("Try Again", action: runDetection)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if review != nil, let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }
            Divider()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if let groups = selectedGroups, !groups.isEmpty {
                    Text("\(groups.count) band\(groups.count == 1 ? "" : "s") selected")
                        .foregroundStyle(.secondary)
                }
                Button("Add Reviewed Bands", action: addBands)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(review == nil || selectedGroups?.isEmpty != false || partID == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 940, idealWidth: 1050, minHeight: 700, idealHeight: 800)
        .onAppear {
            partID = document.selectedPartID ?? document.project.parts.first?.id
            runDetection()
        }
        .onDisappear { document.cancelStaffDetection() }
    }

    private func pagePreview(_ review: StaffDetectionPage) -> some View {
        GeometryReader { geometry in
            let aspect = CGFloat(review.image.width) / CGFloat(review.image.height)
            let width = min(geometry.size.width, geometry.size.height * aspect)
            let height = width / aspect
            ZStack(alignment: .topLeading) {
                Image(decorative: review.image, scale: 1)
                    .resizable()
                    .frame(width: width, height: height)
                ForEach(review.result.candidates) { candidate in
                    let selected = selectedIDs.contains(candidate.id)
                    Button { toggle(candidate.id) } label: {
                        Rectangle()
                            .fill(selected ? Color.accentColor.opacity(0.22) : Color.green.opacity(0.08))
                            .overlay(Rectangle().stroke(selected ? Color.accentColor : .green, lineWidth: selected ? 2 : 1))
                            .overlay(alignment: .topLeading) {
                                Text("\(candidate.id + 1)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 4)
                                    .background(selected ? Color.accentColor : Color.green)
                                    .foregroundStyle(.white)
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: width, height: height * (candidate.bottomFraction - candidate.topFraction))
                    .offset(y: height * candidate.topFraction)
                    .accessibilityLabel("Staff \(candidate.id + 1), \(selected ? "selected" : "not selected")")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipped()
    }

    private func selectionControls(_ review: StaffDetectionPage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Add to part", selection: $partID) {
                ForEach(document.project.parts) { part in
                    Text(part.name).tag(Optional(part.id))
                }
            }
            Text("\(review.result.candidates.count) staff proposals")
                .font(.headline)
            Text("Select the staves belonging to this part. These positions do not identify instruments.")
                .font(.callout).foregroundStyle(.secondary)

            Stepper("Staves per band: \(stavesPerBand)", value: $stavesPerBand, in: 1...4)
            Text("Use 2 for a piano grand staff. Each band must contain consecutive selected staves.")
                .font(.caption).foregroundStyle(.secondary)

            DisclosureGroup("Repeated staff order on this page") {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper("Staves per system: \(stavesPerSystem)", value: $stavesPerSystem, in: 1...32)
                    Stepper("First staff in each system: \(firstStaff)", value: $firstStaff, in: 1...32)
                    Text("Use only after checking that every system has the same staff order and all staves were found.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Select Repeated Staves") { selectRepeated(review) }
                        .disabled(!canSelectRepeated(review))
                    if !canSelectRepeated(review) {
                        Text("The detected count must divide evenly into systems, and the selected group must fit within each system.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top, 8)
            }

            HStack {
                Button("Select All") { selectedIDs = Set(review.result.candidates.map(\.id)) }
                Button("Clear") { selectedIDs.removeAll() }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(review.result.candidates) { candidate in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(candidate.id) },
                            set: { if $0 { selectedIDs.insert(candidate.id) } else { selectedIDs.remove(candidate.id) } }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Staff \(candidate.id + 1) · \(Int(candidate.confidence * 100))% line confidence")
                                    .font(.callout)
                                if !candidate.warnings.isEmpty {
                                    Text(candidate.warnings.joined(separator: " "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedIDs.contains(candidate.id) ? Color.accentColor.opacity(0.08) : .clear)
                    }
                }
            }
            if review.result.candidates.isEmpty {
                Text(review.result.warnings.joined(separator: " "))
                    .font(.callout).foregroundStyle(.secondary)
            } else if !selectedIDs.isEmpty && selectedGroups == nil {
                Text("Select consecutive groups of \(stavesPerBand) staves, or change staves per band.")
                    .font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(.leading, 12)
    }

    private var selectedGroups: [[Int]]? {
        let ids = selectedIDs.sorted()
        guard ids.count.isMultiple(of: stavesPerBand) else { return nil }
        var groups: [[Int]] = []
        for start in stride(from: 0, to: ids.count, by: stavesPerBand) {
            let group = Array(ids[start..<(start + stavesPerBand)])
            guard zip(group, group.dropFirst()).allSatisfy({ $1 == $0 + 1 }) else { return nil }
            groups.append(group)
        }
        return groups
    }

    private func canSelectRepeated(_ review: StaffDetectionPage) -> Bool {
        let count = review.result.candidates.count
        return count > 0 && count.isMultiple(of: stavesPerSystem)
            && firstStaff + stavesPerBand - 1 <= stavesPerSystem
    }

    private func selectRepeated(_ review: StaffDetectionPage) {
        guard canSelectRepeated(review) else { return }
        selectedIDs = Set(stride(from: 0, to: review.result.candidates.count, by: stavesPerSystem).flatMap { start in
            (0..<stavesPerBand).map { start + firstStaff - 1 + $0 }
        })
    }

    private func toggle(_ id: Int) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func runDetection() {
        isDetecting = true
        errorMessage = nil
        selectedIDs.removeAll()
        review = nil
        document.detectStaffBands { result in
            isDetecting = false
            review = result
            if result == nil { errorMessage = "The page changed or could not be rendered. Run detection again." }
        }
    }

    private func addBands() {
        guard let review, let groups = selectedGroups, let partID else { return }
        guard let count = document.addStaffBands(from: review, groups: groups, partID: partID) else {
            errorMessage = "The source page or rectification changed. Run detection again before applying these proposals."
            return
        }
        if count == 0 {
            errorMessage = "These staves already overlap bands for this part. Review the existing bands in the source view."
            return
        }
        dismiss()
    }
}
