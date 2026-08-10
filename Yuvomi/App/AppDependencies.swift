import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let authStore: AuthSessionStore
    let cache: ResponseCache

    private var cookieSession: URLSession

    init(authStore: AuthSessionStore = AuthSessionStore()) {
        self.authStore = authStore
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.cookieSession = URLSession(configuration: config)

        if let cache = try? ResponseCache.applicationSupportCache() {
            self.cache = cache
        } else {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("YuvomiCache", isDirectory: true)
            try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            self.cache = ResponseCache(directory: tmp)
        }
    }

    func makeAPI(serverRaw: String? = nil) throws -> YuvomiAPI {
        let raw = serverRaw ?? authStore.profile?.serverURL
        guard let raw else { throw APIError.invalidURL }
        let server = try ServerURL(raw: raw)
        let client = HTTPClient(session: cookieSession, auth: authStore)
        return YuvomiAPI(client: client, server: server)
    }

    func makeUnauthenticatedAPI(serverRaw: String) throws -> YuvomiAPI {
        let server = try ServerURL(raw: serverRaw)
        let client = HTTPClient(session: cookieSession, auth: NoAuthProvider())
        return YuvomiAPI(client: client, server: server)
    }
}
