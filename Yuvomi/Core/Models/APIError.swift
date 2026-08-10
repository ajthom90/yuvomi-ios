import Foundation

enum APIError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case unauthorized
    case forbidden
    case notFound
    case validation(String)
    case server(status: Int, message: String?)
    case decoding(String)
    case transport(String)
    case offline
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .unauthorized:
            return "Sign-in failed or the session expired. Check username/password or paste a fresh API token from Yuvomi → Settings → API Tokens."
        case .forbidden:
            return "You don’t have permission to do that. If you used a scoped API token, create an unrestricted token for the iOS app."
        case .notFound:
            return "The requested resource was not found. Check the server URL (include any path prefix, e.g. https://host/yuvomi)."
        case .validation(let message):
            return message
        case .server(let status, let message):
            return message.map { "\($0) (HTTP \(status))" } ?? "Server error (HTTP \(status))."
        case .decoding(let message):
            return "Could not read the server response: \(message)"
        case .transport(let message):
            if message.localizedCaseInsensitiveContains("SSL")
                || message.localizedCaseInsensitiveContains("certificate")
                || message.localizedCaseInsensitiveContains("secure connection") {
                return "TLS/certificate error: \(message). Use a trusted certificate, or HTTP on your LAN while testing."
            }
            return message
        case .offline:
            return "You’re offline. Connect to your network and try again."
        case .unknown:
            return "Something went wrong."
        }
    }

    static func from(statusCode: Int, body: Data?) -> APIError {
        let message = Self.message(from: body)
        switch statusCode {
        case 401:
            return .validation(message ?? "Invalid credentials or expired token.")
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 400, 422:
            return .validation(message ?? "Invalid request.")
        case 429:
            return .server(status: statusCode, message: message ?? "Too many attempts. Wait a moment and try again.")
        default:
            return .server(status: statusCode, message: message)
        }
    }

    static func message(from body: Data?) -> String? {
        guard let body, !body.isEmpty else { return nil }
        if let parsed = try? JSONDecoder().decode(APIErrorBody.self, from: body),
           let error = parsed.error, !error.isEmpty {
            return error
        }
        if let text = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return String(text.prefix(200))
        }
        return nil
    }
}

private struct APIErrorBody: Decodable {
    let error: String?
}
