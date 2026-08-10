import SwiftUI

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await dependencies.makeAPI().fetchNotes()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func add(title: String, content: String, color: String) async {
        let body = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        do {
            let note = try await dependencies.makeAPI().createNote(
                title: title.isEmpty ? nil : title,
                content: body,
                color: color
            )
            notes.insert(note, at: 0)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func togglePin(_ note: Note) async {
        do {
            try await dependencies.makeAPI().toggleNotePin(id: note.id)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ note: Note) async {
        do {
            try await dependencies.makeAPI().deleteNote(id: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct NotesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var title = ""
    @State private var content = ""
    @State private var color = "#FFEB3B"

    private let colors = ["#FFEB3B", "#81D4FA", "#C5E1A5", "#F8BBD0", "#FFE0B2", "#E1BEE7"]

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if vm.notes.isEmpty && !vm.isLoading {
                        ContentUnavailableView("No notes", systemImage: "note.text")
                    } else {
                        ForEach(vm.notes) { note in
                            NoteRow(note: note)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.delete(note) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task { await vm.togglePin(note) }
                                    } label: {
                                        Label(note.pinned ? "Unpin" : "Pin", systemImage: "pin")
                                    }
                                    .tint(YuvomiColors.records)
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
                            TextField("Title (optional)", text: $title)
                            TextField("Content", text: $content, axis: .vertical)
                                .lineLimit(4...12)
                            Picker("Color", selection: $color) {
                                ForEach(colors, id: \.self) { hex in
                                    HStack {
                                        Circle().fill(Color(hexString: hex) ?? .yellow).frame(width: 16, height: 16)
                                        Text(hex)
                                    }.tag(hex)
                                }
                            }
                        }
                        .navigationTitle("New note")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    Task {
                                        await vm.add(title: title, content: content, color: color)
                                        title = ""; content = ""
                                        showAdd = false
                                    }
                                }
                                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                }
            } else {
                ProgressView().onAppear { holder.model = NotesViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Notes")
    }
}

private struct NoteRow: View {
    let note: Note
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hexString: note.color ?? "#FFEB3B") ?? .yellow)
                .frame(width: 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.displayTitle).font(.body.weight(.semibold))
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.caption).foregroundStyle(YuvomiColors.records)
                    }
                }
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: NotesViewModel?
}
