import AppKit
import SwiftUI

struct InspectorView: View {
    @ObservedObject var document: PartsmithDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                projectSection

                if let part = document.selectedPart {
                    partSection(part)
                } else {
                    placeholderSection(
                        title: "No Part Selected",
                        body: "Select a part in the sidebar to change its preview settings and band assignments."
                    )
                }

                if let band = document.selectedBand {
                    bandSection(band)
                } else {
                    placeholderSection(
                        title: "No Band Selected",
                        body: "Select a crop band on the source page to inspect it here."
                    )
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Header Block")
                Picker(
                    "Header Block",
                    selection: Binding(
                        get: { document.project.projectSettings.headerDisplayMode },
                        set: { document.updateProjectHeaderDisplayMode($0) }
                    )
                ) {
                    ForEach(HeaderDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

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
                        inspectorRow(label: "Header Page", value: "\(headerSelection.pageIndex + 1)")
                    } else {
                        Text("No source header selected yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Drag a rectangle over the score header on a source page. That engraving will be copied into the first page of every part.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(document.isEditingHeaderSelection ? "Finish Header Selection" : "Select Header On This Page") {
                            document.setHeaderSelectionEditing(document.isEditingHeaderSelection == false)
                        }
                        .disabled(document.pdfDocument == nil)

                        if document.headerSelection != nil {
                            Button("Clear Header Selection", role: .destructive) {
                                document.clearHeaderSelection()
                            }
                        }
                    }
                }
            }

            inspectorRow(label: "Source PDF", value: document.project.sourceFilename ?? "Not imported")
            inspectorRow(label: "Pages", value: "\(document.project.pageCount)")
            inspectorRow(label: "Parts", value: "\(document.project.parts.count)")
            inspectorRow(label: "Mode", value: document.canvasMode.title)
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

            Toggle(
                "Show Title Block",
                isOn: Binding(
                    get: { document.part(withID: part.id)?.layoutSettings.showTitle ?? part.layoutSettings.showTitle },
                    set: { document.updateShowTitle(part.id, showTitle: $0) }
                )
            )

            Toggle(
                "Show Part Name In Header",
                isOn: Binding(
                    get: { document.part(withID: part.id)?.layoutSettings.showPartNameLabel ?? part.layoutSettings.showPartNameLabel },
                    set: { document.updateShowPartNameLabel(part.id, showPartNameLabel: $0) }
                )
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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func bandSection(_ band: BandModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Band")
                .font(.headline)

            inspectorRow(label: "Page", value: "\(band.pageIndex + 1)")
            inspectorRow(label: "Top Crop", value: band.topFraction.formatted(.percent.precision(.fractionLength(0))))
            inspectorRow(label: "Bottom Crop", value: band.bottomFraction.formatted(.percent.precision(.fractionLength(0))))

            HStack {
                Button("Raise Top") {
                    document.nudgeBandTop(band.id, delta: -0.01)
                }
                Button("Lower Top") {
                    document.nudgeBandTop(band.id, delta: 0.01)
                }
            }

            HStack {
                Button("Raise Bottom") {
                    document.nudgeBandBottom(band.id, delta: -0.01)
                }
                Button("Lower Bottom") {
                    document.nudgeBandBottom(band.id, delta: 0.01)
                }
            }

            Toggle(
                "Include In Preview",
                isOn: Binding(
                    get: { document.selectedBand?.excluded == false },
                    set: { document.toggleBandExclusion(band.id, excluded: !$0) }
                )
            )

            Button("Delete Band", role: .destructive) {
                document.deleteBand(band.id)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
