import SwiftUI

@main
struct PartsmithApp: App {
    @FocusedValue(\.documentExportCommands) private var documentExportCommands

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
        }
    }
}
