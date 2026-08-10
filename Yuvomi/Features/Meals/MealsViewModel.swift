import Foundation

@MainActor
final class MealsViewModel: ObservableObject {
    @Published private(set) var meals: [MealPlanEntry] = []
    @Published private(set) var weekStart: String = ""
    @Published private(set) var weekEnd: String = ""
    @Published private(set) var shoppingLists: [ShoppingList] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var referenceDate = Date()

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var mealsByDate: [(date: String, meals: [MealPlanEntry])] {
        let grouped = Dictionary(grouping: meals, by: \.date)
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    private var dayFormatter: DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            let ref = dayFormatter.string(from: referenceDate)
            let week = try await api.fetchMealsWeek(referenceDate: ref)
            meals = week.data
            weekStart = week.weekStart ?? ""
            weekEnd = week.weekEnd ?? ""
            shoppingLists = (try? await api.fetchShoppingLists()) ?? shoppingLists
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func shiftWeek(by weeks: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: weeks * 7, to: referenceDate) {
            referenceDate = d
        }
    }

    func addMeal(date: String, type: MealType, title: String, recipeId: Int?) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            _ = try await api.createMeal(date: date, mealType: type.rawValue, title: trimmed, recipeId: recipeId)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deleteMeal(_ meal: MealPlanEntry) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteMeal(id: meal.id)
            meals.removeAll { $0.id == meal.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendMealToShopping(_ meal: MealPlanEntry, listId: Int) async {
        do {
            let api = try dependencies.makeAPI()
            let result = try await api.transferMealToShopping(mealId: meal.id, listId: listId)
            statusMessage = "Sent \(result.transferred ?? 0) item(s) to shopping"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendWeekToShopping(listId: Int) async {
        let week = weekStart.isEmpty ? dayFormatter.string(from: referenceDate) : weekStart
        do {
            let api = try dependencies.makeAPI()
            let result = try await api.transferWeekMealsToShopping(listId: listId, week: week)
            statusMessage = "Week export: \(result.transferred ?? 0) transferred, \(result.skipped ?? 0) skipped"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
