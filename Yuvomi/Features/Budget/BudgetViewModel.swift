import Foundation

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var entries: [BudgetEntry] = []
    @Published private(set) var accounts: [BudgetAccount] = []
    @Published private(set) var categories: [BudgetCategory] = []
    @Published private(set) var stats: BudgetStatsTotals?
    @Published private(set) var netWorth: Double = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var segment: Segment = .transactions

    enum Segment: String, CaseIterable, Identifiable {
        case transactions, accounts, summary
        var id: String { rawValue }
        var title: String {
            switch self {
            case .transactions: "Transactions"
            case .accounts: "Accounts"
            case .summary: "Summary"
            }
        }
    }

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var expenseCategories: [BudgetCategory] {
        let knownExpense = Set(["education", "financial_other", "food", "housing", "leisure", "personal_health", "shopping_clothing", "subscriptions", "transport"])
        return categories.filter { cat in
            if let type = cat.type { return type == "expense" }
            return knownExpense.contains(cat.key)
        }
    }

    var incomeCategories: [BudgetCategory] {
        categories.filter { $0.type == "income" || !expenseCategories.contains(where: { $0.key == $0.key && expenseCategories.map(\.key).contains($0.key) }) }
            .filter { cat in
                if let type = cat.type { return type == "income" }
                return !Set(["education", "financial_other", "food", "housing", "leisure", "personal_health", "shopping_clothing", "subscriptions", "transport"]).contains(cat.key)
            }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            async let e = api.fetchBudgetEntries()
            async let a = api.fetchBudgetAccounts()
            async let c = api.fetchBudgetCategories()
            async let s = api.fetchBudgetStats()
            entries = try await e
            let accountsPayload = try await a
            accounts = accountsPayload.accounts.filter { !$0.archived }
            netWorth = accountsPayload.netWorth
            categories = try await c
            stats = try await s.totals
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addEntry(title: String, amount: Double, isExpense: Bool, category: String, date: Date, accountId: Int?) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let signed = isExpense ? -abs(amount) : abs(amount)
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        do {
            let api = try dependencies.makeAPI()
            _ = try await api.createBudgetEntry(
                title: trimmed,
                amount: signed,
                category: category,
                date: df.string(from: date),
                accountId: accountId
            )
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addAccount(name: String, type: String, startingBalance: Double) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            _ = try await api.createBudgetAccount(name: trimmed, type: type, startingBalance: startingBalance)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deleteEntry(_ entry: BudgetEntry) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteBudgetEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
