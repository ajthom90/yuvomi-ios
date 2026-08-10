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
            "The server URL is invalid."
        case .unauthorized:
            "Sign-in failed or the session expired."
        case .forbidden:
            "You don’t have permission to do that."
        case .notFound:
            "The requested resource was not found."
        case .validation(let message):
            message
        case .server(let status, let message):
            message ?? "Server error (\(status))."
        case .decoding(let message):
            "Could not read the server response: \(message)"
        case .transport(let message):
            message
        case .offline:
            "You’re offline. Connect to your network and try again."
        case .unknown:
            "Something went wrong."
        }
    }

    static func from(statusCode: Int, body: Data?) -> APIError {
        let message = body.flatMap { data in
            (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error
        }
        switch statusCode {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 400, 422: return .validation(message ?? "Invalid request.")
        default: return .server(status: statusCode, message: message)
        }
    }
}

private struct APIErrorBody: Decodable {
    let error: String?
}
