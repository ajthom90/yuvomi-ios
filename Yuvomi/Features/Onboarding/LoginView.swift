import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var authStore: AuthSessionStore

    let serverURLText: String
    let versionInfo: VersionInfo?

    enum Mode: String, CaseIterable, Identifiable {
        case token = "API token"
        case password = "Password"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .token
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case token, username, password
    }

    var body: some View {
        Form {
            if let versionInfo {
                Section {
                    LabeledContent("Server", value: versionInfo.appName)
                    if let version = versionInfo.version {
                        LabeledContent("Version", value: version)
                    }
                }
            }

            Section {
                Picker("Sign in with", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            switch mode {
            case .token:
                Section {
                    TextField("yuvomi_…", text: $token, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .token)
                        .textContentType(.password)
                        .accessibilityIdentifier("login.token")
                } footer: {
                    Text("In the Yuvomi web app: Settings → API Tokens → create a token with full access (leave scopes empty). Copy the token once and paste it here. Prefer this over password on iOS.")
                }
            case .password:
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($focusedField, equals: .username)
                        .accessibilityIdentifier("login.username")
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .accessibilityIdentifier("login.password")
                        .onSubmit { Task { await signIn() } }
                } footer: {
                    Text("Uses a browser-style session cookie. If this fails on your network, use an API token instead.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("login.error")
                }
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isWorking {
                    ProgressView()
                } else {
                    Button("Sign in") { Task { await signIn() } }
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("login.submit")
                }
            }
        }
        .task(id: serverURLText) {
            guard !serverURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            guard !Self.didAutoSignIn else { return }
            guard let auto = Self.resolveAutoToken() else { return }
            Self.didAutoSignIn = true
            AuthLogger.log.info("Auto token present (len=\(auto.count)); signing in")
            token = auto
            mode = .token
            await signIn()
        }
    }

    private static var didAutoSignIn = false

    /// Shared with OnboardingFlowView for full auto sign-in.
    static func resolveAutoTokenPublic() -> String? { resolveAutoToken() }

    private static func resolveAutoToken() -> String? {
        let args = ProcessInfo.processInfo.arguments
        AuthLogger.log.info("Launch args count=\(args.count)")
        if let env = ProcessInfo.processInfo.environment["YUVOMI_AUTO_TOKEN"], !env.isEmpty {
            return env
        }
        if let flag = Array(args.dropFirst()).pairedValue(for: "-YUVOMI_AUTO_TOKEN"), !flag.isEmpty {
            return flag
        }
        return nil
    }

    private var canSubmit: Bool {
        switch mode {
        case .token:
            !APITokenNormalizer.normalize(token).isEmpty
        case .password:
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        }
    }

    private func signIn() async {
        focusedField = nil
        try? await Task.sleep(for: .milliseconds(50))

        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        AuthLogger.log.info("Sign-in started mode=\(mode.rawValue, privacy: .public) server=\(serverURLText, privacy: .public)")

        do {
            let server = try ServerURL(raw: serverURLText)
            switch mode {
            case .token:
                try await signInWithToken(server: server)
            case .password:
                try await signInWithPassword(server: server)
            }
        } catch {
            AuthLogger.log.error("Sign-in failed: \(String(describing: error), privacy: .public)")
            try? authStore.clearAll()
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func signInWithToken(server: ServerURL) async throws {
        let normalized = APITokenNormalizer.normalize(token)
        guard !normalized.isEmpty else {
            throw APIError.validation("Paste an API token from Yuvomi Settings → API Tokens.")
        }

        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        // Persist secrets first; only flip isAuthenticated after /auth/me succeeds.
        try authStore.saveAPIToken(normalized)
        let draft = ServerProfile(
            serverURL: server.baseURL.absoluteString,
            method: .apiToken,
            displayName: nil,
            username: nil,
            userId: nil
        )
        try authStore.persistProfile(draft)

        AuthLogger.log.info("Calling /auth/me with API token")
        let api = try dependencies.makeAPI()
        let me = try await api.me()
        if let csrf = me.csrfToken {
            try authStore.saveCSRFToken(csrf)
        }
        try authStore.completeSignIn(profile: draft, user: me.user)
    }

    private func signInWithPassword(server: ServerURL) async throws {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else {
            throw APIError.validation("Enter username and password.")
        }

        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        let unauth = try dependencies.makeUnauthenticatedAPI(serverRaw: server.baseURL.absoluteString)
        AuthLogger.log.info("Calling /auth/login")
        let login = try await unauth.login(username: user, password: password)
        if let csrf = login.csrfToken {
            try authStore.saveCSRFToken(csrf)
        }
        let draft = ServerProfile(
            serverURL: server.baseURL.absoluteString,
            method: .session,
            displayName: login.user.displayName,
            username: login.user.username,
            userId: login.user.id
        )
        try authStore.persistProfile(draft)

        let api = try dependencies.makeAPI()
        do {
            AuthLogger.log.info("Verifying session via /auth/me")
            let me = try await api.me()
            if let csrf = me.csrfToken {
                try authStore.saveCSRFToken(csrf)
            }
            try authStore.completeSignIn(profile: draft, user: me.user)
        } catch {
            try? authStore.clearAll()
            throw APIError.validation(
                "Password was accepted, but the session cookie did not stick (common with some reverse proxies). Create an API token in the web app (Settings → API Tokens, full access) and sign in with that instead. Underlying: \(friendlyMessage(for: error))"
            )
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let api = error as? APIError, let description = api.errorDescription {
            return description
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(describing: error)
    }
}

private extension Array where Element == String {
    func pairedValue(for flag: String) -> String? {
        guard let idx = firstIndex(of: flag), idx + 1 < count else { return nil }
        return self[idx + 1]
    }
}
