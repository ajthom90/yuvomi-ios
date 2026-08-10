import Foundation

enum ServerURLError: LocalizedError, Equatable, Sendable {
    case empty
    case invalid
    case unsupportedScheme(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            "Enter your Yuvomi server URL."
        case .invalid:
            "That doesn’t look like a valid server address."
        case .unsupportedScheme(let scheme):
            "Unsupported URL scheme “\(scheme)”. Use http or https."
        }
    }
}

struct ServerURL: Equatable, Sendable, Hashable {
    let baseURL: URL

    var host: String {
        baseURL.host() ?? baseURL.absoluteString
    }

    init(raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServerURLError.empty }

        var candidate = trimmed
        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }

        guard var components = URLComponents(string: candidate) else {
            throw ServerURLError.invalid
        }

        guard let scheme = components.scheme?.lowercased() else {
            throw ServerURLError.invalid
        }
        guard scheme == "http" || scheme == "https" else {
            throw ServerURLError.unsupportedScheme(scheme)
        }
        components.scheme = scheme

        guard let host = components.host, !host.isEmpty else {
            throw ServerURLError.invalid
        }

        // Drop accidental /api or /api/v1 suffixes so we always own the API root.
        if var path = components.path as String? {
            while path.hasSuffix("/") {
                path.removeLast()
            }
            let lower = path.lowercased()
            if lower.hasSuffix("/api/v1") {
                path = String(path.dropLast("/api/v1".count))
            } else if lower.hasSuffix("/api") {
                path = String(path.dropLast("/api".count))
            }
            components.path = path
        }

        components.fragment = nil
        // Keep query out of base URL
        components.query = nil

        guard var url = components.url else {
            throw ServerURLError.invalid
        }

        // Normalize trailing slash away from base
        var absolute = url.absoluteString
        while absolute.hasSuffix("/") {
            absolute.removeLast()
        }
        guard let normalized = URL(string: absolute) else {
            throw ServerURLError.invalid
        }
        url = normalized
        self.baseURL = url
    }

    /// `path` is relative to `/api/v1`, e.g. `/auth/login` or `auth/login`.
    func apiURL(path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? path : "/\(path)"
        let full = baseURL.absoluteString + "/api/v1" + cleaned
        return URL(string: full)!
    }

    /// Non-versioned paths such as `/health`.
    func rootURL(path: String) -> URL {
        let cleaned = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: baseURL.absoluteString + cleaned)!
    }
}
