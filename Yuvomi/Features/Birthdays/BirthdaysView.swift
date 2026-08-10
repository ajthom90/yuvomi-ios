import SwiftUI

@MainActor
final class BirthdaysViewModel: ObservableObject {
    @Published private(set) var birthdays: [Birthday] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            // Prefer upcoming for relevance; fall back to full list.
            let upcoming = try await api.fetchUpcomingBirthdays()
            birthdays = upcoming.isEmpty ? try await api.fetchBirthdays() : upcoming
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func add(name: String, date: Date) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        do {
            _ = try await dependencies.makeAPI().createBirthday(name: trimmed, birthDate: df.string(from: date))
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ b: Birthday) async {
        do {
            try await dependencies.makeAPI().deleteBirthday(id: b.id)
            birthdays.removeAll { $0.id == b.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct BirthdaysView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var name = ""
    @State private var date = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if vm.birthdays.isEmpty && !vm.isLoading {
                        ContentUnavailableView("No birthdays", systemImage: "gift")
                    } else {
                        ForEach(vm.birthdays) { b in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.name).font(.body.weight(.medium))
                                    Text(b.birthDate).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let days = b.daysUntil {
                                    VStack(alignment: .trailing) {
                                        Text("\(days)d")
                                            .font(.headline)
                                            .foregroundStyle(YuvomiColors.people)
                                        if let age = b.nextAge {
                                            Text("turns \(age)").font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(b) }
                                } label: { Label("Delete", systemImage: "trash") }
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
                            TextField("Name", text: $name)
                            DatePicker("Birth date", selection: $date, displayedComponents: .date)
                        }
                        .navigationTitle("Add birthday")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    Task {
                                        await vm.add(name: name, date: date)
                                        name = ""
                                        showAdd = false
                                    }
                                }
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            } else {
                ProgressView().onAppear { holder.model = BirthdaysViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Birthdays")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: BirthdaysViewModel?
}
