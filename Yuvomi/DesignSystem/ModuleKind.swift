import SwiftUI

/// All first-party Yuvomi surfaces the client will eventually cover.
enum ModuleKind: String, CaseIterable, Identifiable, Sendable {
    case home
    case tasks
    case shopping
    case calendar
    case meals
    case recipes
    case pantry
    case budget
    case splitExpenses
    case family
    case contacts
    case birthdays
    case health
    case rewards
    case notes
    case documents
    case housekeeping
    case reminders
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .tasks: "Tasks"
        case .shopping: "Shopping"
        case .calendar: "Calendar"
        case .meals: "Meals"
        case .recipes: "Recipes"
        case .pantry: "Pantry"
        case .budget: "Budget"
        case .splitExpenses: "Split expenses"
        case .family: "Family"
        case .contacts: "Contacts"
        case .birthdays: "Birthdays"
        case .health: "Health"
        case .rewards: "Rewards"
        case .notes: "Notes"
        case .documents: "Documents"
        case .housekeeping: "Housekeeping"
        case .reminders: "Reminders"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .tasks: "checkmark.circle.fill"
        case .shopping: "cart.fill"
        case .calendar: "calendar"
        case .meals: "fork.knife"
        case .recipes: "book.fill"
        case .pantry: "cabinet.fill"
        case .budget: "banknote.fill"
        case .splitExpenses: "person.2.fill"
        case .family: "figure.2.and.child.holdinghands"
        case .contacts: "person.crop.rectangle.stack.fill"
        case .birthdays: "gift.fill"
        case .health: "heart.fill"
        case .rewards: "star.fill"
        case .notes: "note.text"
        case .documents: "doc.fill"
        case .housekeeping: "broom"
        case .reminders: "bell.fill"
        case .settings: "gearshape.fill"
        }
    }

    /// Implementation phase from the design roadmap (0 = foundation).
    var phase: Int {
        switch self {
        case .home, .settings: 0
        case .tasks, .shopping, .calendar: 1
        case .meals, .recipes, .pantry: 2
        case .budget, .splitExpenses: 3
        case .family, .contacts, .birthdays, .health, .rewards: 4
        case .notes, .documents, .housekeeping, .reminders: 5
        }
    }

    var accent: Color {
        switch self {
        case .home: YuvomiColors.overview
        case .calendar, .reminders: YuvomiColors.time
        case .tasks, .housekeeping, .rewards: YuvomiColors.work
        case .meals, .recipes, .shopping, .pantry: YuvomiColors.kitchen
        case .budget, .splitExpenses: YuvomiColors.money
        case .contacts, .birthdays, .family: YuvomiColors.people
        case .health: YuvomiColors.health
        case .documents, .notes: YuvomiColors.records
        case .settings: YuvomiColors.neutral
        }
    }

    /// Modules shown in the More grid (not primary tabs).
    static var moreGridModules: [ModuleKind] {
        allCases.filter { ![.home, .tasks, .shopping, .calendar, .settings].contains($0) }
    }
}
