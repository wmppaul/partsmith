import AppKit
import SwiftUI

struct PartsSidebarView: View {
    @ObservedObject var document: PartsmithDocument
    var onNewPartRequested: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                if document.project.parts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No parts yet")
                            .foregroundStyle(.secondary)
                        Text("Create a part before placing crop bands.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                ForEach(document.project.parts) { part in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(part.swiftUIColor)
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.body.weight(.medium))
                            Text("\(document.bandCount(for: part.id)) bands")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .tag(part.id)
                    .contextMenu {
                        Button("Delete Part", role: .destructive) {
                            document.deletePart(part.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button("New Part", systemImage: "plus") {
                    onNewPartRequested()
                }

                Spacer()

                if let selectedPartID = document.selectedPartID {
                    Button(role: .destructive) {
                        document.deletePart(selectedPartID)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 240)
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { document.selectedPartID },
            set: { document.selectPart($0) }
        )
    }
}

struct AddPartSheet: View {
    @ObservedObject var document: PartsmithDocument
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var color: Color

    init(document: PartsmithDocument, isPresented: Binding<Bool>) {
        self.document = document
        self._isPresented = isPresented
        self._color = State(initialValue: Color(nsColor: document.suggestedNewPartColor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Part")
                .font(.title3.weight(.semibold))

            TextField("Part name", text: $name)

            ColorPicker("Color", selection: $color, supportsOpacity: false)

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Create") {
                    document.createPart(name: name, color: NSColor(color))
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
