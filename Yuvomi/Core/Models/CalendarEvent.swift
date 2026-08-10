import Foundation

struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var description: String?
    var startDatetime: String
    var endDatetime: String?
    var allDay: Bool
    var location: String?
    var color: String?
    var calName: String?
    var creatorName: String?
    var visibility: String?
    var externalSource: String?

    var isLocal: Bool { externalSource == nil || externalSource == "local" }
}

extension CalendarEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, description, location, color, visibility
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case allDay = "all_day"
        case calName = "cal_name"
        case creatorName = "creator_name"
        case externalSource = "external_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        startDatetime = try c.decodeIfPresent(String.self, forKey: .startDatetime) ?? ""
        endDatetime = try c.decodeIfPresent(String.self, forKey: .endDatetime)
        allDay = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.allDay)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        calName = try c.decodeIfPresent(String.self, forKey: .calName)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility)
        externalSource = try c.decodeIfPresent(String.self, forKey: .externalSource)
    }
}

extension CalendarEvent {
    /// Best-effort display date from server strings (`YYYY-MM-DD` or ISO-ish).
    var startDate: Date? {
        Self.parseDate(startDatetime)
    }

    var dayKey: String {
        String(startDatetime.prefix(10))
    }

    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 10 {
            let day = String(trimmed.prefix(10))
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: day) { return d }
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: trimmed)
    }
}
