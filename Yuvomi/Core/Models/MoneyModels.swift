import Foundation

// MARK: - Budget

struct BudgetAccount: Identifiable, Equatable, Sendable {
    let id: Int
    var name: String
    var type: String
    var startingBalance: Double
    var currentBalance: Double
    var currency: String?
    var archived: Bool
}

extension BudgetAccount: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, type, currency
        case startingBalance = "starting_balance"
        case currentBalance = "current_balance"
        case archived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "checking"
        startingBalance = Self.decodeDouble(c, .startingBalance)
        currentBalance = Self.decodeDouble(c, .currentBalance)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        archived = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.archived)
    }

    private static func decodeDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }
}

struct BudgetAccountsPayload: Decodable {
    let accounts: [BudgetAccount]
    let netWorth: Double

    enum CodingKeys: String, CodingKey {
        case accounts
        case netWorth = "net_worth"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try c.decodeIfPresent([BudgetAccount].self, forKey: .accounts) ?? []
        if let d = try? c.decode(Double.self, forKey: .netWorth) {
            netWorth = d
        } else if let i = try? c.decode(Int.self, forKey: .netWorth) {
            netWorth = Double(i)
        } else {
            netWorth = 0
        }
    }
}

struct BudgetEntry: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var amount: Double
    var category: String
    var subcategory: String?
    var date: String
    var accountId: Int?
    var visibility: String?
    var creatorName: String?
    var isPending: Bool

    var isExpense: Bool { amount < 0 }
    var isIncome: Bool { amount > 0 }
}

extension BudgetEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, date, visibility
        case subcategory
        case accountId = "account_id"
        case creatorName = "creator_name"
        case isPending = "is_pending"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = d
        } else if let i = try? c.decode(Int.self, forKey: .amount) {
            amount = Double(i)
        } else if let s = try? c.decode(String.self, forKey: .amount), let d = Double(s) {
            amount = d
        } else {
            amount = 0
        }
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        subcategory = try c.decodeIfPresent(String.self, forKey: .subcategory)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        accountId = try c.decodeIfPresent(Int.self, forKey: .accountId)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
        isPending = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.isPending)
    }
}

struct BudgetCategory: Identifiable, Equatable, Sendable, Codable {
    var id: String { key }
    let key: String
    var name: String?
    var type: String?
    var label: String?

    var displayName: String { label ?? name ?? key }
}

struct BudgetStatsTotals: Equatable, Sendable {
    var income: Double
    var expenses: Double
    var balance: Double
}

extension BudgetStatsTotals: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        income = Self.d(c, .income)
        expenses = Self.d(c, .expenses)
        balance = Self.d(c, .balance)
    }

    enum CodingKeys: String, CodingKey { case income, expenses, balance }

    private static func d(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let v = try? c.decode(Double.self, forKey: k) { return v }
        if let v = try? c.decode(Int.self, forKey: k) { return Double(v) }
        return 0
    }
}

struct BudgetStatsPayload: Decodable {
    let totals: BudgetStatsTotals
    let from: String?
    let to: String?

    enum CodingKeys: String, CodingKey { case totals, from, to }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totals = try c.decodeIfPresent(BudgetStatsTotals.self, forKey: .totals)
            ?? BudgetStatsTotals(income: 0, expenses: 0, balance: 0)
        from = try c.decodeIfPresent(String.self, forKey: .from)
        to = try c.decodeIfPresent(String.self, forKey: .to)
    }
}

// MARK: - Split expenses

struct SplitGroup: Identifiable, Equatable, Sendable {
    let id: Int
    var name: String
    var type: String?
    var defaultCurrency: String?
    var status: String?
    var memberCount: Int
    var memberRole: String?
    var avatarColor: String?
}

extension SplitGroup: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, type, status
        case defaultCurrency = "default_currency"
        case memberCount = "member_count"
        case memberRole = "member_role"
        case avatarColor = "avatar_color"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type)
        defaultCurrency = try c.decodeIfPresent(String.self, forKey: .defaultCurrency)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        memberRole = try c.decodeIfPresent(String.self, forKey: .memberRole)
        avatarColor = try c.decodeIfPresent(String.self, forKey: .avatarColor)
    }
}

struct SplitExpense: Identifiable, Equatable, Sendable {
    let id: Int
    var groupId: Int
    var title: String
    var amount: String
    var currency: String?
    var payerName: String?
    var category: String?
    var expenseDate: String?
    var splitMethod: String?
}

extension SplitExpense: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, category
        case groupId = "group_id"
        case payerName = "payer_name"
        case expenseDate = "expense_date"
        case splitMethod = "split_method"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        groupId = try c.decodeIfPresent(Int.self, forKey: .groupId) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        if let s = try? c.decode(String.self, forKey: .amount) {
            amount = s
        } else if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = String(format: "%.2f", d)
        } else {
            amount = "0"
        }
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        payerName = try c.decodeIfPresent(String.self, forKey: .payerName)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        expenseDate = try c.decodeIfPresent(String.self, forKey: .expenseDate)
        splitMethod = try c.decodeIfPresent(String.self, forKey: .splitMethod)
    }
}

struct SplitExpensesPage: Decodable {
    let data: [SplitExpense]
}

struct SplitBalanceRow: Identifiable, Equatable, Sendable, Codable {
    var id: String { "\(userId ?? 0)-\(displayName ?? "")-\(amount ?? "")" }
    var userId: Int?
    var displayName: String?
    var amount: String?
    var currency: String?

    enum CodingKeys: String, CodingKey {
        case amount, currency
        case userId = "user_id"
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        if let s = try? c.decode(String.self, forKey: .amount) {
            amount = s
        } else if let d = try? c.decode(Double.self, forKey: .amount) {
            amount = String(format: "%.2f", d)
        } else {
            amount = nil
        }
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
    }
}

struct SplitBalancesPayload: Decodable {
    let balances: [SplitBalanceRow]
    let simplifiedDebts: [SplitBalanceRow]

    enum CodingKeys: String, CodingKey {
        case balances
        case simplifiedDebts = "simplified_debts"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balances = try c.decodeIfPresent([SplitBalanceRow].self, forKey: .balances) ?? []
        simplifiedDebts = try c.decodeIfPresent([SplitBalanceRow].self, forKey: .simplifiedDebts) ?? []
    }
}

struct SplitDashboardPayload: Decodable {
    let groups: [SplitGroup]
    let recentExpenses: [SplitExpense]

    enum CodingKeys: String, CodingKey {
        case groups
        case recentExpenses = "recent_expenses"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = try c.decodeIfPresent([SplitGroup].self, forKey: .groups) ?? []
        recentExpenses = try c.decodeIfPresent([SplitExpense].self, forKey: .recentExpenses) ?? []
    }
}
