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
                    // TextField (not SecureField): long tokens paste more reliably.
                    TextField("yuvomi_…", text: $token, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .token)
                        .textContentType(.password)
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
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
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
                }
            }
        }
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
        // Commit SecureField / TextField bindings (last character can be lost while focused).
        focusedField = nil
        try? await Task.sleep(for: .milliseconds(50))

        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let server = try ServerURL(raw: serverURLText)
            switch mode {
            case .token:
                try await signInWithToken(server: server)
            case .password:
                try await signInWithPassword(server: server)
            }
        } catch {
            try? authStore.clearAll()
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func signInWithToken(server: ServerURL) async throws {
        let normalized = APITokenNormalizer.normalize(token)
        guard !normalized.isEmpty else {
            throw APIError.validation("Paste an API token from Yuvomi Settings → API Tokens.")
        }
        // Clear any stale session cookies so they cannot shadow Bearer auth.
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        try authStore.saveAPIToken(normalized)
        try authStore.saveProfile(
            ServerProfile(
                serverURL: server.baseURL.absoluteString,
                method: .apiToken,
                displayName: nil,
                username: nil,
                userId: nil
            )
        )

        let api = try dependencies.makeAPI()
        let me = try await api.me()
        if let csrf = me.csrfToken {
            try authStore.saveCSRFToken(csrf)
        }
        authStore.setCurrentUser(me.user)
    }

    private func signInWithPassword(server: ServerURL) async throws {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else {
            throw APIError.validation("Enter username and password.")
        }

        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        let unauth = try dependencies.makeUnauthenticatedAPI(serverRaw: server.baseURL.absoluteString)
        let login = try await unauth.login(username: user, password: password)
        if let csrf = login.csrfToken {
            try authStore.saveCSRFToken(csrf)
        }
        try authStore.saveProfile(
            ServerProfile(
                serverURL: server.baseURL.absoluteString,
                method: .session,
                displayName: login.user.displayName,
                username: login.user.username,
                userId: login.user.id
            )
        )

        // Session cookies must round-trip before we consider login complete.
        // Native apps sometimes fail SameSite/Secure cookie storage on self-hosted hosts.
        let api = try dependencies.makeAPI()
        do {
            let me = try await api.me()
            if let csrf = me.csrfToken {
                try authStore.saveCSRFToken(csrf)
            }
            authStore.setCurrentUser(me.user)
        } catch {
            try? authStore.clearAll()
            throw APIError.validation(
                "Password was accepted, but the session cookie did not stick (common with some reverse proxies). Create an API token in the web app (Settings → API Tokens, full access) and sign in with that instead."
            )
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let api = error as? APIError, let description = api.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
