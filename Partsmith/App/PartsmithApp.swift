import SwiftUI

@main
struct PartsmithApp: App {
    @FocusedValue(\.documentExportCommands) private var documentExportCommands
    @FocusedValue(\.documentBandCommands) private var documentBandCommands

    var body: some Scene {
        DocumentGroup(newDocument: { PartsmithDocument() }) { file in
            DocumentRootView(document: file.document)
        }
        .defaultSize(width: 1600, height: 980)
        .commands {
            CommandGroup(after: .saveItem) {
                Divider()

                Button("Export All...") {
                    documentExportCommands?.exportAllParts()
                }
                .disabled(documentExportCommands?.canExportAllParts != true)
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Delete Selected Band") {
                    documentBandCommands?.deleteSelectedBand()
                }
                .disabled(documentBandCommands?.canDeleteSelectedBand != true)
            }
        }
    }
}
