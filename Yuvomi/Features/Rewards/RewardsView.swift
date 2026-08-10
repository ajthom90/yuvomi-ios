import SwiftUI

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published private(set) var overview: RewardsOverview?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            overview = try await dependencies.makeAPI().fetchRewardsOverview()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addReward(name: String, cost: Int) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, cost > 0 else { return }
        do {
            _ = try await dependencies.makeAPI().createReward(name: trimmed, cost: cost)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct RewardsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var name = ""
    @State private var cost = "50"

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }

                    if let overview = vm.overview {
                        Section("Standings") {
                            ForEach(overview.balances) { row in
                                HStack {
                                    Text("\(row.rank.map(String.init) ?? "–"). \(row.displayName)")
                                    Spacer()
                                    Text("\(row.balance) pts")
                                        .font(.body.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(YuvomiColors.work)
                                }
                            }
                        }

                        Section("Catalog") {
                            if overview.catalog.isEmpty {
                                Text("No rewards yet").foregroundStyle(.secondary)
                            } else {
                                ForEach(overview.catalog) { item in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.name).font(.body.weight(.medium))
                                            if let d = item.description, !d.isEmpty {
                                                Text(d).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text("\(item.cost) pts")
                                            .foregroundStyle(YuvomiColors.work)
                                    }
                                }
                            }
                        }

                        if overview.pendingCount > 0 {
                            Section {
                                Text("\(overview.pendingCount) pending redemption(s)")
                                    .foregroundStyle(.orange)
                            }
                        }
                    } else if !vm.isLoading {
                        ContentUnavailableView("Rewards", systemImage: "star", description: Text("Earn points from tasks."))
                    }
                }
                .toolbar {
                    if vm.overview?.isAdmin == true {
                        ToolbarItem(placement: .primaryAction) {
                            Button { showAdd = true } label: { Image(systemName: "plus") }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .sheet(isPresented: $showAdd) {
                    NavigationStack {
                        Form {
                            TextField("Reward name", text: $name)
                            TextField("Cost (points)", text: $cost).keyboardType(.numberPad)
                        }
                        .navigationTitle("New reward")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    Task {
                                        await vm.addReward(name: name, cost: Int(cost) ?? 0)
                                        name = ""; cost = "50"
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
                ProgressView().onAppear { holder.model = RewardsViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Rewards")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: RewardsViewModel?
}
