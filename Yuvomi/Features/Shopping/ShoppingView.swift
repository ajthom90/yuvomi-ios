import SwiftUI

struct ShoppingView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAddItem = false
    @State private var showAddList = false
    @State private var newItemName = ""
    @State private var newItemQty = ""
    @State private var newListName = ""

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = ShoppingViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Shopping")
    }

    @ViewBuilder
    private func content(_ vm: ShoppingViewModel) -> some View {
        List {
            if !vm.lists.isEmpty {
                Section {
                    Picker("List", selection: Binding(
                        get: { vm.selectedListId ?? vm.lists.first?.id ?? 0 },
                        set: { id in Task { await vm.loadItems(listId: id) } }
                    )) {
                        ForEach(vm.lists) { list in
                            Text(list.name).tag(list.id)
                        }
                    }
                    Toggle("Hide checked", isOn: Binding(
                        get: { vm.hideChecked },
                        set: { vm.hideChecked = $0 }
                    ))
                }
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }

            if vm.lists.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No shopping lists",
                    systemImage: "cart",
                    description: Text("Create a list to get started.")
                )
            } else if vm.visibleItems.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "List is empty",
                    systemImage: "cart",
                    description: Text("Add milk, eggs, and the rest.")
                )
            } else {
                ForEach(vm.groupedItems, id: \.category) { group in
                    Section(group.category) {
                        ForEach(group.items) { item in
                            ShoppingItemRow(item: item) {
                                Task { await vm.toggle(item) }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(item) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add item") { showAddItem = true }
                    Button("New list") { showAddList = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await vm.loadLists() }
        .task { await vm.loadLists() }
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                Form {
                    TextField("Item", text: $newItemName)
                    TextField("Quantity (optional)", text: $newItemQty)
                }
                .navigationTitle("Add item")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddItem = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                await vm.addItem(name: newItemName, quantity: newItemQty)
                                newItemName = ""
                                newItemQty = ""
                                showAddItem = false
                            }
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddList) {
            NavigationStack {
                Form {
                    TextField("List name", text: $newListName)
                }
                .navigationTitle("New list")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddList = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                await vm.addList(name: newListName)
                                newListName = ""
                                showAddList = false
                            }
                        }
                        .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? YuvomiColors.kitchen : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if let qty = item.quantity, !qty.isEmpty {
                        Text(qty).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: ShoppingViewModel?
}
