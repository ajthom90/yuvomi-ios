import Foundation

struct DashboardPayload: Decodable, Equatable {
    var upcomingEvents: [CalendarEvent]
    var urgentTasks: [TaskItem]
    var todayMeals: [MealPlanEntry]
    var pinnedNotes: [Note]
    var shoppingLists: [DashboardShoppingList]
    var birthdays: [Birthday]
    var budget: DashboardBudget?
    var rewards: DashboardRewards?
    var health: DashboardHealth?
    var housekeeping: DashboardHousekeeping?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        upcomingEvents = (try? c.decode([CalendarEvent].self, forKey: .upcomingEvents)) ?? []
        urgentTasks = (try? c.decode([TaskItem].self, forKey: .urgentTasks)) ?? []
        todayMeals = (try? c.decode([MealPlanEntry].self, forKey: .todayMeals)) ?? []
        pinnedNotes = (try? c.decode([Note].self, forKey: .pinnedNotes)) ?? []
        shoppingLists = (try? c.decode([DashboardShoppingList].self, forKey: .shoppingLists)) ?? []
        birthdays = (try? c.decode([Birthday].self, forKey: .birthdays)) ?? []
        budget = try? c.decode(DashboardBudget.self, forKey: .budget)
        rewards = try? c.decode(DashboardRewards.self, forKey: .rewards)
        health = try? c.decode(DashboardHealth.self, forKey: .health)
        housekeeping = try? c.decode(DashboardHousekeeping.self, forKey: .housekeeping)
    }

    enum CodingKeys: String, CodingKey {
        case upcomingEvents, urgentTasks, todayMeals, pinnedNotes, shoppingLists, birthdays
        case budget, rewards, health, housekeeping
    }
}

struct DashboardShoppingList: Identifiable, Decodable, Equatable {
    let id: Int
    var name: String
    var openCount: Int
    var totalCount: Int
    var items: [DashboardShoppingItem]

    enum CodingKeys: String, CodingKey {
        case id, name, items
        case openCount = "open_count"
        case totalCount = "total_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        openCount = try c.decodeIfPresent(Int.self, forKey: .openCount) ?? 0
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        items = try c.decodeIfPresent([DashboardShoppingItem].self, forKey: .items) ?? []
    }
}

struct DashboardShoppingItem: Identifiable, Decodable, Equatable {
    let id: Int
    var name: String
    var quantity: String?
    var isChecked: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, quantity
        case isChecked = "is_checked"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)
        isChecked = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.isChecked)
    }
}

struct DashboardBudget: Decodable, Equatable {
    var month: String?
    var income: Double
    var expenses: Double
    var balance: Double
    var entryCount: Int?
    var topExpenseCategory: String?

    enum CodingKeys: String, CodingKey {
        case month, income, expenses, balance, entryCount, topExpenseCategory, topExpenseAmount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        month = try c.decodeIfPresent(String.self, forKey: .month)
        income = Self.d(c, .income)
        expenses = Self.d(c, .expenses)
        balance = Self.d(c, .balance)
        entryCount = try c.decodeIfPresent(Int.self, forKey: .entryCount)
        topExpenseCategory = try c.decodeIfPresent(String.self, forKey: .topExpenseCategory)
    }

    private static func d(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let v = try? c.decode(Double.self, forKey: k) { return v }
        if let v = try? c.decode(Int.self, forKey: k) { return Double(v) }
        return 0
    }
}

struct DashboardRewards: Decodable, Equatable {
    var participantCount: Int?
    var pending: Int?
}

struct DashboardHealth: Decodable, Equatable {
    var hasMeds: Bool?
    var dosesTotal: Int?
    var dosesTaken: Int?
    var lowStockCount: Int?
}

struct DashboardHousekeeping: Decodable, Equatable {
    var configured: Bool?
    var present: Bool?
    var workerName: String?
    var visitsThisMonth: Int?
    var unpaidAmount: Double?
}

// MARK: - Search

struct SearchResults: Decodable, Equatable {
    var tasks: [SearchHit]
    var events: [SearchHit]
    var notes: [SearchHit]
    var contacts: [SearchHit]
    var items: [SearchHit]
    var meds: [SearchHit]
    var activities: [SearchHit]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = (try? c.decode([SearchHit].self, forKey: .tasks)) ?? []
        events = (try? c.decode([SearchHit].self, forKey: .events)) ?? []
        notes = (try? c.decode([SearchHit].self, forKey: .notes)) ?? []
        contacts = (try? c.decode([SearchHit].self, forKey: .contacts)) ?? []
        items = (try? c.decode([SearchHit].self, forKey: .items)) ?? []
        meds = (try? c.decode([SearchHit].self, forKey: .meds)) ?? []
        activities = (try? c.decode([SearchHit].self, forKey: .activities)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case tasks, events, notes, contacts, items, meds, activities
    }

    var isEmpty: Bool {
        tasks.isEmpty && events.isEmpty && notes.isEmpty && contacts.isEmpty
            && items.isEmpty && meds.isEmpty && activities.isEmpty
    }

    var sections: [(title: String, hits: [SearchHit])] {
        [
            ("Tasks", tasks),
            ("Events", events),
            ("Notes", notes),
            ("Contacts", contacts),
            ("Items", items),
            ("Meds", meds),
            ("Activities", activities),
        ].filter { !$0.hits.isEmpty }
    }
}

struct SearchHit: Identifiable, Decodable, Equatable {
    let id: Int
    var title: String
    var subtitle: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, content
        case startDatetime = "start_datetime"
        case allDay = "all_day"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        if let t = try c.decodeIfPresent(String.self, forKey: .title), !t.isEmpty {
            title = t
        } else if let n = try c.decodeIfPresent(String.self, forKey: .name), !n.isEmpty {
            title = n
        } else if let content = try c.decodeIfPresent(String.self, forKey: .content) {
            title = String(content.prefix(60))
        } else {
            title = "#\(id)"
        }
        subtitle = try c.decodeIfPresent(String.self, forKey: .startDatetime)
    }
}

// MARK: - Invites

struct Invite: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var email: String?
    var username: String?
    var displayName: String?
    var role: String?
    var familyRole: String?
    var expiresAt: Double?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, email, username, role
        case displayName = "display_name"
        case familyRole = "family_role"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct InviteCreateResponse: Decodable {
    let invite: Invite
    let token: String
    let emailSent: Bool?

    enum CodingKeys: String, CodingKey {
        case invite, token
        case emailSent = "email_sent"
    }
}

struct InvitesListPayload: Decodable {
    let invites: [Invite]
}
