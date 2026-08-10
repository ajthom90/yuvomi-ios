import Foundation

/// Flexible dashboard payload — upstream schema is intentionally broad.
struct DashboardSnapshot: Equatable, Sendable {
    /// Precomputed summary lines so we don't store non-Sendable `Any` JSON.
    let summaryLines: [String]
    let sectionTitles: [String]
    let fetchedAt: Date

    init(data: Data, fetchedAt: Date = .now) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw APIError.decoding("Dashboard root is not an object")
        }
        let dict: [String: Any]
        if let nested = root["data"] as? [String: Any] {
            dict = nested
        } else {
            dict = root
        }

        let keys = dict.keys.sorted()
        self.sectionTitles = keys
        self.summaryLines = keys.prefix(12).map { key in
            guard let value = dict[key] else { return key }
            switch value {
            case let array as [Any]:
                return "\(key): \(array.count) items"
            case let nested as [String: Any]:
                return "\(key): \(nested.count) fields"
            case let n as NSNumber:
                return "\(key): \(n)"
            case let s as String:
                return "\(key): \(s)"
            default:
                return key
            }
        }
        self.fetchedAt = fetchedAt
    }

    func summaryLines(limit: Int = 12) -> [String] {
        Array(summaryLines.prefix(limit))
    }
}
