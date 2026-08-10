import Foundation

// MARK: - Notes

struct Note: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var title: String?
    var content: String
    var color: String?
    var pinned: Bool
    var creatorName: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, content, color, pinned
        case creatorName = "creator_name"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color)
        pinned = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.pinned)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        let first = content.split(separator: "\n").first.map(String.init) ?? "Note"
        return first.count > 40 ? String(first.prefix(40)) + "…" : first
    }
}

// MARK: - Documents

struct FamilyDocument: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var description: String?
    var category: String?
    var status: String?
    var visibility: String?
    var originalName: String?
    var mimeType: String?
    var fileSize: Int?
    var folderName: String?
    var creatorName: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, status, visibility
        case originalName = "original_name"
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case folderName = "folder_name"
        case creatorName = "creator_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
        originalName = try c.decodeIfPresent(String.self, forKey: .originalName)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType)
        fileSize = try c.decodeIfPresent(Int.self, forKey: .fileSize)
        folderName = try c.decodeIfPresent(String.self, forKey: .folderName)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var sizeLabel: String? {
        guard let fileSize else { return nil }
        if fileSize < 1024 { return "\(fileSize) B" }
        if fileSize < 1024 * 1024 { return String(format: "%.1f KB", Double(fileSize) / 1024) }
        return String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
    }
}

// MARK: - Housekeeping

struct HousekeepingDashboard: Decodable, Equatable {
    var visitsThisMonth: Int
    var pendingTasks: Int
    var finishedTasksThisMonth: Int
    var pendingPayments: Double
    var paidThisMonth: Double
    var workers: [HousekeepingWorker]

    enum CodingKeys: String, CodingKey {
        case visitsThisMonth = "visits_this_month"
        case pendingTasks = "pending_tasks"
        case finishedTasksThisMonth = "finished_tasks_this_month"
        case pendingPayments = "pending_payments"
        case paidThisMonth = "paid_this_month"
        case workers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visitsThisMonth = try c.decodeIfPresent(Int.self, forKey: .visitsThisMonth) ?? 0
        pendingTasks = try c.decodeIfPresent(Int.self, forKey: .pendingTasks) ?? 0
        finishedTasksThisMonth = try c.decodeIfPresent(Int.self, forKey: .finishedTasksThisMonth) ?? 0
        pendingPayments = Self.num(c, .pendingPayments)
        paidThisMonth = Self.num(c, .paidThisMonth)
        workers = try c.decodeIfPresent([HousekeepingWorker].self, forKey: .workers) ?? []
    }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return 0
    }
}

struct HousekeepingWorker: Identifiable, Equatable, Sendable, Codable {
    let id: Int?
    var name: String?
    var displayName: String?

    var label: String { displayName ?? name ?? "Worker \(id.map(String.init) ?? "")" }

    enum CodingKeys: String, CodingKey {
        case id, name
        case displayName = "display_name"
    }
}

// MARK: - Reminders

struct ReminderItem: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var entityType: String
    var entityId: Int
    var remindAt: String
    var dismissed: Bool
    var title: String?
    var entityTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case entityType = "entity_type"
        case entityId = "entity_id"
        case remindAt = "remind_at"
        case dismissed
        case entityTitle = "entity_title"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        entityType = try c.decodeIfPresent(String.self, forKey: .entityType) ?? ""
        entityId = try c.decodeIfPresent(Int.self, forKey: .entityId) ?? 0
        remindAt = try c.decodeIfPresent(String.self, forKey: .remindAt) ?? ""
        dismissed = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.dismissed)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        entityTitle = try c.decodeIfPresent(String.self, forKey: .entityTitle)
    }

    var displayTitle: String {
        title ?? entityTitle ?? "\(entityType) #\(entityId)"
    }
}
