import Foundation

@MainActor
final class PantryViewModel: ObservableObject {
    @Published private(set) var items: [PantryItem] = []
    @Published private(set) var locations: [PantryLocation] = []
    @Published private(set) var shoppingLists: [ShoppingList] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all, low, out
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All"
            case .low: "Low"
            case .out: "Out"
            }
        }
    }

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var visibleItems: [PantryItem] {
        switch filter {
        case .all: items
        case .low: items.filter(\.isLow)
        case .out: items.filter(\.isOut)
        }
    }

    var grouped: [(location: String, items: [PantryItem])] {
        let dict = Dictionary(grouping: visibleItems) {
            $0.locationName?.isEmpty == false ? $0.locationName! : "Unassigned"
        }
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            let response = try await api.fetchPantry()
            items = response.data
            locations = response.locations
            shoppingLists = (try? await api.fetchShoppingLists()) ?? []
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addItem(name: String, quantity: Double, unit: String?, locationId: Int?) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let item = try await api.createPantryItem(
                name: trimmed,
                quantity: quantity,
                unit: unit,
                locationId: locationId
            )
            // Reload for location_name enrichment
            await load()
            _ = item
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func adjustQuantity(_ item: PantryItem, delta: Double) async {
        let next = max(0, item.quantity + delta)
        do {
            let api = try dependencies.makeAPI()
            let updated = try await api.patchPantryItem(id: item.id, quantity: next, unit: nil, name: nil)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = updated
                // preserve location name if patch response omits it
                if items[idx].locationName == nil {
                    items[idx].locationName = item.locationName
                }
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ item: PantryItem) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deletePantryItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendToShopping(itemIds: [Int], listId: Int) async {
        guard !itemIds.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let result = try await api.importPantryToShopping(listId: listId, pantryItemIds: itemIds)
            statusMessage = "Shopping: added \(result.added ?? 0), skipped \(result.skipped ?? 0)"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
