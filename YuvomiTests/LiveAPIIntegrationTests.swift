import XCTest
@testable import Yuvomi

/// Opt-in live tests. Never hardcode secrets in this file.
///
/// Create gitignored `YuvomiTests/LiveCredentials.local.json`:
///   { "url": "https://…", "token": "yuvomi_…" }
/// Simulator can read that host path via `#filePath`.
@MainActor
final class LiveAPIIntegrationTests: XCTestCase {
    private struct LiveCreds: Decodable {
        let url: String
        let token: String
    }

    private var creds: LiveCreds?

    private var urlString: String? { creds?.url }
    private var token: String? { creds?.token }

    override func setUp() async throws {
        try await super.setUp()
        creds = Self.loadCredentials()
        try XCTSkipIf(
            urlString?.isEmpty != false || token?.isEmpty != false,
            "Add YuvomiTests/LiveCredentials.local.json (gitignored) to run live tests"
        )
    }

    private static func loadCredentials() -> LiveCreds? {
        let env = ProcessInfo.processInfo.environment
        if let url = env["YUVOMI_URL"], let token = env["YUVOMI_TOKEN"],
           !url.isEmpty, !token.isEmpty {
            return LiveCreds(url: url, token: token)
        }
        // Source-adjacent file (readable by Simulator on the host path).
        let local = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("LiveCredentials.local.json")
        for path in [local, URL(fileURLWithPath: "/tmp/yuvomi-ios-live.json")] {
            if let data = try? Data(contentsOf: path),
               let decoded = try? JSONDecoder().decode(LiveCreds.self, from: data) {
                return decoded
            }
        }
        return nil
    }

    func testVersionUnauthenticated() async throws {
        let server = try ServerURL(raw: urlString!)
        let client = HTTPClient(session: .shared, auth: NoAuthProvider())
        let api = YuvomiAPI(client: client, server: server)
        let version = try await api.fetchVersion()
        XCTAssertFalse(version.setupRequired)
        XCTAssertFalse(version.appName.isEmpty)
    }

    func testMeWithAPIToken() async throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)
        try store.saveAPIToken(token!)
        try store.saveProfile(
            ServerProfile(
                serverURL: try ServerURL(raw: urlString!).baseURL.absoluteString,
                method: .apiToken,
                displayName: nil,
                username: nil,
                userId: nil
            )
        )

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)
        let client = HTTPClient(session: session, auth: store)
        let api = YuvomiAPI(client: client, server: try ServerURL(raw: urlString!))

        let me = try await api.me()
        XCTAssertGreaterThan(me.user.id, 0)
        XCTAssertFalse(me.user.username.isEmpty)
        XCTAssertFalse(me.user.displayName.isEmpty)

        let dash = try await api.fetchDashboardData()
        XCTAssertFalse(dash.isEmpty)
        let snap = try DashboardSnapshot(data: dash)
        XCTAssertFalse(snap.summaryLines.isEmpty)
    }
}
