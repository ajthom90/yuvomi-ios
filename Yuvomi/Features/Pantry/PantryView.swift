import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit = ""
    @State private var locationId: Int?
    @State private var showShopPicker = false
    @State private var shopItemIds: [Int] = []

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = PantryViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Pantry")
    }

    @ViewBuilder
    private func content(_ vm: PantryViewModel) -> some View {
        List {
            Section {
                Picker("Filter", selection: Binding(
                    get: { vm.filter },
                    set: { vm.filter = $0 }
                )) {
                    ForEach(PantryViewModel.Filter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            if let status = vm.statusMessage {
                Section { Text(status).foregroundStyle(YuvomiColors.kitchen).font(.footnote) }
            }

            if vm.visibleItems.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "Pantry is empty",
                    systemImage: "cabinet",
                    description: Text("Track stock, expiry, and send low items to shopping.")
                )
            } else {
                ForEach(vm.grouped, id: \.location) { group in
                    Section(group.location) {
                        ForEach(group.items) { item in
                            PantryRow(
                                item: item,
                                onMinus: { Task { await vm.adjustQuantity(item, delta: -1) } },
                                onPlus: { Task { await vm.adjustQuantity(item, delta: 1) } }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await vm.delete(item) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                if !vm.shoppingLists.isEmpty {
                                    Button {
                                        shopItemIds = [item.id]
                                        showShopPicker = true
                                    } label: { Label("Shop", systemImage: "cart") }
                                    .tint(YuvomiColors.kitchen)
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            if !vm.shoppingLists.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        shopItemIds = vm.visibleItems.filter(\.isLow).map(\.id)
                        showShopPicker = true
                    } label: {
                        Image(systemName: "cart.badge.plus")
                    }
                    .disabled(vm.visibleItems.filter(\.isLow).isEmpty)
                }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Name", text: $name)
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)
                    TextField("Unit", text: $unit)
                    if !vm.locations.isEmpty {
                        Picker("Location", selection: Binding(
                            get: { locationId ?? vm.locations.first?.id },
                            set: { locationId = $0 }
                        )) {
                            ForEach(vm.locations) { loc in
                                Text(loc.name).tag(Optional(loc.id))
                            }
                        }
                    }
                }
                .navigationTitle("Add stock")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                let qty = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 1
                                await vm.addItem(
                                    name: name,
                                    quantity: qty,
                                    unit: unit.isEmpty ? nil : unit,
                                    locationId: locationId ?? vm.locations.first?.id
                                )
                                name = ""; quantityText = "1"; unit = ""
                                showAdd = false
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Shopping list", isPresented: $showShopPicker, titleVisibility: .visible) {
            ForEach(vm.shoppingLists) { list in
                Button(list.name) {
                    Task { await vm.sendToShopping(itemIds: shopItemIds, listId: list.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PantryRow: View {
    let item: PantryItem
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(qtyLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if item.isOut {
                        badge("Out", .red)
                    } else if item.isLow {
                        badge("Low", .orange)
                    }
                    if let exp = item.expiresOn {
                        Text("BB \(exp)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
            .foregroundStyle(YuvomiColors.kitchen)
            .font(.title3)
        }
    }

    private var qtyLabel: String {
        let q = item.quantity
        let qText = q.rounded() == q ? String(Int(q)) : String(format: "%g", q)
        if let unit = item.unit, !unit.isEmpty { return "\(qText) \(unit)" }
        return qText
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: PantryViewModel?
}
