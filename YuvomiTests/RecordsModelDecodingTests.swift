import XCTest
@testable import Yuvomi

final class RecordsModelDecodingTests: XCTestCase {
    func testNotePinned() throws {
        let json = """
        {"id":2,"title":"Health","content":"Notes","color":"#81D4FA","pinned":1,"creator_name":"A","updated_at":"2026-08-10T20:00:00Z"}
        """.data(using: .utf8)!
        let note = try JSONDecoder().decode(Note.self, from: json)
        XCTAssertTrue(note.pinned)
        XCTAssertEqual(note.displayTitle, "Health")
    }

    func testHousekeepingDashboard() throws {
        let json = """
        {"visits_this_month":2,"pending_tasks":1,"finished_tasks_this_month":3,"pending_payments":40,"paid_this_month":100,"workers":[]}
        """.data(using: .utf8)!
        let dash = try JSONDecoder().decode(HousekeepingDashboard.self, from: json)
        XCTAssertEqual(dash.visitsThisMonth, 2)
        XCTAssertEqual(dash.pendingPayments, 40, accuracy: 0.01)
    }

    func testReminder() throws {
        let json = """
        {"id":2,"entity_type":"event","entity_id":811,"remind_at":"2026-08-11T09:00:00","dismissed":0}
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(ReminderItem.self, from: json)
        XCTAssertEqual(r.entityType, "event")
        XCTAssertFalse(r.dismissed)
    }
}
