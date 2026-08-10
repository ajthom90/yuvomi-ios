import XCTest
@testable import Yuvomi

final class UserDecodingTests: XCTestCase {
    func testDecodesLoginShapedPayload() throws {
        let json = """
        {
          "user": {
            "id": 1,
            "username": "admin",
            "display_name": "Admin",
            "avatar_color": "#007AFF",
            "avatar_data": null,
            "role": "admin",
            "family_role": "dad",
            "access_scope": "family",
            "phone": null,
            "email": null,
            "birth_date": null,
            "created_at": "2026-01-01T00:00:00Z"
          },
          "permissions": { "tasks": true },
          "householdSize": 2,
          "csrfToken": "abc"
        }
        """.data(using: .utf8)!

        let me = try JSONDecoder().decode(MeResponse.self, from: json)
        XCTAssertEqual(me.user.username, "admin")
        XCTAssertEqual(me.user.displayName, "Admin")
        XCTAssertEqual(me.csrfToken, "abc")
    }

    func testDecodesMinimalUserWithoutOptionalFields() throws {
        let json = """
        {
          "user": {
            "id": "3",
            "username": "kid",
            "display_name": "Kid",
            "role": "member"
          }
        }
        """.data(using: .utf8)!

        let me = try JSONDecoder().decode(MeResponse.self, from: json)
        XCTAssertEqual(me.user.id, 3)
        XCTAssertEqual(me.user.familyRole, "other")
        XCTAssertEqual(me.user.avatarColor, "#4F4DC9")
    }
}
