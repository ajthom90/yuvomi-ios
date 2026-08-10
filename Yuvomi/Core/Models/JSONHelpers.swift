import Foundation

enum JSONHelpers {
    /// Decodes JSON `0`/`1`, `true`/`false`, or missing as Bool.
    static func decodeBool<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> Bool {
        if let b = try? container.decode(Bool.self, forKey: key) { return b }
        if let i = try? container.decode(Int.self, forKey: key) { return i != 0 }
        if let s = try? container.decode(String.self, forKey: key) {
            return s == "1" || s.lowercased() == "true"
        }
        return false
    }
}

struct APIData<T: Decodable>: Decodable {
    let data: T
}

struct APIList<T: Decodable>: Decodable {
    let data: [T]
}
