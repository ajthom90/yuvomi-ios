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
                        "Offline · showing last updated \(cacheDate.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "wifi.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }

            if let error = viewModel.errorMessage, viewModel.snapshot == nil {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                    Button("Try again") {
                        Task { await viewModel.load() }
                    }
                }
            }

            if let snapshot = viewModel.snapshot {
                Section("Today on your server") {
                    ForEach(snapshot.summaryLines(), id: \.self) { line in
                        Text(line)
                    }
                }
            } else if viewModel.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading dashboard…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
    }

    private var greeting: String {
        let name = authStore.currentUser?.displayName
            ?? authStore.profile?.displayName
            ?? "there"
        return "Hello, \(name)"
    }
}

/// Avoids recreating the view model before dependencies are available.
@MainActor
private final class ViewModelHolder: ObservableObject {
    @Published var model: DashboardViewModel?
}
