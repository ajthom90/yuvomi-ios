import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAddEntry = false
    @State private var showAddAccount = false

    // Entry form
    @State private var entryTitle = ""
    @State private var entryAmount = ""
    @State private var entryIsExpense = true
    @State private var entryCategory = "food"
    @State private var entryDate = Date()
    @State private var entryAccountId: Int?

    // Account form
    @State private var accountName = ""
    @State private var accountType = "checking"
    @State private var accountBalance = "0"

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = BudgetViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Budget")
    }

    @ViewBuilder
    private func content(_ vm: BudgetViewModel) -> some View {
        List {
            Section {
                Picker("Section", selection: Binding(
                    get: { vm.segment },
                    set: { vm.segment = $0 }
                )) {
                    ForEach(BudgetViewModel.Segment.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }

            switch vm.segment {
            case .transactions:
                transactions(vm)
            case .accounts:
                accounts(vm)
            case .summary:
                summary(vm)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add transaction") { showAddEntry = true }
                    Button("Add account") { showAddAccount = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .sheet(isPresented: $showAddEntry) { addEntrySheet(vm) }
        .sheet(isPresented: $showAddAccount) { addAccountSheet(vm) }
    }

    @ViewBuilder
    private func transactions(_ vm: BudgetViewModel) -> some View {
        if vm.entries.isEmpty && !vm.isLoading {
            ContentUnavailableView("No transactions", systemImage: "banknote", description: Text("Track income and expenses."))
        } else {
            ForEach(vm.entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).font(.body.weight(.medium))
                        Text("\(entry.category) · \(entry.date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatMoney(entry.amount))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(entry.isExpense ? .red : YuvomiColors.money)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await vm.deleteEntry(entry) }
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    @ViewBuilder
    private func accounts(_ vm: BudgetViewModel) -> some View {
        Section {
            LabeledContent("Net worth") {
                Text(formatMoney(vm.netWorth))
                    .font(.headline)
                    .foregroundStyle(YuvomiColors.money)
            }
        }
        if vm.accounts.isEmpty {
            ContentUnavailableView("No accounts", systemImage: "building.columns")
        } else {
            ForEach(vm.accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        Text(account.name).font(.body.weight(.medium))
                        Text(account.type.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatMoney(account.currentBalance))
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func summary(_ vm: BudgetViewModel) -> some View {
        if let stats = vm.stats {
            Section("This month") {
                LabeledContent("Income") {
                    Text(formatMoney(stats.income)).foregroundStyle(YuvomiColors.money)
                }
                LabeledContent("Expenses") {
                    Text(formatMoney(abs(stats.expenses))).foregroundStyle(.red)
                }
                LabeledContent("Balance") {
                    Text(formatMoney(stats.balance)).fontWeight(.semibold)
                }
            }
        } else {
            ContentUnavailableView("No stats yet", systemImage: "chart.bar")
        }
    }

    private func addEntrySheet(_ vm: BudgetViewModel) -> some View {
        NavigationStack {
            Form {
                TextField("Title", text: $entryTitle)
                TextField("Amount", text: $entryAmount)
                    .keyboardType(.decimalPad)
                Picker("Kind", selection: $entryIsExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)
                Picker("Category", selection: $entryCategory) {
                    let cats = entryIsExpense
                        ? (vm.expenseCategories.isEmpty ? defaultExpenseCats : vm.expenseCategories)
                        : (vm.incomeCategories.isEmpty ? defaultIncomeCats : vm.incomeCategories)
                    ForEach(cats) { cat in
                        Text(cat.displayName).tag(cat.key)
                    }
                }
                DatePicker("Date", selection: $entryDate, displayedComponents: .date)
                if !vm.accounts.isEmpty {
                    Picker("Account", selection: Binding(
                        get: { entryAccountId ?? vm.accounts.first?.id },
                        set: { entryAccountId = $0 }
                    )) {
                        Text("None").tag(Optional<Int>.none)
                        ForEach(vm.accounts) { a in
                            Text(a.name).tag(Optional(a.id))
                        }
                    }
                }
            }
            .navigationTitle("Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let amount = Double(entryAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
                            await vm.addEntry(
                                title: entryTitle,
                                amount: amount,
                                isExpense: entryIsExpense,
                                category: entryCategory,
                                date: entryDate,
                                accountId: entryAccountId
                            )
                            entryTitle = ""; entryAmount = ""
                            showAddEntry = false
                        }
                    }
                    .disabled(entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if entryIsExpense, entryCategory.isEmpty || !vm.expenseCategories.map(\.key).contains(entryCategory) {
                    entryCategory = vm.expenseCategories.first?.key ?? "food"
                }
            }
        }
    }

    private func addAccountSheet(_ vm: BudgetViewModel) -> some View {
        NavigationStack {
            Form {
                TextField("Name", text: $accountName)
                Picker("Type", selection: $accountType) {
                    ForEach(["checking", "savings", "cash", "credit", "investment", "other"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                TextField("Starting balance", text: $accountBalance)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddAccount = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let bal = Double(accountBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
                            await vm.addAccount(name: accountName, type: accountType, startingBalance: bal)
                            accountName = ""; accountBalance = "0"
                            showAddAccount = false
                        }
                    }
                    .disabled(accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var defaultExpenseCats: [BudgetCategory] {
        ["food", "housing", "transport", "leisure", "subscriptions"].map {
            BudgetCategory(key: $0, name: $0, type: "expense", label: $0.capitalized)
        }
    }

    private var defaultIncomeCats: [BudgetCategory] {
        [BudgetCategory(key: "Erwerbseinkommen", name: "Earned Income", type: "income", label: "Earned Income")]
    }

    private func formatMoney(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: BudgetViewModel?
}
