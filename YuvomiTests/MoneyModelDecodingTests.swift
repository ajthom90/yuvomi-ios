import XCTest
@testable import Yuvomi

final class MoneyModelDecodingTests: XCTestCase {
    func testBudgetEntry() throws {
        let json = """
        {"id":1,"title":"Coffee","amount":-4.5,"category":"food","date":"2026-08-10","subcategory":"groceries","account_id":1,"visibility":"shared","creator_name":"A","is_pending":0}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(BudgetEntry.self, from: json)
        XCTAssertTrue(entry.isExpense)
        XCTAssertEqual(entry.amount, -4.5, accuracy: 0.001)
    }

    func testAccountsPayload() throws {
        let json = """
        {"accounts":[{"id":1,"name":"Checking","type":"checking","starting_balance":1000,"current_balance":995.5,"currency":null,"archived":0}],"net_worth":995.5}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(BudgetAccountsPayload.self, from: json)
        XCTAssertEqual(payload.accounts.count, 1)
        XCTAssertEqual(payload.netWorth, 995.5, accuracy: 0.001)
    }

    func testSplitExpenseAmountString() throws {
        let json = """
        {"id":1,"group_id":1,"title":"Dinner","amount":"80.00","currency":"USD","payer_name":"Andrew","category":"travel","expense_date":"2026-08-10","split_method":"equal"}
        """.data(using: .utf8)!
        let expense = try JSONDecoder().decode(SplitExpense.self, from: json)
        XCTAssertEqual(expense.amount, "80.00")
        XCTAssertEqual(expense.currency, "USD")
    }
}
