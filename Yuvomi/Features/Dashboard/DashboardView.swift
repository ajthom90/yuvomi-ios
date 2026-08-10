import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var authStore: AuthSessionStore
    @StateObject private var viewModelHolder = ViewModelHolder()

    var body: some View {
        Group {
            if let viewModel = viewModelHolder.model {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        viewModelHolder.model = DashboardViewModel(dependencies: dependencies)
                    }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: DashboardViewModel) -> some View {
        List {
            Section {
                Text(greeting)
                    .font(.title2.bold())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
            }

            if viewModel.isShowingCached, let cacheDate = viewModel.cacheDate {
                Section {
                    Label(
                        "Offline · last updated \(cacheDate.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "wifi.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }

            if let error = viewModel.errorMessage, viewModel.payload == nil {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await viewModel.load() } }
                }
            }

            if let p = viewModel.payload {
                if !p.urgentTasks.isEmpty {
                    Section("Tasks") {
                        ForEach(p.urgentTasks.prefix(5)) { task in
                            HStack {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(YuvomiColors.work)
                                VStack(alignment: .leading) {
                                    Text(task.title)
                                    if let due = task.dueDate {
                                        Text(due).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        NavigationLink("All tasks") { TasksView() }
                    }
                }

                if !p.upcomingEvents.isEmpty {
                    Section("Coming up") {
                        ForEach(p.upcomingEvents.prefix(5)) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.body.weight(.medium))
                                Text(event.startDatetime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        NavigationLink("Calendar") { CalendarAgendaView() }
                    }
                }

                if let list = p.shoppingLists.first {
                    Section(list.name) {
                        ForEach(list.items.prefix(5)) { item in
                            HStack {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(YuvomiColors.kitchen)
                                Text(item.name)
                                if let q = item.quantity, !q.isEmpty {
                                    Text(q).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Text("\(list.openCount) open · \(list.totalCount) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        NavigationLink("Shopping") { ShoppingView() }
                    }
                }

                if !p.pinnedNotes.isEmpty {
                    Section("Pinned notes") {
                        ForEach(p.pinnedNotes.prefix(3)) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.displayTitle).font(.body.weight(.medium))
                                Text(note.content).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        NavigationLink("Notes") { NotesView() }
                    }
                }

                if !p.birthdays.isEmpty {
                    Section("Birthdays") {
                        ForEach(p.birthdays.prefix(3)) { b in
                            HStack {
                                Text(b.name)
                                Spacer()
                                if let days = b.daysUntil {
                                    Text("in \(days)d").foregroundStyle(YuvomiColors.people)
                                }
                            }
                        }
                        NavigationLink("All birthdays") { BirthdaysView() }
                    }
                }

                if let budget = p.budget {
                    Section("Budget \(budget.month ?? "")") {
                        LabeledContent("Income") {
                            Text(budget.income.formatted(.currency(code: "USD")))
                                .foregroundStyle(YuvomiColors.money)
                        }
                        LabeledContent("Expenses") {
                            Text(budget.expenses.formatted(.currency(code: "USD")))
                                .foregroundStyle(.red)
                        }
                        LabeledContent("Balance") {
                            Text(budget.balance.formatted(.currency(code: "USD")))
                                .fontWeight(.semibold)
                        }
                        NavigationLink("Budget") { BudgetView() }
                    }
                }

                if let health = p.health, health.hasMeds == true {
                    Section("Health") {
                        LabeledContent("Doses today") {
                            Text("\(health.dosesTaken ?? 0)/\(health.dosesTotal ?? 0)")
                        }
                        if let low = health.lowStockCount, low > 0 {
                            Text("\(low) meds low on stock").foregroundStyle(.orange)
                        }
                        NavigationLink("Health") { HealthView() }
                    }
                }
            } else if viewModel.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading dashboard…").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var greeting: String {
        let name = authStore.currentUser?.displayName
            ?? authStore.profile?.displayName
            ?? "there"
        return "Hello, \(name)"
    }
}

@MainActor
private final class ViewModelHolder: ObservableObject {
    @Published var model: DashboardViewModel?
}
