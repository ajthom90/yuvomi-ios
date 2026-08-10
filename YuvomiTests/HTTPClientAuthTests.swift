import XCTest
@testable import Yuvomi

final class HTTPClientAuthTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        StubURLProtocol.handler = nil
    }

    @MainActor
    func testBearerTokenIsInjected() async throws {
        let secrets = InMemorySecretStore()
        let store = AuthSessionStore(secrets: secrets)
        try store.saveAPIToken("tok-123")
        try store.saveProfile(
            ServerProfile(serverURL: "https://example.test", method: .apiToken, displayName: nil, username: nil, userId: nil)
        )

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "tok-123")
            let data = Data(#"{"status":"ok","timestamp":"2026-01-01T00:00:00Z"}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = HTTPClient(session: session, auth: store)

        var request = URLRequest(url: URL(string: "https://example.test/api/v1/version")!)
        request.httpMethod = "GET"
        let data = try await client.sendData(request)
        XCTAssertFalse(data.isEmpty)
    }

    func testUnauthorizedMapsToAPIError() async throws {
        StubURLProtocol.handler = { request in
            let data = Data(#"{"error":"nope"}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = HTTPClient(session: session, auth: NoAuthProvider())

        var request = URLRequest(url: URL(string: "https://example.test/api/v1/auth/me")!)
        request.httpMethod = "GET"

        do {
            _ = try await client.sendData(request)
            XCTFail("Expected unauthorized")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
