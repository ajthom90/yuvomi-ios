import SwiftUI

struct SplitExpensesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAddGroup = false
    @State private var showAddExpense = false
    @State private var groupName = ""
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var expenseDate = Date()
    @State private var expenseCategory = "general"

    private let categories = [
        "groceries", "rent", "utilities", "travel", "shopping",
        "subscriptions", "health", "home", "general",
    ]

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = SplitExpensesViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Split expenses")
    }

    @ViewBuilder
    private func content(_ vm: SplitExpensesViewModel) -> some View {
        List {
            if !vm.groups.isEmpty {
                Section("Group") {
                    Picker("Group", selection: Binding(
                        get: { vm.selectedGroupId ?? vm.groups.first?.id ?? 0 },
                        set: { id in Task { await vm.loadGroup(id) } }
                    )) {
                        ForEach(vm.groups) { g in
                            Text(g.name).tag(g.id)
                        }
                    }
                }
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }

            if let balances = vm.balances, !balances.simplifiedDebts.isEmpty {
                Section("Settle up") {
                    ForEach(balances.simplifiedDebts) { row in
                        HStack {
                            Text(row.displayName ?? "Member")
                            Spacer()
                            Text("\(row.amount ?? "0") \(row.currency ?? "")")
                                .foregroundStyle(YuvomiColors.money)
                        }
                    }
                }
            }

            Section("Expenses") {
                if vm.expenses.isEmpty && !vm.isLoading {
                    Text("No expenses in this group yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.title).font(.body.weight(.medium))
                                Text("\(expense.payerName ?? "Someone") · \(expense.expenseDate ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(expense.amount) \(expense.currency ?? "")")
                                .font(.body.monospacedDigit())
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.deleteExpense(expense) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add expense") { showAddExpense = true }
                        .disabled(vm.selectedGroupId == nil)
                    Button("New group") { showAddGroup = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .sheet(isPresented: $showAddGroup) {
            NavigationStack {
                Form {
                    TextField("Group name", text: $groupName)
                }
                .navigationTitle("New group")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddGroup = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                await vm.createGroup(name: groupName)
                                groupName = ""
                                showAddGroup = false
                            }
                        }
                        .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddExpense) {
            NavigationStack {
                Form {
                    TextField("Title", text: $expenseTitle)
                    TextField("Amount", text: $expenseAmount)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $expenseDate, displayedComponents: .date)
                    Picker("Category", selection: $expenseCategory) {
                        ForEach(categories, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                .navigationTitle("Expense")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddExpense = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await vm.addExpense(
                                    title: expenseTitle,
                                    amount: expenseAmount,
                                    date: expenseDate,
                                    category: expenseCategory
                                )
                                expenseTitle = ""; expenseAmount = ""
                                showAddExpense = false
                            }
                        }
                        .disabled(expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || expenseAmount.isEmpty)
                    }
                }
            }
        }
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: SplitExpensesViewModel?
}
