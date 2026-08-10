import Foundation

enum APITokenNormalizer {
    /// Strips whitespace, wrapping quotes, and an accidental `Bearer ` prefix.
    static func normalize(_ raw: String) -> String {
        var token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Zero-width / BOM characters sometimes ride along with paste.
        token = token.replacingOccurrences(of: "\u{200B}", with: "")
        token = token.replacingOccurrences(of: "\u{FEFF}", with: "")
        if (token.hasPrefix("\"") && token.hasSuffix("\""))
            || (token.hasPrefix("'") && token.hasSuffix("'")) {
            token = String(token.dropFirst().dropLast())
            token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if token.count > 7, token.prefix(7).lowercased() == "bearer " {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return token
    }
}
