import XCTest
@testable import Yuvomi

final class DashboardSearchDecodingTests: XCTestCase {
    func testDashboardPayload() throws {
        let json = """
        {
          "upcomingEvents":[{"id":1,"title":"Event","start_datetime":"2026-08-11","end_datetime":"2026-08-11","all_day":1}],
          "urgentTasks":[{"id":2,"title":"Task","status":"open","priority":"low"}],
          "todayMeals":[],
          "pinnedNotes":[{"id":1,"title":"N","content":"Hello","color":"#FFEB3B","pinned":1}],
          "shoppingLists":[{"id":1,"name":"Groceries","open_count":2,"total_count":3,"items":[{"id":1,"name":"Milk","quantity":"1","is_checked":0}]}],
          "birthdays":[{"id":1,"name":"Ella","birth_date":"2015-05-01","days_until":10,"next_age":12}],
          "budget":{"month":"2026-08","income":100,"expenses":10,"balance":90,"entryCount":2,"topExpenseCategory":"food"}
        }
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(DashboardPayload.self, from: json)
        XCTAssertEqual(d.upcomingEvents.count, 1)
        XCTAssertEqual(d.urgentTasks.first?.title, "Task")
        XCTAssertEqual(d.shoppingLists.first?.openCount, 2)
        XCTAssertEqual(d.budget?.balance ?? -1, 90, accuracy: 0.01)
    }

    func testSearchResults() throws {
        let json = """
        {"tasks":[],"events":[{"id":1363,"title":"Birthday: Ella","start_datetime":"2015-05-01","all_day":1}],"notes":[],"contacts":[],"items":[],"meds":[],"activities":[]}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(SearchResults.self, from: json)
        XCTAssertEqual(s.events.count, 1)
        XCTAssertEqual(s.events[0].title, "Birthday: Ella")
        XCTAssertFalse(s.isEmpty)
    }

    func testInviteCreate() throws {
        let json = """
        {"invite":{"id":1,"username":"guest","display_name":"Guest","role":"member","family_role":"other","expires_at":1,"created_at":"2026-08-10T00:00:00Z"},"token":"abc","email_sent":false}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(InviteCreateResponse.self, from: json)
        XCTAssertEqual(r.token, "abc")
        XCTAssertEqual(r.invite.displayName, "Guest")
    }
}
