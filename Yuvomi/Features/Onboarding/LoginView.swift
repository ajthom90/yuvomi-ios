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
                    SecureField("Paste API token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Create a token in Yuvomi web: Settings → API Tokens. Tokens are stored only in the Keychain.")
                }
            case .password:
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                } footer: {
                    Text("Uses a session cookie like the web app. Your password is not stored.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .password:
            !username.isEmpty && !password.isEmpty
        }
    }

    private func signIn() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let server = try ServerURL(raw: serverURLText)
            switch mode {
            case .token:
                try authStore.saveAPIToken(token)
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

            case .password:
                // Login without prior auth headers
                let unauth = try dependencies.makeUnauthenticatedAPI(serverRaw: server.baseURL.absoluteString)
                let login = try await unauth.login(username: username, password: password)
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
                authStore.setCurrentUser(login.user)
            }
        } catch {
            try? authStore.clearAll()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
