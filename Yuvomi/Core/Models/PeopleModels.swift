import Foundation

// MARK: - Family

struct FamilyMember: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var displayName: String
    var avatarColor: String?
    var familyRole: String?
    var phone: String?
    var email: String?
    var birthDate: String?

    enum CodingKeys: String, CodingKey {
        case id, phone, email
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case familyRole = "family_role"
        case birthDate = "birth_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarColor = try c.decodeIfPresent(String.self, forKey: .avatarColor)
        familyRole = try c.decodeIfPresent(String.self, forKey: .familyRole)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate)
    }
}

// MARK: - Contacts

struct Contact: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var category: String?
    var phone: String?
    var email: String?
    var address: String?
    var notes: String?
    var organization: String?
    var birthday: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, phone, email, address, notes, organization, birthday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        organization = try c.decodeIfPresent(String.self, forKey: .organization)
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday)
    }
}

// MARK: - Birthdays

struct Birthday: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var birthDate: String
    var notes: String?
    var nextBirthday: String?
    var nextAge: Int?
    var daysUntil: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case birthDate = "birth_date"
        case nextBirthday = "next_birthday"
        case nextAge = "next_age"
        case daysUntil = "days_until"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        nextBirthday = try c.decodeIfPresent(String.self, forKey: .nextBirthday)
        nextAge = try c.decodeIfPresent(Int.self, forKey: .nextAge)
        daysUntil = try c.decodeIfPresent(Int.self, forKey: .daysUntil)
    }
}

// MARK: - Health

struct HealthVital: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var userId: Int?
    var type: String
    var valueNum: Double?
    var valueNum2: Double?
    var valueNum3: Double?
    var unit: String?
    var measuredAt: String?
    var note: String?
    var visibility: String?

    enum CodingKeys: String, CodingKey {
        case id, type, unit, note, visibility
        case userId = "user_id"
        case valueNum = "value_num"
        case valueNum2 = "value_num2"
        case valueNum3 = "value_num3"
        case measuredAt = "measured_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        valueNum = Self.double(c, .valueNum)
        valueNum2 = Self.double(c, .valueNum2)
        valueNum3 = Self.double(c, .valueNum3)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        measuredAt = try c.decodeIfPresent(String.self, forKey: .measuredAt)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
    }

    private static func double(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return nil
    }

    var displayValue: String {
        if type == "blood_pressure", let s = valueNum, let d = valueNum2 {
            return "\(format(s))/\(format(d)) \(unit ?? "mmHg")"
        }
        if let v = valueNum {
            return "\(format(v)) \(unit ?? "")".trimmingCharacters(in: .whitespaces)
        }
        return "—"
    }

    private func format(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%g", v)
    }
}

// MARK: - Rewards

struct RewardBalance: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var displayName: String
    var avatarColor: String?
    var balance: Int
    var rank: Int?

    enum CodingKeys: String, CodingKey {
        case id, balance, rank
        case displayName = "display_name"
        case avatarColor = "avatar_color"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarColor = try c.decodeIfPresent(String.self, forKey: .avatarColor)
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        rank = try c.decodeIfPresent(Int.self, forKey: .rank)
    }
}

struct RewardCatalogItem: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var cost: Int
    var description: String?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, cost, description
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        cost = try c.decodeIfPresent(Int.self, forKey: .cost) ?? 0
        description = try c.decodeIfPresent(String.self, forKey: .description)
        isActive = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.isActive)
    }
}

struct RewardsOverview: Decodable {
    let balances: [RewardBalance]
    let catalog: [RewardCatalogItem]
    let pendingCount: Int
    let isAdmin: Bool
    let me: Int?

    enum CodingKeys: String, CodingKey {
        case balances, catalog, me
        case pendingCount
        case isAdmin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balances = try c.decodeIfPresent([RewardBalance].self, forKey: .balances) ?? []
        catalog = try c.decodeIfPresent([RewardCatalogItem].self, forKey: .catalog) ?? []
        pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        me = try c.decodeIfPresent(Int.self, forKey: .me)
    }
}
