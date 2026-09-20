import AppKit
import SwiftUI

struct InspectorView: View {
    @ObservedObject var document: PartsmithDocument
    @State private var cropExpansionPoints = 6.0

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
                    Text("Preferred System Gap")
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

            Toggle("Balance Page Fill", isOn: Binding(
                get: { document.part(withID: part.id)?.layoutSettings.balancePages ?? true },
                set: { document.updatePartBalancedPages(part.id, enabled: $0) }
            ))
            .help("Balance complete systems between explicit section breaks. Spacing may reduce to 4 points to avoid an extra page; notation keeps its scale.")

            Toggle("Use Consistent Scale", isOn: Binding(
                get: { document.part(withID: part.id)?.layoutSettings.useConsistentScale ?? true },
                set: { document.updatePartConsistentScale(part.id, enabled: $0) }
            ))
            .help("Use one scale for this part's systems, preserving relative notation sizes from the source.")

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

            VStack(alignment: .leading, spacing: 8) {
                Stepper("Extra context: \(Int(cropExpansionPoints)) pt per side",
                        value: $cropExpansionPoints, in: 1...36, step: 1)
                Button("Expand Crop", systemImage: "arrow.up.left.and.arrow.down.right") {
                    document.expandBandCrop(band.id, by: cropExpansionPoints)
                }
                .disabled(document.pdfDocument?.page(at: currentBand.pageIndex) == nil ||
                          (currentBand.topFraction == 0 && currentBand.bottomFraction == 1 &&
                           currentBand.leftFraction == 0 && currentBand.rightFraction == 0))
                .help("Move all four crop edges outward by this amount, stopping at the page edges. Repeat if more context is needed, or undo the expansion.")
                Text("Keep neighboring notation when it protects target notes. Expand, then compare the source and Preview; extra space alone does not guarantee a complete part.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !currentBand.exclusions.isEmpty {
                    Text("Whiteout areas still hide ink inside this crop. Review or delete them below to restore it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(
                "Include In Output",
                isOn: Binding(
                    get: { (document.band(withID: band.id) ?? band).excluded == false },
                    set: { document.toggleBandExclusion(band.id, excluded: !$0) }
                )
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Editorial Label").font(.subheadline.weight(.semibold))
                TextField("Optional direction or source reference", text: Binding(
                    get: { (document.band(withID: band.id) ?? band).editorialLabel },
                    set: { document.updateBandEditorialLabel(band.id, label: $0) }
                ), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                Text("Printed above this band. Long labels wrap to keep every word.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Start on New Page", isOn: Binding(
                    get: { (document.band(withID: band.id) ?? band).pageBreakBefore },
                    set: { document.updateBandPageBreakBefore(band.id, pageBreakBefore: $0) }
                ))
            }

            Divider()

            bandExclusionsSection(currentBand)

            if !currentBand.sourceMarkings.isEmpty {
                Divider()
                Text("Shared Score Markings").font(.subheadline.weight(.semibold))
                Text("Verified source fragments appear above this staff at their original horizontal positions.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(currentBand.sourceMarkings.indices, id: \.self) { index in
                    HStack {
                        Text("Marking \(index + 1)")
                        Spacer()
                        Button("Remove", role: .destructive) {
                            var markings = (document.band(withID: band.id) ?? band).sourceMarkings
                            guard markings.indices.contains(index) else { return }
                            markings.remove(at: index)
                            document.updateBandSourceMarkings(band.id, markings: markings)
                        }
                    }
                }
            }

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

    private enum ExclusionEdge: String {
        case top = "Top"
        case bottom = "Bottom"
        case left = "Left"
        case right = "Right"
    }

    private func bandExclusionsSection(_ band: BandModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Whiteout Areas")
                .font(.subheadline.weight(.semibold))
            Text("Only hide ink after checking that no target notation overlaps it. Keep neighboring notation when uncertain; deleting an area restores the source ink.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(band.exclusions.enumerated()), id: \.element.id) { index, exclusion in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Area \(index + 1)").font(.caption.weight(.semibold))
                        Spacer()
                        Button("Delete Area", systemImage: "trash", role: .destructive) {
                            let current = document.band(withID: band.id) ?? band
                            document.updateBandExclusions(band.id, exclusions: current.exclusions.filter { $0.id != exclusion.id })
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                    HStack {
                        exclusionCoordinateField(.top, band: band, exclusionID: exclusion.id)
                        exclusionCoordinateField(.bottom, band: band, exclusionID: exclusion.id)
                    }
                    HStack {
                        exclusionCoordinateField(.left, band: band, exclusionID: exclusion.id)
                        exclusionCoordinateField(.right, band: band, exclusionID: exclusion.id)
                    }
                    if !exclusion.isValid(in: band) {
                        Text("This area must fit inside the selected crop.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            if !band.exclusions.isEmpty {
                Text("Edges are page percentages, measured from the top left.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("Add Whiteout Area", systemImage: "rectangle.dashed") {
                let current = document.band(withID: band.id) ?? band
                let width = 1 - current.leftFraction - current.rightFraction
                let height = current.bottomFraction - current.topFraction
                guard width > 0, height > 0 else { return }
                let area = BandExclusion(topFraction: current.topFraction,
                                         bottomFraction: current.topFraction + height * 0.18,
                                         leftFraction: 1 - current.rightFraction - width * 0.12,
                                         rightFraction: current.rightFraction)
                document.updateBandExclusions(band.id, exclusions: current.exclusions + [area])
            }
        }
    }

    private func exclusionCoordinateField(_ edge: ExclusionEdge, band: BandModel, exclusionID: UUID) -> some View {
        HStack(spacing: 4) {
            Text(edge.rawValue).font(.caption).frame(width: 42, alignment: .leading)
            TextField(edge.rawValue, value: exclusionCoordinateBinding(edge, band: band, exclusionID: exclusionID),
                      format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospacedDigit())
            Text("%").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func exclusionCoordinateBinding(_ edge: ExclusionEdge, band: BandModel, exclusionID: UUID) -> Binding<Double> {
        Binding(
            get: {
                guard let area = (document.band(withID: band.id) ?? band).exclusions.first(where: { $0.id == exclusionID }) else { return 0 }
                switch edge {
                case .top: return area.topFraction * 100
                case .bottom: return area.bottomFraction * 100
                case .left: return area.leftFraction * 100
                case .right: return (1 - area.rightFraction) * 100
                }
            },
            set: { percent in
                guard percent.isFinite else { return }
                let current = document.band(withID: band.id) ?? band
                var areas = current.exclusions
                guard let index = areas.firstIndex(where: { $0.id == exclusionID }) else { return }
                let value = percent / 100
                let minimumSize = min(current.bottomFraction - current.topFraction,
                                      1 - current.leftFraction - current.rightFraction) * 0.001
                switch edge {
                case .top:
                    areas[index].topFraction = max(current.topFraction, min(value, areas[index].bottomFraction - minimumSize))
                case .bottom:
                    areas[index].bottomFraction = min(current.bottomFraction, max(value, areas[index].topFraction + minimumSize))
                case .left:
                    areas[index].leftFraction = max(current.leftFraction, min(value, 1 - areas[index].rightFraction - minimumSize))
                case .right:
                    areas[index].rightFraction = max(current.rightFraction, min(1 - value, 1 - areas[index].leftFraction - minimumSize))
                }
                document.updateBandExclusions(band.id, exclusions: areas)
            }
        )
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
