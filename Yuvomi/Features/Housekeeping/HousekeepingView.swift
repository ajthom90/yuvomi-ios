import SwiftUI

@MainActor
final class HousekeepingViewModel: ObservableObject {
    @Published private(set) var dashboard: HousekeepingDashboard?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await dependencies.makeAPI().fetchHousekeepingDashboard()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct HousekeepingView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if let dash = vm.dashboard {
                        Section("This month") {
                            LabeledContent("Visits", value: "\(dash.visitsThisMonth)")
                            LabeledContent("Pending tasks", value: "\(dash.pendingTasks)")
                            LabeledContent("Finished tasks", value: "\(dash.finishedTasksThisMonth)")
                            LabeledContent("Pending pay") {
                                Text(dash.pendingPayments.formatted(.currency(code: "USD")))
                            }
                            LabeledContent("Paid") {
                                Text(dash.paidThisMonth.formatted(.currency(code: "USD")))
                                    .foregroundStyle(YuvomiColors.work)
                            }
                        }
                        Section("Staff") {
                            if dash.workers.isEmpty {
                                Text("No housekeepers configured yet.")
                                    .foregroundStyle(.secondary)
                                Text("Add workers and schedules in the Yuvomi web app; check-in/out will land natively next.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(dash.workers.enumerated()), id: \.offset) { _, worker in
                                    Text(worker.label)
                                }
                            }
                        }
                    } else if !vm.isLoading {
                        ContentUnavailableView("Housekeeping", systemImage: "broom")
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
            } else {
                ProgressView().onAppear { holder.model = HousekeepingViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Housekeeping")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: HousekeepingViewModel?
}
