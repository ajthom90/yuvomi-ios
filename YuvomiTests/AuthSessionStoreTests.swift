import XCTest
@testable import Yuvomi

@MainActor
final class AuthSessionStoreTests: XCTestCase {
    func testSaveAndLoadAPITokenProfile() throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)

        try store.saveAPIToken("secret-token")
        try store.saveProfile(
            ServerProfile(
                serverURL: "https://example.test",
                method: .apiToken,
                displayName: "Alex",
                username: "alex",
                userId: 1
            )
        )

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(try store.apiToken(), "secret-token")
        XCTAssertEqual(store.profile?.serverURL, "https://example.test")

        let reloaded = AuthSessionStore(secrets: secrets)
        XCTAssertTrue(reloaded.isAuthenticated)
        XCTAssertEqual(reloaded.profile?.userId, 1)
    }

    func testClearAllRemovesSecrets() throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)
        try store.saveAPIToken("x")
        try store.saveCSRFToken("csrf")
        try store.saveProfile(
            ServerProfile(serverURL: "https://example.test", method: .session, displayName: nil, username: nil, userId: nil)
        )

        try store.clearAll()
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(try store.apiToken())
        XCTAssertNil(try store.csrfToken())
    }
}
