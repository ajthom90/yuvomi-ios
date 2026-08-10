import XCTest
@testable import Yuvomi

@MainActor
final class AuthSessionStoreTests: XCTestCase {
    func testSaveAndLoadAPITokenProfile() throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)

        try store.saveAPIToken("secret-token")
        try store.completeSignIn(
            profile: ServerProfile(
                serverURL: "https://example.test",
                method: .apiToken,
                displayName: "Alex",
                username: "alex",
                userId: 1
            ),
            user: User(
                id: 1,
                username: "alex",
                displayName: "Alex",
                avatarColor: "#000",
                role: "admin",
                familyRole: "other"
            )
        )

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(try store.apiToken(), "secret-token")
        XCTAssertEqual(store.profile?.serverURL, "https://example.test")

        let reloaded = AuthSessionStore(secrets: secrets)
        XCTAssertTrue(reloaded.isAuthenticated)
        XCTAssertEqual(reloaded.profile?.userId, 1)
    }

    func testPersistProfileDoesNotAuthenticateUntilComplete() throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)
        try store.saveAPIToken("tok")
        try store.persistProfile(
            ServerProfile(serverURL: "https://example.test", method: .apiToken, displayName: nil, username: nil, userId: nil)
        )
        XCTAssertFalse(store.isAuthenticated)
    }

    func testClearAllRemovesSecrets() throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)
        try store.saveAPIToken("x")
        try store.saveCSRFToken("csrf")
        try store.completeSignIn(
            profile: ServerProfile(serverURL: "https://example.test", method: .session, displayName: nil, username: nil, userId: nil),
            user: User(id: 2, username: "u", displayName: "U", avatarColor: "#111", role: "member", familyRole: "other")
        )

        try store.clearAll()
        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(try store.apiToken())
        XCTAssertNil(try store.csrfToken())
    }
}
