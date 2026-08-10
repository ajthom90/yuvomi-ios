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

    init(secrets: SecretStore = KeychainStore(), defaults: UserDefaults = .standard) {
        self.secrets = secrets
        self.defaults = defaults
        reloadFromStorage()
    }

    func reloadFromStorage() {
        if let data = try? secrets.get(account: Account.profile),
           let profile = try? JSONDecoder().decode(ServerProfile.self, from: data) {
            self.profile = profile
            isAuthenticated = true
        } else {
            profile = nil
            isAuthenticated = false
        }
    }

    func saveProfile(_ profile: ServerProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try secrets.set(data, account: Account.profile)
        self.profile = profile
        isAuthenticated = true
    }

    func saveAPIToken(_ token: String) throws {
        let trimmed = APITokenNormalizer.normalize(token)
        guard !trimmed.isEmpty else { return }
        try secrets.set(Data(trimmed.utf8), account: Account.apiToken)
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
            try? saveProfile(profile)
        }
    }

    func clearAll() throws {
        try secrets.delete(account: Account.profile)
        try secrets.delete(account: Account.apiToken)
        try secrets.delete(account: Account.csrfToken)
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        profile = nil
        currentUser = nil
        isAuthenticated = false
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
