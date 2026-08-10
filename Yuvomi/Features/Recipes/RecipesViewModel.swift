import Foundation

@MainActor
final class RecipesViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var shoppingLists: [ShoppingList] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            recipes = try await api.fetchRecipes()
            shoppingLists = (try? await api.fetchShoppingLists()) ?? []
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addRecipe(title: String, notes: String, ingredientLines: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ingredients = parseIngredients(ingredientLines)
        do {
            let api = try dependencies.makeAPI()
            // Create then PUT ingredients (create may ignore ingredient array).
            var created = try await api.createRecipe(title: trimmed, notes: notes, ingredients: ingredients)
            if !ingredients.isEmpty {
                created = try await api.updateRecipe(
                    id: created.id,
                    title: trimmed,
                    notes: notes.isEmpty ? nil : notes,
                    ingredients: ingredients
                )
            }
            recipes.insert(created, at: 0)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ recipe: Recipe) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteRecipe(id: recipe.id)
            recipes.removeAll { $0.id == recipe.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func sendToShopping(_ recipe: Recipe, listId: Int) async {
        do {
            let api = try dependencies.makeAPI()
            let result = try await api.transferRecipeToShopping(recipeId: recipe.id, listId: listId)
            statusMessage = "Sent \(result.transferred ?? 0) ingredient(s) to shopping"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Lines like "2 cups Flour" or "Flour | 2 cups"
    private func parseIngredients(_ text: String) -> [[String: String]] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                if line.contains("|") {
                    let parts = line.split(separator: "|", maxSplits: 1).map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    if parts.count == 2 {
                        return ["name": parts[0], "quantity": parts[1]]
                    }
                }
                return ["name": line, "quantity": ""]
            }
    }
}
