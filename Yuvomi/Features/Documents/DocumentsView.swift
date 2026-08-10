import SwiftUI

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [FamilyDocument] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            documents = try await dependencies.makeAPI().fetchDocuments()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ doc: FamilyDocument) async {
        do {
            try await dependencies.makeAPI().deleteDocument(id: doc.id)
            documents.removeAll { $0.id == doc.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct DocumentsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    Section {
                        Text("Browse and manage family files stored on your Yuvomi server. Upload from the web app for now; download/upload will land in a later polish pass.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if vm.documents.isEmpty && !vm.isLoading {
                        ContentUnavailableView(
                            "No documents",
                            systemImage: "doc",
                            description: Text("Files you add in the web app will show up here.")
                        )
                    } else {
                        ForEach(vm.documents) { doc in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: doc.mimeType))
                                    .foregroundStyle(YuvomiColors.records)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.name).font(.body.weight(.medium))
                                    HStack(spacing: 8) {
                                        if let cat = doc.category {
                                            Text(cat).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        if let size = doc.sizeLabel {
                                            Text(size).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        if let vis = doc.visibility {
                                            Text(vis).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(doc) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
            } else {
                ProgressView().onAppear { holder.model = DocumentsViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Documents")
    }

    private func icon(for mime: String?) -> String {
        guard let mime else { return "doc" }
        if mime.hasPrefix("image/") { return "photo" }
        if mime.contains("pdf") { return "doc.richtext" }
        if mime.hasPrefix("text/") { return "doc.plaintext" }
        return "doc"
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: DocumentsViewModel?
}
