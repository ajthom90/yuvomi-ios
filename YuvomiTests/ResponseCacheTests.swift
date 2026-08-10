import XCTest
@testable import Yuvomi

final class ResponseCacheTests: XCTestCase {
    func testStoreLoadAndClear() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = ResponseCache(directory: dir)
        let key = ResponseCache.key(host: "example.test", userId: 3, path: "/dashboard")
        let payload = Data("{\"ok\":true}".utf8)

        try await cache.store(key: key, data: payload)
        let loaded = await cache.load(key: key)
        XCTAssertEqual(loaded?.data, payload)
        XCTAssertNotNil(loaded?.savedAt)

        try await cache.clearAll()
        let after = await cache.load(key: key)
        XCTAssertNil(after)
    }

    func testKeyIsStable() {
        let a = ResponseCache.key(host: "h", userId: 1, path: "/x")
        let b = ResponseCache.key(host: "h", userId: 1, path: "/x")
        let c = ResponseCache.key(host: "h", userId: 2, path: "/x")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
