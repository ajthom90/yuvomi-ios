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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: authorized)
        } catch {
            let ns = error as NSError
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

        guard (200..<300).contains(http.statusCode) else {
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
