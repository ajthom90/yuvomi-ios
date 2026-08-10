import Foundation

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published private(set) var lists: [ShoppingList] = []
    @Published var selectedListId: Int?
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var hideChecked = false

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var selectedList: ShoppingList? {
        lists.first { $0.id == selectedListId }
    }

    var visibleItems: [ShoppingItem] {
        let base = items.sorted { lhs, rhs in
            if lhs.isChecked != rhs.isChecked { return !lhs.isChecked && rhs.isChecked }
            if lhs.category != rhs.category {
                return (lhs.category ?? "") < (rhs.category ?? "")
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        return hideChecked ? base.filter { !$0.isChecked } : base
    }

    var groupedItems: [(category: String, items: [ShoppingItem])] {
        let dict = Dictionary(grouping: visibleItems) { $0.category?.isEmpty == false ? $0.category! : "Other" }
        return dict.keys.sorted().map { key in
            (key, dict[key] ?? [])
        }
    }

    func loadLists() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            lists = try await api.fetchShoppingLists()
            if selectedListId == nil {
                selectedListId = lists.first?.id
            }
            if let id = selectedListId {
                await loadItems(listId: id)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadItems(listId: Int) async {
        do {
            let api = try dependencies.makeAPI()
            let response = try await api.fetchShoppingItems(listId: listId)
            items = response.data
            selectedListId = listId
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addList(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let list = try await api.createShoppingList(name: trimmed)
            lists.append(list)
            selectedListId = list.id
            items = []
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addItem(name: String, quantity: String?) async {
        guard let listId = selectedListId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let item = try await api.addShoppingItem(listId: listId, name: trimmed, quantity: quantity)
            items.append(item)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func toggle(_ item: ShoppingItem) async {
        do {
            let api = try dependencies.makeAPI()
            let updated = try await api.setShoppingItemChecked(itemId: item.id, isChecked: !item.isChecked)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = updated
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ item: ShoppingItem) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteShoppingItem(itemId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
