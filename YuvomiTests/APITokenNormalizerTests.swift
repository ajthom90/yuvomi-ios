import XCTest
@testable import Yuvomi

final class APITokenNormalizerTests: XCTestCase {
    func testStripsBearerPrefixAndWhitespace() {
        XCTAssertEqual(
            APITokenNormalizer.normalize("  Bearer yuvomi_abc123  "),
            "yuvomi_abc123"
        )
    }

    func testStripsQuotes() {
        XCTAssertEqual(
            APITokenNormalizer.normalize("\"yuvomi_abc123\""),
            "yuvomi_abc123"
        )
    }

    func testLeavesBareToken() {
        XCTAssertEqual(
            APITokenNormalizer.normalize("yuvomi_abc123"),
            "yuvomi_abc123"
        )
    }
}
