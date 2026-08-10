import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: SearchResults?
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?

    private let dependencies: AppDependencies
    private var task: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func queryChanged(_ value: String) {
        task?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = nil
            return
        }
        task = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search(trimmed)
        }
    }

    func search(_ q: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            results = try await dependencies.makeAPI().search(query: q)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = SearchViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Search")
    }

    @ViewBuilder
    private func content(_ vm: SearchViewModel) -> some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search Yuvomi…", text: Binding(
                        get: { vm.query },
                        set: { vm.query = $0; vm.queryChanged($0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    if vm.isSearching { ProgressView() }
                }
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }

            if let results = vm.results {
                if results.isEmpty {
                    ContentUnavailableView("No results", systemImage: "magnifyingglass")
                } else {
                    ForEach(results.sections, id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.hits) { hit in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.title)
                                    if let sub = hit.subtitle {
                                        Text(sub).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if vm.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                Section {
                    Text("Type at least 2 characters to search tasks, events, notes, contacts, and more.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: SearchViewModel?
}
