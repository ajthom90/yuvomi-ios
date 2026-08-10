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
        .task {
            guard !Self.didAutoOnboard else { return }
            guard let url = Self.resolveAutoURL() else { return }
            Self.didAutoOnboard = true
            serverURLText = url
            await autoAdvanceToLogin(url: url)
        }
    }

    private static var didAutoOnboard = false

    private static func resolveAutoURL() -> String? {
        if let env = ProcessInfo.processInfo.environment["YUVOMI_AUTO_URL"], !env.isEmpty {
            return env
        }
        if let flag = Array(ProcessInfo.processInfo.arguments.dropFirst()).pairedValue(for: "-YUVOMI_AUTO_URL"),
           !flag.isEmpty {
            return flag
        }
        #if DEBUG
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("YuvomiTests/LiveCredentials.local.json")
        if let data = try? Data(contentsOf: file),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let url = json["url"], !url.isEmpty {
            AuthLogger.log.info("Loaded DEBUG URL from \(file.path, privacy: .public)")
            return url
        }
        #endif
        return nil
    }

    private func autoAdvanceToLogin(url: String) async {
        do {
            let api = try dependencies.makeUnauthenticatedAPI(serverRaw: url)
            let info = try await api.fetchVersion()
            versionInfo = info
            let normalized = try ServerURL(raw: url).baseURL.absoluteString
            serverURLText = normalized
            AuthLogger.log.info("Auto-onboarding version OK for \(normalized, privacy: .public)")

            // Prefer full auto sign-in when a token is also available (DEBUG / launch args).
            if let token = LoginView.resolveAutoTokenPublic() {
                AuthLogger.log.info("Auto sign-in with token (len=\(token.count))")
                try await performTokenSignIn(serverURL: normalized, token: token)
                return
            }

            path = NavigationPath()
            path.append(OnboardingRoute.login)
            AuthLogger.log.info("Auto-onboarding advanced to login UI")
        } catch {
            AuthLogger.log.error("Auto-onboarding failed: \(String(describing: error), privacy: .public)")
            // Still show login UI so the user can recover.
            path = NavigationPath()
            path.append(OnboardingRoute.login)
        }
    }

    private func performTokenSignIn(serverURL: String, token: String) async throws {
        let store = dependencies.authStore
        let server = try ServerURL(raw: serverURL)
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        try store.saveAPIToken(token)
        let draft = ServerProfile(
            serverURL: server.baseURL.absoluteString,
            method: .apiToken,
            displayName: nil,
            username: nil,
            userId: nil
        )
        try store.persistProfile(draft)
        let api = try dependencies.makeAPI()
        let me = try await api.me()
        if let csrf = me.csrfToken {
            try store.saveCSRFToken(csrf)
        }
        try store.completeSignIn(profile: draft, user: me.user)
        AuthLogger.log.info("Auto sign-in SUCCESS as \(me.user.username, privacy: .public)")
    }
}

private extension Array where Element == String {
    func pairedValue(for flag: String) -> String? {
        guard let idx = firstIndex(of: flag), idx + 1 < count else { return nil }
        return self[idx + 1]
    }
}

private enum OnboardingRoute: Hashable {
    case server
    case login
}
