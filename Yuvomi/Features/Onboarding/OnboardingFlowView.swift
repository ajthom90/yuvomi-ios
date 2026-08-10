import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var path = NavigationPath()
    @State private var serverURLText = ""
    @State private var versionInfo: VersionInfo?

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView {
                path.append(OnboardingRoute.server)
            }
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .server:
                    ServerURLView(serverURLText: $serverURLText) { info in
                        versionInfo = info
                        path.append(OnboardingRoute.login)
                    }
                case .login:
                    LoginView(serverURLText: serverURLText, versionInfo: versionInfo)
                }
            }
        }
    }
}

private enum OnboardingRoute: Hashable {
    case server
    case login
}
