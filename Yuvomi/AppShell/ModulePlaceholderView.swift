import SwiftUI

struct ModulePlaceholderView: View {
    let module: ModuleKind

    var body: some View {
        ContentUnavailableView {
            Label(module.title, systemImage: module.systemImage)
                .foregroundStyle(module.accent)
        } description: {
            Text("Native \(module.title) is planned for Phase \(module.phase). The app shell is ready — this module will use the same server connection.")
        } actions: {
            if module == .settings {
                EmptyView()
            }
        }
        .navigationTitle(module.title)
    }
}
