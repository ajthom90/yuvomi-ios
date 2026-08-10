import Foundation

@MainActor
final class AuthSessionStore: ObservableObject {
    private enum Account {
        static let profile = "profile"
        static let apiToken = "apiToken"
        static let csrfToken = "csrfToken"
    }

    private let secrets: SecretStore
    private let defaults: UserDefaults

    @Published private(set) var profile: ServerProfile?
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    init(secrets: SecretStore = ResilientSecretStore.makeDefault(), defaults: UserDefaults = .standard) {
        self.secrets = secrets
        self.defaults = defaults
        reloadFromStorage()
    }

    func reloadFromStorage() {
        if let data = try? secrets.get(account: Account.profile),
           let profile = try? JSONDecoder().decode(ServerProfile.self, from: data) {
            self.profile = profile
            // Only treat as signed-in if we still have credentials for the method.
            switch profile.method {
            case .apiToken:
                let token = (try? secrets.get(account: Account.apiToken)) ?? Data()
                isAuthenticated = !token.isEmpty
            case .session:
                isAuthenticated = true
            }
            AuthLogger.log.info(
                "Restored profile host=\(profile.serverURL, privacy: .public) method=\(profile.method.rawValue, privacy: .public) auth=\(self.isAuthenticated)"
            )
        } else {
            profile = nil
            isAuthenticated = false
        }
    }

    /// Persist profile without flipping `isAuthenticated` (used mid-login).
    func persistProfile(_ profile: ServerProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try secrets.set(data, account: Account.profile)
        self.profile = profile
        AuthLogger.log.info("Persisted profile for \(profile.serverURL, privacy: .public)")
    }

    /// Mark the session fully established (only call after `/auth/me` succeeds).
    func completeSignIn(profile: ServerProfile, user: User) throws {
        var finalized = profile
        finalized.displayName = user.displayName
        finalized.username = user.username
        finalized.userId = user.id
        try persistProfile(finalized)
        currentUser = user
        isAuthenticated = true
        AuthLogger.log.info(
            "Sign-in complete user=\(user.username, privacy: .public) id=\(user.id)"
        )
    }

    func saveAPIToken(_ token: String) throws {
        let trimmed = APITokenNormalizer.normalize(token)
        guard !trimmed.isEmpty else {
            throw APIError.validation("API token is empty after normalization.")
        }
        try secrets.set(Data(trimmed.utf8), account: Account.apiToken)
        AuthLogger.log.info("Saved API token (len=\(trimmed.count))")
    }

    func saveCSRFToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try secrets.set(Data(trimmed.utf8), account: Account.csrfToken)
    }

    func apiToken() throws -> String? {
        guard let data = try secrets.get(account: Account.apiToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func csrfToken() throws -> String? {
        guard let data = try secrets.get(account: Account.csrfToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setCurrentUser(_ user: User?) {
        currentUser = user
        if var profile, let user {
            profile.displayName = user.displayName
            profile.username = user.username
            profile.userId = user.id
            try? persistProfile(profile)
        }
    }

    func clearAll() throws {
        // Best-effort deletes — do not fail sign-out if one store is unavailable.
        try? secrets.delete(account: Account.profile)
        try? secrets.delete(account: Account.apiToken)
        try? secrets.delete(account: Account.csrfToken)
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        profile = nil
        currentUser = nil
        isAuthenticated = false
        AuthLogger.log.info("Cleared auth session")
    }
}

extension AuthSessionStore: AuthHeaderProviding {
    nonisolated func authorize(_ request: inout URLRequest) async throws {
        let method = await MainActor.run { profile?.method }
        switch method {
        case .apiToken:
            if let token = try await MainActor.run(body: { try apiToken() }), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(token, forHTTPHeaderField: "X-API-Key")
            } else {
                AuthLogger.log.error("authorize: apiToken mode but no token in keychain")
            }
        case .session:
            if let csrf = try await MainActor.run(body: { try csrfToken() }), !csrf.isEmpty {
                let httpMethod = request.httpMethod?.uppercased() ?? "GET"
                if ["POST", "PUT", "PATCH", "DELETE"].contains(httpMethod) {
                    request.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
                }
            }
        case .none:
            break
        }
    }
}
