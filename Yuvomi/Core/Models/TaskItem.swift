import Foundation

struct TaskItem: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var description: String?
    var category: String?
    var priority: String
    var status: String
    var dueDate: String?
    var dueTime: String?
    var points: Int
    var visibility: String?
    var assignedName: String?
    var tags: [String]
    var subtaskTotal: Int
    var subtaskDone: Int
    var archivedAt: String?

    var isDone: Bool { status == "done" }
    var isArchived: Bool { archivedAt != nil || status == "archived" }

    var priorityLabel: String {
        switch priority {
        case "urgent": "Urgent"
        case "high": "High"
        case "medium": "Medium"
        case "low": "Low"
        default: "None"
        }
    }
}

extension TaskItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, priority, status, points, visibility, tags
        case dueDate = "due_date"
        case dueTime = "due_time"
        case assignedName = "assigned_name"
        case subtaskTotal = "subtask_total"
        case subtaskDone = "subtask_done"
        case archivedAt = "archived_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        priority = try c.decodeIfPresent(String.self, forKey: .priority) ?? "none"
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        dueTime = try c.decodeIfPresent(String.self, forKey: .dueTime)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
        assignedName = try c.decodeIfPresent(String.self, forKey: .assignedName)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        subtaskTotal = try c.decodeIfPresent(Int.self, forKey: .subtaskTotal) ?? 0
        subtaskDone = try c.decodeIfPresent(Int.self, forKey: .subtaskDone) ?? 0
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
    }
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case open
    case inProgress = "in_progress"
    case done
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In progress"
        case .done: "Done"
        case .archived: "Archived"
        }
    }
}
