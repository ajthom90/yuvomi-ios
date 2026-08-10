import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var title = ""
    @State private var notes = ""
    @State private var ingredientLines = ""
    @State private var recipeForShop: Recipe?
    @State private var showListPicker = false

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = RecipesViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Recipes")
    }

    @ViewBuilder
    private func content(_ vm: RecipesViewModel) -> some View {
        List {
            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            if let status = vm.statusMessage {
                Section { Text(status).foregroundStyle(YuvomiColors.kitchen).font(.footnote) }
            }

            if vm.recipes.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No recipes",
                    systemImage: "book",
                    description: Text("Save family favorites and send ingredients to shopping.")
                )
            } else {
                ForEach(vm.recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title).font(.body.weight(.medium))
                            HStack {
                                Text("\(recipe.ingredients.count) ingredients")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let source = recipe.source, source != "native" {
                                    Text(source).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.delete(recipe) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        if !vm.shoppingLists.isEmpty {
                            Button {
                                recipeForShop = recipe
                                showListPicker = true
                            } label: { Label("Shop", systemImage: "cart") }
                            .tint(YuvomiColors.kitchen)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    Section("Ingredients (one per line)") {
                        TextField("Flour | 2 cups", text: $ingredientLines, axis: .vertical)
                            .lineLimit(4...10)
                            .font(.body.monospaced())
                    }
                }
                .navigationTitle("New recipe")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await vm.addRecipe(title: title, notes: notes, ingredientLines: ingredientLines)
                                title = ""; notes = ""; ingredientLines = ""
                                showAdd = false
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .confirmationDialog("Shopping list", isPresented: $showListPicker, titleVisibility: .visible) {
            ForEach(vm.shoppingLists) { list in
                Button(list.name) {
                    if let recipe = recipeForShop {
                        Task { await vm.sendToShopping(recipe, listId: list.id) }
                    }
                    recipeForShop = nil
                }
            }
            Button("Cancel", role: .cancel) { recipeForShop = nil }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        List {
            if let notes = recipe.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
            Section("Ingredients") {
                if recipe.ingredients.isEmpty {
                    Text("No ingredients").foregroundStyle(.secondary)
                } else {
                    ForEach(recipe.ingredients) { ing in
                        HStack {
                            Text(ing.name)
                            Spacer()
                            if let q = ing.quantity, !q.isEmpty {
                                Text(q).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !recipe.mealTypes.isEmpty {
                Section("Meal types") {
                    Text(recipe.mealTypes.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(recipe.title)
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: RecipesViewModel?
}
