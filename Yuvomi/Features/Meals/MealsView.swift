import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var newType: MealType = .dinner
    @State private var showListPicker = false
    @State private var pendingMeal: MealPlanEntry?
    @State private var weekExport = false

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = MealsViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Meals")
    }

    @ViewBuilder
    private func content(_ vm: MealsViewModel) -> some View {
        List {
            Section {
                HStack {
                    Button {
                        vm.shiftWeek(by: -1)
                        Task { await vm.load() }
                    } label: { Image(systemName: "chevron.left") }

                    Spacer()
                    VStack(spacing: 2) {
                        Text("Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(weekLabel(vm))
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Button {
                        vm.shiftWeek(by: 1)
                        Task { await vm.load() }
                    } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.borderless)

                if !vm.shoppingLists.isEmpty {
                    Button {
                        weekExport = true
                        showListPicker = true
                    } label: {
                        Label("Send week to shopping", systemImage: "cart.badge.plus")
                    }
                }
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            if let status = vm.statusMessage {
                Section { Text(status).foregroundStyle(YuvomiColors.kitchen).font(.footnote) }
            }

            if vm.meals.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No meals planned",
                    systemImage: "fork.knife",
                    description: Text("Add dinners and breakfasts for this week.")
                )
            } else {
                ForEach(vm.mealsByDate, id: \.date) { day in
                    Section(header: Text(formatDay(day.date))) {
                        ForEach(day.meals) { meal in
                            MealRow(meal: meal)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteMeal(meal) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    if !vm.shoppingLists.isEmpty {
                                        Button {
                                            pendingMeal = meal
                                            weekExport = false
                                            showListPicker = true
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
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Meal title", text: $newTitle)
                    DatePicker("Date", selection: $newDate, displayedComponents: .date)
                    Picker("Type", selection: $newType) {
                        ForEach(MealType.allCases) { t in
                            Label(t.title, systemImage: t.systemImage).tag(t)
                        }
                    }
                }
                .navigationTitle("Add meal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                let df = DateFormatter()
                                df.calendar = Calendar(identifier: .gregorian)
                                df.locale = Locale(identifier: "en_US_POSIX")
                                df.dateFormat = "yyyy-MM-dd"
                                await vm.addMeal(
                                    date: df.string(from: newDate),
                                    type: newType,
                                    title: newTitle,
                                    recipeId: nil
                                )
                                newTitle = ""
                                showAdd = false
                            }
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Choose shopping list", isPresented: $showListPicker, titleVisibility: .visible) {
            ForEach(vm.shoppingLists) { list in
                Button(list.name) {
                    Task {
                        if weekExport {
                            await vm.sendWeekToShopping(listId: list.id)
                        } else if let meal = pendingMeal {
                            await vm.sendMealToShopping(meal, listId: list.id)
                        }
                        pendingMeal = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingMeal = nil
                weekExport = false
            }
        }
    }

    private func weekLabel(_ vm: MealsViewModel) -> String {
        if !vm.weekStart.isEmpty, !vm.weekEnd.isEmpty {
            return "\(vm.weekStart) → \(vm.weekEnd)"
        }
        return "This week"
    }

    private func formatDay(_ key: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        if let date = df.date(from: key) {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        return key
    }
}

private struct MealRow: View {
    let meal: MealPlanEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: MealType(rawValue: meal.mealType)?.systemImage ?? "fork.knife")
                .foregroundStyle(YuvomiColors.kitchen)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title).font(.body.weight(.medium))
                HStack(spacing: 8) {
                    Text(MealType(rawValue: meal.mealType)?.title ?? meal.mealType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if meal.recipeId != nil {
                        Label("Recipe", systemImage: "book")
                            .font(.caption2)
                            .foregroundStyle(YuvomiColors.kitchen)
                    }
                    let count = meal.ingredients.count + meal.recipeIngredientCount
                    if count > 0 {
                        Text("\(count) ingredients")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: MealsViewModel?
}
