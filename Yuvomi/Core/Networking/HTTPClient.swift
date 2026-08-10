import Foundation

final class HTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let auth: AuthHeaderProviding?

    init(session: URLSession = .shared, auth: AuthHeaderProviding? = nil) {
        self.session = session
        self.auth = auth
    }

    func send<T: Decodable>(_ request: URLRequest, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let data = try await sendData(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(180)) } ?? "non-UTF8 body"
            throw APIError.decoding("\(error.localizedDescription) — body: \(snippet)")
        }
    }

    func sendData(_ request: URLRequest) async throws -> Data {
        var authorized = request
        if authorized.value(forHTTPHeaderField: "Accept") == nil {
            authorized.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        try await auth?.authorize(&authorized)

        let method = authorized.httpMethod ?? "GET"
        let urlString = authorized.url?.absoluteString ?? "(nil)"
        let hasAuth = authorized.value(forHTTPHeaderField: "Authorization") != nil
            || authorized.value(forHTTPHeaderField: "X-API-Key") != nil
        AuthLogger.log.info("HTTP \(method, privacy: .public) \(urlString, privacy: .public) authHeader=\(hasAuth)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: authorized)
        } catch {
            let ns = error as NSError
            AuthLogger.log.error("HTTP transport error: \(ns.domain, privacy: .public) \(ns.code) \(ns.localizedDescription, privacy: .public)")
            if ns.domain == NSURLErrorDomain {
                if ns.code == NSURLErrorNotConnectedToInternet || ns.code == NSURLErrorNetworkConnectionLost {
                    throw APIError.offline
                }
                throw APIError.transport(ns.localizedDescription)
            }
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        AuthLogger.log.info("HTTP status=\(http.statusCode) bytes=\(data.count)")

        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? ""
            AuthLogger.log.error("HTTP failure body=\(snippet, privacy: .public)")
            throw APIError.from(statusCode: http.statusCode, body: data)
        }

        // Capture CSRF from headers when present (session mode).
        if let csrf = http.value(forHTTPHeaderField: "X-CSRF-Token"), !csrf.isEmpty {
            await MainActor.run {
                if let store = auth as? AuthSessionStore {
                    try? store.saveCSRFToken(csrf)
                }
            }
        }

        return data
    }

    func sendVoid(_ request: URLRequest) async throws {
        _ = try await sendData(request)
    }
}
