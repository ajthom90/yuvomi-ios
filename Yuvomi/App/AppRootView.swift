import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var authStore: AuthSessionStore

    var body: some View {
        Group {
            if authStore.isAuthenticated {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.easeInOut, value: authStore.isAuthenticated)
    }
}
