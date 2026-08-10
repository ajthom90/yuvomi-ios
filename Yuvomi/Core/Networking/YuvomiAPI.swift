import Foundation

struct YuvomiAPI {
    let client: HTTPClient
    let server: ServerURL

    init(client: HTTPClient, server: ServerURL) {
        self.client = client
        self.server = server
    }

    // MARK: - Public bootstrap

    func fetchVersion() async throws -> VersionInfo {
        var request = URLRequest(url: server.apiURL(path: "/version"))
        request.httpMethod = "GET"
        return try await client.send(request, as: VersionInfo.self)
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> LoginResponse {
        var request = URLRequest(url: server.apiURL(path: "/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: LoginResponse.self)
    }

    func me() async throws -> MeResponse {
        var request = URLRequest(url: server.apiURL(path: "/auth/me"))
        request.httpMethod = "GET"
        return try await client.send(request, as: MeResponse.self)
    }

    func logout() async throws {
        var request = URLRequest(url: server.apiURL(path: "/auth/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        try await client.sendVoid(request)
    }

    // MARK: - Dashboard

    func fetchDashboardData() async throws -> Data {
        var request = URLRequest(url: server.apiURL(path: "/dashboard"))
        request.httpMethod = "GET"
        return try await client.sendData(request)
    }
}
