import SwiftUI

@main
struct YuvomiApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(dependencies)
                .environmentObject(dependencies.authStore)
        }
    }
}
