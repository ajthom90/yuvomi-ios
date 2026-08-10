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

    // MARK: - Meals

    func fetchMealsWeek(referenceDate: String? = nil) async throws -> MealsWeekResponse {
        var components = URLComponents(url: server.apiURL(path: "/meals"), resolvingAgainstBaseURL: false)!
        if let referenceDate {
            components.queryItems = [URLQueryItem(name: "date", value: referenceDate)]
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await client.send(request, as: MealsWeekResponse.self)
    }

    func createMeal(date: String, mealType: String, title: String, recipeId: Int? = nil) async throws -> MealPlanEntry {
        var request = URLRequest(url: server.apiURL(path: "/meals"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "date": date,
            "meal_type": mealType,
            "title": title,
        ]
        if let recipeId { body["recipe_id"] = recipeId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<MealPlanEntry>.self).data
    }

    func deleteMeal(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/meals/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    func addMealIngredient(mealId: Int, name: String, quantity: String?) async throws -> MealIngredient {
        var request = URLRequest(url: server.apiURL(path: "/meals/\(mealId)/ingredients"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["name": name]
        if let quantity, !quantity.isEmpty { body["quantity"] = quantity }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<MealIngredient>.self).data
    }

    func transferMealToShopping(mealId: Int, listId: Int) async throws -> TransferResult {
        var request = URLRequest(url: server.apiURL(path: "/meals/\(mealId)/to-shopping-list"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["listId": listId])
        return try await client.send(request, as: APIData<TransferResult>.self).data
    }

    func transferWeekMealsToShopping(listId: Int, week: String) async throws -> TransferResult {
        var request = URLRequest(url: server.apiURL(path: "/meals/week-to-shopping-list"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["listId": listId, "week": week])
        return try await client.send(request, as: APIData<TransferResult>.self).data
    }

    // MARK: - Recipes

    func fetchRecipes() async throws -> [Recipe] {
        var request = URLRequest(url: server.apiURL(path: "/recipes"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<Recipe>.self).data
    }

    func createRecipe(title: String, notes: String?, ingredients: [[String: String]]) async throws -> Recipe {
        var request = URLRequest(url: server.apiURL(path: "/recipes"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["title": title]
        if let notes, !notes.isEmpty { body["notes"] = notes }
        if !ingredients.isEmpty { body["ingredients"] = ingredients }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<Recipe>.self).data
    }

    func updateRecipe(id: Int, title: String, notes: String?, ingredients: [[String: String]]) async throws -> Recipe {
        var request = URLRequest(url: server.apiURL(path: "/recipes/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["title": title, "ingredients": ingredients]
        if let notes { body["notes"] = notes }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<Recipe>.self).data
    }

    func deleteRecipe(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/recipes/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    func transferRecipeToShopping(recipeId: Int, listId: Int) async throws -> TransferResult {
        var request = URLRequest(url: server.apiURL(path: "/recipes/\(recipeId)/to-shopping-list"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["listId": listId])
        return try await client.send(request, as: APIData<TransferResult>.self).data
    }

    // MARK: - Pantry

    func fetchPantry() async throws -> PantryListResponse {
        var request = URLRequest(url: server.apiURL(path: "/pantry"))
        request.httpMethod = "GET"
        return try await client.send(request, as: PantryListResponse.self)
    }

    func createPantryItem(name: String, quantity: Double, unit: String?, locationId: Int?) async throws -> PantryItem {
        var request = URLRequest(url: server.apiURL(path: "/pantry"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["name": name, "quantity": quantity]
        if let unit, !unit.isEmpty { body["unit"] = unit }
        if let locationId { body["location_id"] = locationId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<PantryItem>.self).data
    }

    func patchPantryItem(id: Int, quantity: Double?, unit: String?, name: String?) async throws -> PantryItem {
        var request = URLRequest(url: server.apiURL(path: "/pantry/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if let quantity { body["quantity"] = quantity }
        if let unit { body["unit"] = unit }
        if let name { body["name"] = name }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<PantryItem>.self).data
    }

    func deletePantryItem(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/pantry/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    func importPantryToShopping(listId: Int, pantryItemIds: [Int]) async throws -> TransferResult {
        var request = URLRequest(url: server.apiURL(path: "/shopping/\(listId)/import-pantry"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let items = pantryItemIds.map { ["pantry_item_id": $0] }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["items": items])
        return try await client.send(request, as: APIData<TransferResult>.self).data
    }

    // MARK: - Budget

    func fetchBudgetEntries() async throws -> [BudgetEntry] {
        var request = URLRequest(url: server.apiURL(path: "/budget"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<BudgetEntry>.self).data
    }

    func fetchBudgetAccounts() async throws -> BudgetAccountsPayload {
        var request = URLRequest(url: server.apiURL(path: "/budget/accounts"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIData<BudgetAccountsPayload>.self).data
    }

    func fetchBudgetCategories() async throws -> [BudgetCategory] {
        var request = URLRequest(url: server.apiURL(path: "/budget/categories"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<BudgetCategory>.self).data
    }

    func fetchBudgetStats() async throws -> BudgetStatsPayload {
        var request = URLRequest(url: server.apiURL(path: "/budget/stats"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIData<BudgetStatsPayload>.self).data
    }

    func createBudgetAccount(name: String, type: String, startingBalance: Double) async throws -> BudgetAccount {
        var request = URLRequest(url: server.apiURL(path: "/budget/accounts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "type": type,
            "starting_balance": startingBalance,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<BudgetAccount>.self).data
    }

    func createBudgetEntry(title: String, amount: Double, category: String, date: String, accountId: Int?) async throws -> BudgetEntry {
        var request = URLRequest(url: server.apiURL(path: "/budget"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "title": title,
            "amount": amount,
            "category": category,
            "date": date,
        ]
        if let accountId { body["account_id"] = accountId }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<BudgetEntry>.self).data
    }

    func deleteBudgetEntry(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/budget/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }

    // MARK: - Split expenses

    func fetchSplitGroups() async throws -> [SplitGroup] {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/groups"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIList<SplitGroup>.self).data
    }

    func fetchSplitDashboard() async throws -> SplitDashboardPayload {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/dashboard"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIData<SplitDashboardPayload>.self).data
    }

    func createSplitGroup(name: String) async throws -> SplitGroup {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/groups"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        return try await client.send(request, as: APIData<SplitGroup>.self).data
    }

    func fetchSplitExpenses(groupId: Int) async throws -> [SplitExpense] {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/groups/\(groupId)/expenses"))
        request.httpMethod = "GET"
        return try await client.send(request, as: SplitExpensesPage.self).data
    }

    func fetchSplitBalances(groupId: Int) async throws -> SplitBalancesPayload {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/groups/\(groupId)/balances"))
        request.httpMethod = "GET"
        return try await client.send(request, as: APIData<SplitBalancesPayload>.self).data
    }

    func createSplitExpense(
        groupId: Int,
        title: String,
        amount: String,
        expenseDate: String,
        payerId: Int?,
        category: String?,
        splitMethod: String = "equal"
    ) async throws -> SplitExpense {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/groups/\(groupId)/expenses"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "title": title,
            "amount": amount,
            "expense_date": expenseDate,
            "split_method": splitMethod,
        ]
        if let payerId { body["payer_id"] = payerId }
        if let category, !category.isEmpty { body["category"] = category }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await client.send(request, as: APIData<SplitExpense>.self).data
    }

    func deleteSplitExpense(id: Int) async throws {
        var request = URLRequest(url: server.apiURL(path: "/split-expenses/expenses/\(id)"))
        request.httpMethod = "DELETE"
        try await client.sendVoid(request)
    }
}
