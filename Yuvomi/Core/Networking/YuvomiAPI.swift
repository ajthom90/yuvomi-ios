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

    // MARK: - Tasks

    func fetchTasks() async throws -> [TaskItem] {
        var request = URLRequest(url: server.apiURL(path: "/tasks"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<TaskItem>.self).data
    }

    func createTask(title: String, status: String = "open", priority: String = "medium", dueDate: String? = nil) async throws -> TaskItem {
        var request = URLRequest(url: server.apiURL(path: "/tasks"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "title": title,
            "status": status,
            "priority": priority,
        ]
        if let dueDate, !dueDate.isEmpty {
            body["due_date"] = dueDate
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<TaskItem>.self).data
    }

    func updateTaskStatus(id: Int, status: String) async throws {
        var request = URLRequest(url: server.apiURL(path: "/tasks/\(id)/status"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["status": status])
        try await client.sendVoid(request)
    }

    func deleteTask(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/tasks/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    // MARK: - Shopping

    func fetchShoppingLists() async throws -> [ShoppingList] {
        var request = URLRequest(url: server.apiURL(path: "/shopping"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<ShoppingList>.self).data
    }

    func createShoppingList(name: String) async throws -> ShoppingList {
        var request = URLRequest(url: server.apiURL(path: "/shopping"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        return try await client.send(request, as: APIData<ShoppingList>.self).data
    }

    func fetchShoppingItems(listId: Int) async throws -> ShoppingItemsResponse {
        var request = URLRequest(url: server.apiURL(path: "/shopping/\(listId)/items"))
        request.httpMethod = "GET"
        return try await client.send(request, as: ShoppingItemsResponse.self)
    }

    func addShoppingItem(listId: Int, name: String, quantity: String? = nil) async throws -> ShoppingItem {
        var request = URLRequest(url: server.apiURL(path: "/shopping/\(listId)/items"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["name": name]
        if let quantity, !quantity.isEmpty {
            body["quantity"] = quantity
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<ShoppingItem>.self).data
    }

    func setShoppingItemChecked(itemId: Int, isChecked: Bool) async throws -> ShoppingItem {
        var request = URLRequest(url: server.apiURL(path: "/shopping/items/\(itemId)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["is_checked": isChecked])
        return try await client.send(request, as: APIData<ShoppingItem>.self).data
    }

    func deleteShoppingItem(itemId: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/shopping/items/\(itemId)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    // MARK: - Calendar

    func fetchCalendarEvents(from: String, to: String) async throws -> [CalendarEvent] {
        var components = URLComponents(url: server.apiURL(path: "/calendar"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<CalendarEvent>.self).data
    }

    func fetchUpcomingEvents() async throws -> [CalendarEvent] {
        var request = URLRequest(url: server.apiURL(path: "/calendar/upcoming"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<CalendarEvent>.self).data
    }

    func createCalendarEvent(title: String, start: String, end: String, allDay: Bool) async throws -> CalendarEvent {
        var request = URLRequest(url: server.apiURL(path: "/calendar"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "title": title,
            "start_datetime": start,
            "end_datetime": end,
            "all_day": allDay ? 1 : 0,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<CalendarEvent>.self).data
    }

    func deleteCalendarEvent(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/calendar/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }
}
