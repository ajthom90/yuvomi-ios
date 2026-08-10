import SwiftUI

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await dependencies.makeAPI().fetchPendingReminders()
            await ReminderNotificationScheduler.sync(reminders: reminders)
            if statusMessage == nil {
                statusMessage = "Local notifications refreshed for pending reminders."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func dismiss(_ item: ReminderItem) async {
        do {
            try await dependencies.makeAPI().dismissReminder(id: item.id)
            reminders.removeAll { $0.id == item.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct RemindersView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if let status = vm.statusMessage {
                        Section { Text(status).font(.footnote).foregroundStyle(YuvomiColors.time) }
                    }
                    Section {
                        Text("Pending reminders from your Yuvomi server. This app schedules local notifications on this device (no Apple Push / APNs required).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if vm.reminders.isEmpty && !vm.isLoading {
                        ContentUnavailableView(
                            "No pending reminders",
                            systemImage: "bell",
                            description: Text("You’re all caught up.")
                        )
                    } else {
                        ForEach(vm.reminders) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayTitle).font(.body.weight(.medium))
                                    Text("\(item.entityType) · \(item.remindAt)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Dismiss") {
                                    Task { await vm.dismiss(item) }
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                            }
                            .swipeActions {
                                Button {
                                    Task { await vm.dismiss(item) }
                                } label: { Label("Dismiss", systemImage: "checkmark") }
                                .tint(YuvomiColors.time)
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
            } else {
                ProgressView().onAppear { holder.model = RemindersViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Reminders")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: RemindersViewModel?
}
