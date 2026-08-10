import SwiftUI

struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, tasks, shopping, calendar, more
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Home", systemImage: ModuleKind.home.systemImage) }
            .tag(Tab.home)

            NavigationStack {
                TasksView()
            }
            .tabItem { Label("Tasks", systemImage: ModuleKind.tasks.systemImage) }
            .tag(Tab.tasks)

            NavigationStack {
                ShoppingView()
            }
            .tabItem { Label("Shopping", systemImage: ModuleKind.shopping.systemImage) }
            .tag(Tab.shopping)

            NavigationStack {
                CalendarAgendaView()
            }
            .tabItem { Label("Calendar", systemImage: ModuleKind.calendar.systemImage) }
            .tag(Tab.calendar)

            NavigationStack {
                MoreModulesView()
            }
            .tabItem { Label("More", systemImage: "square.grid.2x2.fill") }
            .tag(Tab.more)
        }
        .tint(YuvomiColors.overview)
    }
}

struct MoreModulesView: View {
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ModuleKind.moreGridModules) { module in
                    NavigationLink {
                        destination(for: module)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: module.systemImage)
                                .font(.title2)
                                .foregroundStyle(module.accent)
                                .frame(width: 52, height: 52)
                                .background(module.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(module.title)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: ModuleKind.settings.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("More")
    }

    @ViewBuilder
    private func destination(for module: ModuleKind) -> some View {
        switch module {
        case .meals: MealsView()
        case .recipes: RecipesView()
        case .pantry: PantryView()
        case .budget: BudgetView()
        case .splitExpenses: SplitExpensesView()
        case .family: FamilyView()
        case .contacts: ContactsView()
        case .birthdays: BirthdaysView()
        case .health: HealthView()
        case .rewards: RewardsView()
        case .notes: NotesView()
        case .documents: DocumentsView()
        case .housekeeping: HousekeepingView()
        case .reminders: RemindersView()
        default: ModulePlaceholderView(module: module)
        }
    }
}
