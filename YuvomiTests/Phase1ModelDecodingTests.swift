import XCTest
@testable import Yuvomi

final class Phase1ModelDecodingTests: XCTestCase {
    func testTaskDecoding() throws {
        let json = """
        {"data":[{"id":1,"title":"Take out recycling","description":null,"category":"misc","priority":"medium","status":"open","due_date":"2026-08-12","due_time":null,"points":0,"visibility":"all","assigned_name":null,"tags":[],"subtask_total":0,"subtask_done":0,"archived_at":null}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder().decode(APIList<TaskItem>.self, from: json)
        XCTAssertEqual(list.data.count, 1)
        XCTAssertEqual(list.data[0].title, "Take out recycling")
        XCTAssertEqual(list.data[0].status, "open")
        XCTAssertEqual(list.data[0].dueDate, "2026-08-12")
    }

    func testShoppingItemCheckedAsInt() throws {
        let json = """
        {"id":1,"list_id":1,"name":"Milk","quantity":"1 gal","category":"Dairy","is_checked":1,"notes":null,"sort_order":1}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(ShoppingItem.self, from: json)
        XCTAssertTrue(item.isChecked)
        XCTAssertEqual(item.name, "Milk")
    }

    func testCalendarEventAllDayAsInt() throws {
        let json = """
        {"id":9,"title":"Trip","description":null,"start_datetime":"2026-08-11","end_datetime":"2026-08-11","all_day":1,"location":null,"color":"#CC73E1","cal_name":"Family","creator_name":"Andrew","visibility":"all","external_source":"caldav"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(CalendarEvent.self, from: json)
        XCTAssertTrue(event.allDay)
        XCTAssertEqual(event.dayKey, "2026-08-11")
        XCTAssertFalse(event.isLocal)
    }
}
