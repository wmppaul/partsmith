import AppKit
import SwiftUI

struct InspectorView: View {
    @ObservedObject var document: PartsmithDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                rectificationSection
                projectInfoSection

                if let part = document.selectedPart {
                    partSection(part)
                } else {
                    placeholderSection(
                        title: "No Part Selected",
                        body: "Select a part in the sidebar to change its preview settings and band assignments."
                    )
                }

                if let selectedBand = document.selectedBand {
                    selectedBandSection(selectedBand)
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var headerSection: some View {
        inspectorCard(title: "Header") {
            Picker(
                "Header Source",
                selection: Binding(
                    get: { document.project.projectSettings.headerDisplayMode },
                    set: { document.updateProjectHeaderDisplayMode($0) }
                )
            ) {
                ForEach([HeaderDisplayMode.sourceSelection, .typed]) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Choose whether each part uses a copied score header or typed title and subtitle text.")

            if document.project.projectSettings.headerDisplayMode == .typed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Title")
                    TextField(
                        "Shown when part title override is empty",
                        text: Binding(
                            get: { document.project.projectSettings.defaultTitleText },
                            set: { document.updateProjectTitleText($0) }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Subtitle")
                    TextField(
                        "Shown when part subtitle override is empty",
                        text: Binding(
                            get: { document.project.projectSettings.defaultComposerText },
                            set: { document.updateProjectComposerText($0) }
                        )
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let headerSelection = document.headerSelection {
                        inspectorRow(label: "Page", value: "\(headerSelection.pageIndex + 1)")
                    } else {
                        Text("No source header selected yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Click Edit to choose the score header copied onto the first page of every part.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("After clicking Edit, drag the header box or its corners on the source page. Click Save here or click elsewhere when finished.")

                    HStack {
                        Button(document.isEditingHeaderSelection ? "Save" : "Edit") {
                            document.setHeaderSelectionEditing(document.isEditingHeaderSelection == false)
                        }
                        .disabled(document.pdfDocument == nil)
                        .help(
                            document.isEditingHeaderSelection
                                ? "Save the current header selection."
                                : "Enter header editing and drag a box around the score header."
                        )

                        Button("Clear", role: .destructive) {
                            document.clearHeaderSelection()
                        }
                        .disabled(document.headerSelection == nil)
                    }

                    if document.isEditingHeaderSelection {
                        Text("Drag the header box on the page, then click Save.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            Toggle(
                "Show Title Block",
                isOn: Binding(
                    get: { document.project.projectSettings.showTitleBlock },
                    set: { document.updateProjectShowTitleBlock($0) }
                )
            )

            Toggle(
                "Show Part Name In Header",
                isOn: Binding(
                    get: { document.project.projectSettings.showPartNameInHeader },
                    set: { document.updateProjectShowPartNameInHeader($0) }
                )
            )
        }
    }

    private var rectificationSection: some View {
        inspectorCard(title: "Rectification") {
            VStack(alignment: .leading, spacing: 8) {
                if document.isAutoEstimatingPageRectifications {
                    Text(
                        "Auto-rectifying \(document.rectificationAutoProgress?.completedPageCount ?? 0) of \(document.rectificationAutoProgress?.totalPageCount ?? 0) pages in the background."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if document.isEditingPageRectification {
                    Text("Drag the four corners on the page, then click Done.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if document.currentPageRectification != nil {
                    Text("A rectification is saved for this page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Auto All") {
                        document.autoEstimateAllPageRectifications()
                    }
                    .disabled(document.canAutoEstimateAllPageRectifications == false)
                    .help("Estimate rectification for every page in the source PDF.")

                    Button("Auto") {
                        document.autoEstimateCurrentPageRectification()
                    }
                    .disabled(document.canAutoEstimateCurrentPageRectification == false)
                    .help("Estimate rectification for the current page.")

                    Button(document.isEditingPageRectification ? "Done" : "Manual") {
                        document.setPageRectificationEditing(document.isEditingPageRectification == false)
                    }
                    .disabled(document.pdfDocument == nil || document.isAutoEstimatingPageRectifications)
                    .help(
                        document.isEditingPageRectification
                            ? "Finish manual rectification editing."
                            : "Adjust the current page rectification by dragging its four corners."
                    )

                    Button("Clear", role: .destructive) {
                        document.clearCurrentPageRectification()
                    }
                    .disabled(document.currentPageRectification == nil || document.isAutoEstimatingPageRectifications)
                    .help("Remove the saved rectification for the current page.")
                }
            }
        }
    }

    private var projectInfoSection: some View {
        inspectorCard(title: "Project Info") {
            inspectorRow(label: "Source PDF", value: document.project.sourceFilename ?? "Not imported")
            inspectorRow(label: "Pages", value: "\(document.project.pageCount)")
            inspectorRow(label: "Parts", value: "\(document.project.parts.count)")
        }
    }

    private func inspectorCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func partSection(_ part: PartModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Part")
                .font(.headline)

            TextField(
                "Part name",
                text: Binding(
                    get: { document.part(withID: part.id)?.name ?? part.name },
                    set: { document.updatePartName(part.id, name: $0) }
                )
            )

            ColorPicker(
                "Color",
                selection: Binding(
                    get: { document.part(withID: part.id)?.swiftUIColor ?? part.swiftUIColor },
                    set: { document.updatePartColor(part.id, color: NSColor($0)) }
                ),
                supportsOpacity: false
            )

            if document.project.projectSettings.headerDisplayMode == .typed {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Title Override")
                        Spacer()
                    }
                    TextField(
                        "Use project title when empty",
                        text: Binding(
                            get: { document.part(withID: part.id)?.layoutSettings.titleText ?? part.layoutSettings.titleText },
                            set: { document.updatePartTitleText(part.id, titleText: $0) }
                        )
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Subtitle Override")
                        Spacer()
                    }
                    TextField(
                        "Use project subtitle when empty",
                        text: Binding(
                            get: { document.part(withID: part.id)?.layoutSettings.composerText ?? part.layoutSettings.composerText },
                            set: { document.updatePartComposerText(part.id, composerText: $0) }
                        )
                    )
                }
            } else {
                Text("This part will use the shared source header selection instead of typed title and subtitle text.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Scale")
                    Spacer()
                    Text((document.part(withID: part.id)?.layoutSettings.scale ?? part.layoutSettings.scale).formatted(.number.precision(.fractionLength(2))))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { document.part(withID: part.id)?.layoutSettings.scale ?? part.layoutSettings.scale },
                        set: { document.updatePartScale(part.id, scale: $0) }
                    ),
                    in: 0.6...1.4,
                    step: 0.05
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("System Gap")
                    Spacer()
                    Text("\(Int(document.part(withID: part.id)?.layoutSettings.interSystemGap ?? part.layoutSettings.interSystemGap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { document.part(withID: part.id)?.layoutSettings.interSystemGap ?? part.layoutSettings.interSystemGap },
                        set: { document.updatePartGap(part.id, gap: $0) }
                    ),
                    in: 4...48,
                    step: 2
                )
            }

            bandOrderSection(part)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectedBandSection(_ band: BandModel) -> some View {
        let currentBand = document.band(withID: band.id) ?? band

        return inspectorCard(title: "Selected Band") {
            inspectorRow(label: "Page", value: "\(currentBand.pageIndex + 1)")
            inspectorRow(
                label: "Top Crop",
                value: currentBand.topFraction.formatted(.percent.precision(.fractionLength(0)))
            )
            inspectorRow(
                label: "Bottom Crop",
                value: currentBand.bottomFraction.formatted(.percent.precision(.fractionLength(0)))
            )

            Toggle(
                "Include In Output",
                isOn: Binding(
                    get: { (document.band(withID: band.id) ?? band).excluded == false },
                    set: { document.toggleBandExclusion(band.id, excluded: !$0) }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bar Number")
                    .font(.subheadline.weight(.semibold))

                Picker(
                    "Bar Number Mode",
                    selection: Binding(
                        get: { (document.band(withID: band.id) ?? band).barNumberMode },
                        set: { document.updateBandBarNumberMode(band.id, mode: $0) }
                    )
                ) {
                    ForEach(BarNumberMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch currentBand.barNumberMode {
                case .automatic:
                    Text(automaticBarNumberDescription(for: currentBand))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Refresh Auto Detection") {
                        document.refreshBarNumber(for: band.id)
                    }
                    .disabled(document.pdfDocument == nil)
                case .manual:
                    HStack {
                        Text("Value")
                            .foregroundStyle(.secondary)

                        TextField(
                            "Bar number",
                            value: manualBarNumberBinding(for: band.id),
                            format: .number
                        )
                        .frame(width: 90)
                    }

                    Text("Manual values are re-engraved in preview and export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .hidden:
                    Text("This band will not show a bar-number badge on the source pane or in exported output.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button("Delete Band", role: .destructive) {
                document.deleteBand(band.id)
            }
        }
    }

    private func bandOrderSection(_ part: PartModel) -> some View {
        let outputBands = document.outputBands(for: part.id)
        let excludedCount = document.project.sortedBands(for: part.id).count - outputBands.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Output Order")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Refresh Auto") {
                    document.refreshAutomaticBarNumbers(for: part.id)
                }
                .disabled(outputBands.isEmpty || document.pdfDocument == nil)
            }

            Text("Bands now follow score order within the part. Click a row to jump to that band on the source page.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if outputBands.isEmpty {
                Text(excludedCount > 0 ? "All bands for this part are currently excluded." : "No included bands yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(outputBands.enumerated()), id: \.element.id) { index, band in
                        bandOrderRow(band, position: index + 1)
                    }
                }
            }

            if excludedCount > 0 {
                Text("\(excludedCount) excluded band\(excludedCount == 1 ? "" : "s") omitted from output order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bandOrderRow(_ band: BandModel, position: Int) -> some View {
        let isSelected = document.selectedBandID == band.id

        return Button {
            document.revealBand(band.id)
        } label: {
            HStack(spacing: 12) {
                Text("\(position)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Page \(band.pageIndex + 1)")
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(bandPositionDescription(for: band))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "scope")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func bandPositionDescription(for band: BandModel) -> String {
        let normalizedBand = band.normalized()
        let topPercent = Int((normalizedBand.topFraction * 100).rounded())
        let bottomPercent = Int((normalizedBand.bottomFraction * 100).rounded())
        let barDescription: String
        if let barNumber = band.displayedBarNumber {
            barDescription = " • Bar \(barNumber)"
        } else {
            barDescription = ""
        }
        return "Top \(topPercent)% • Bottom \(bottomPercent)%\(barDescription)"
    }

    private func manualBarNumberBinding(for bandID: UUID) -> Binding<Int> {
        Binding(
            get: { document.band(withID: bandID)?.barNumberValue ?? 1 },
            set: { document.updateBandBarNumberValue(bandID, value: $0) }
        )
    }

    private func automaticBarNumberDescription(for band: BandModel) -> String {
        guard let value = band.barNumberValue else {
            return "No system-start number found yet for this band. You can refresh detection or switch to Manual."
        }

        let method = band.barNumberDetectionMethod?.title ?? "Auto"
        if let confidence = band.barNumberConfidence {
            return "Detected \(value) via \(method) (\(Int((confidence * 100).rounded()))% confidence)."
        }

        return "Detected \(value) via \(method)."
    }

    private func placeholderSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func inspectorRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}
