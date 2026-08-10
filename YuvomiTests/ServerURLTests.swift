import XCTest
@testable import Yuvomi

final class ServerURLTests: XCTestCase {
    func testHTTPSPassthrough() throws {
        let url = try ServerURL(raw: "https://home.example")
        XCTAssertEqual(url.baseURL.absoluteString, "https://home.example")
        XCTAssertEqual(url.apiURL(path: "/auth/login").absoluteString, "https://home.example/api/v1/auth/login")
    }

    func testAddsHTTPSWhenMissingScheme() throws {
        let url = try ServerURL(raw: "home.example")
        XCTAssertEqual(url.baseURL.absoluteString, "https://home.example")
    }

    func testStripsAPIV1Suffix() throws {
        let url = try ServerURL(raw: "https://home.example/api/v1")
        XCTAssertEqual(url.baseURL.absoluteString, "https://home.example")
        XCTAssertEqual(url.apiURL(path: "dashboard").absoluteString, "https://home.example/api/v1/dashboard")
    }

    func testStripsAPISuffix() throws {
        let url = try ServerURL(raw: "https://home.example/api/")
        XCTAssertEqual(url.baseURL.absoluteString, "https://home.example")
    }

    func testRejectsEmpty() {
        XCTAssertThrowsError(try ServerURL(raw: "   ")) { error in
            XCTAssertEqual(error as? ServerURLError, .empty)
        }
    }

    func testRejectsFTP() {
        XCTAssertThrowsError(try ServerURL(raw: "ftp://home.example")) { error in
            XCTAssertEqual(error as? ServerURLError, .unsupportedScheme("ftp"))
        }
    }

    func testTrimsWhitespace() throws {
        let url = try ServerURL(raw: "  https://home.example/  ")
        XCTAssertEqual(url.baseURL.absoluteString, "https://home.example")
    }
}
