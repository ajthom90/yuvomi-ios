import SwiftUI
import UniformTypeIdentifiers
import QuickLook

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [FamilyDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUploading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var previewURL: URL?

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

    func upload(fileURL: URL, category: String) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let accessed = fileURL.startAccessingSecurityScopedResource()
            defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: fileURL)
            let name = fileURL.deletingPathExtension().lastPathComponent
            let original = fileURL.lastPathComponent
            let mime = mimeType(for: fileURL) ?? "application/octet-stream"
            let api = try dependencies.makeAPI()
            let doc = try await api.uploadDocument(
                name: name,
                originalName: original,
                mimeType: mime,
                fileData: data,
                category: category
            )
            documents.insert(doc, at: 0)
            statusMessage = "Uploaded \(doc.name)"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func open(_ doc: FamilyDocument) async {
        do {
            let api = try dependencies.makeAPI()
            let (data, _) = try await api.downloadDocument(id: doc.id)
            let ext = (doc.originalName as NSString?)?.pathExtension
                ?? (doc.name as NSString).pathExtension
            let filename = doc.originalName ?? (ext.isEmpty ? "\(doc.name).bin" : "\(doc.name).\(ext)")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            previewURL = url
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

    private func mimeType(for url: URL) -> String? {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType
        }
        return nil
    }
}

struct DocumentsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showImporter = false
    @State private var category = "other"

    private let categories = [
        "medical", "school", "identity", "insurance", "finance", "home",
        "vehicle", "legal", "travel", "pets", "warranty", "taxes", "work", "other",
    ]

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = DocumentsViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Documents")
    }

    @ViewBuilder
    private func content(_ vm: DocumentsViewModel) -> some View {
        List {
            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            if let status = vm.statusMessage {
                Section { Text(status).foregroundStyle(YuvomiColors.records).font(.footnote) }
            }
            if vm.isUploading {
                Section { HStack { ProgressView(); Text("Uploading…") } }
            }

            if vm.documents.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No documents",
                    systemImage: "doc",
                    description: Text("Upload a file to your Yuvomi server.")
                )
            } else {
                ForEach(vm.documents) { doc in
                    Button {
                        Task { await vm.open(doc) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: doc.mimeType))
                                .foregroundStyle(YuvomiColors.records)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                                HStack(spacing: 8) {
                                    if let cat = doc.category {
                                        Text(cat).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    if let size = doc.sizeLabel {
                                        Text(size).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Button("Choose file…") { showImporter = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item, .pdf, .image, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await vm.upload(fileURL: url, category: category) }
            case .failure(let error):
                vm.errorMessage = error.localizedDescription
            }
        }
        .quickLookPreview(Binding(
            get: { vm.previewURL },
            set: { vm.previewURL = $0 }
        ))
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
