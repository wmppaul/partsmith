import SwiftUI

@main
struct PartsmithApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { PartsmithDocument() }) { file in
            DocumentRootView(document: file.document)
        }
        .defaultSize(width: 1600, height: 980)
    }
}
