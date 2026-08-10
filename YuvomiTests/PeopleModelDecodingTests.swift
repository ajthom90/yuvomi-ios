import XCTest
@testable import Yuvomi

final class PeopleModelDecodingTests: XCTestCase {
    func testFamilyMember() throws {
        let json = """
        {"id":1,"display_name":"Andrew","avatar_color":"#FF2D55","family_role":"other","phone":null,"email":null,"birth_date":null}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(FamilyMember.self, from: json)
        XCTAssertEqual(m.displayName, "Andrew")
    }

    func testVitalBP() throws {
        let json = """
        {"id":2,"user_id":1,"type":"blood_pressure","value_num":120,"value_num2":80,"value_num3":null,"unit":"mmHg","measured_at":"2026-08-10T08:00","note":null,"visibility":"private"}
        """.data(using: .utf8)!
        let v = try JSONDecoder().decode(HealthVital.self, from: json)
        XCTAssertTrue(v.displayValue.contains("120"))
        XCTAssertTrue(v.displayValue.contains("80"))
    }

    func testRewardsOverview() throws {
        let json = """
        {"balances":[{"id":1,"display_name":"A","avatar_color":"#fff","balance":10,"rank":1}],"catalog":[{"id":1,"name":"Movie","cost":50,"description":null,"is_active":1}],"pendingCount":0,"isAdmin":true,"me":1}
        """.data(using: .utf8)!
        let o = try JSONDecoder().decode(RewardsOverview.self, from: json)
        XCTAssertEqual(o.balances.first?.balance, 10)
        XCTAssertTrue(o.catalog.first?.isActive == true)
    }
}
