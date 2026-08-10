import XCTest
@testable import Yuvomi

final class DocumentUploadEncodingTests: XCTestCase {
    func testDataURLEncodingRoundTrip() {
        let payload = Data("Hello from iOS".utf8)
        let mime = "text/plain"
        let dataURL = "data:\(mime);base64,\(payload.base64EncodedString())"
        XCTAssertTrue(dataURL.hasPrefix("data:text/plain;base64,"))
        let b64 = String(dataURL.split(separator: ",").last ?? "")
        let decoded = Data(base64Encoded: b64)
        XCTAssertEqual(decoded, payload)
    }

    func testDocumentModelSizeLabel() throws {
        let json = """
        {"id":1,"name":"Doc","original_name":"a.txt","mime_type":"text/plain","file_size":2048,"category":"other","status":"active","visibility":"family"}
        """.data(using: .utf8)!
        let doc = try JSONDecoder().decode(FamilyDocument.self, from: json)
        XCTAssertEqual(doc.sizeLabel, "2.0 KB")
    }
}
