import Foundation

@MainActor
final class SplitExpensesViewModel: ObservableObject {
    @Published private(set) var groups: [SplitGroup] = []
    @Published private(set) var recentExpenses: [SplitExpense] = []
    @Published var selectedGroupId: Int?
    @Published private(set) var expenses: [SplitExpense] = []
    @Published private(set) var balances: SplitBalancesPayload?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var selectedGroup: SplitGroup? {
        groups.first { $0.id == selectedGroupId }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            groups = try await api.fetchSplitGroups()
            if let dash = try? await api.fetchSplitDashboard() {
                recentExpenses = dash.recentExpenses
                if groups.isEmpty { groups = dash.groups }
            }
            if selectedGroupId == nil {
                selectedGroupId = groups.first?.id
            }
            if let id = selectedGroupId {
                await loadGroup(id)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadGroup(_ id: Int) async {
        selectedGroupId = id
        do {
            let api = try dependencies.makeAPI()
            expenses = try await api.fetchSplitExpenses(groupId: id)
            balances = try await api.fetchSplitBalances(groupId: id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func createGroup(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let group = try await api.createSplitGroup(name: trimmed)
            groups.insert(group, at: 0)
            await loadGroup(group.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addExpense(title: String, amount: String, date: Date, category: String) async {
        guard let groupId = selectedGroupId else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedAmount: String = {
            let cleaned = amount.replacingOccurrences(of: ",", with: ".")
            if let d = Double(cleaned) {
                return String(format: "%.2f", d)
            }
            return cleaned
        }()
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        do {
            let api = try dependencies.makeAPI()
            let me = try? await api.me()
            _ = try await api.createSplitExpense(
                groupId: groupId,
                title: trimmed,
                amount: normalizedAmount,
                expenseDate: df.string(from: date),
                payerId: me?.user.id,
                category: category
            )
            await loadGroup(groupId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func deleteExpense(_ expense: SplitExpense) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteSplitExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
