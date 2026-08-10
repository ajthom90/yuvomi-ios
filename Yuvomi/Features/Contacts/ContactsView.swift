import SwiftUI

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await dependencies.makeAPI().fetchContacts()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func add(name: String, phone: String?, email: String?) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try await dependencies.makeAPI().createContact(name: trimmed, phone: phone, email: email)
            contacts.insert(created, at: 0)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ contact: Contact) async {
        do {
            try await dependencies.makeAPI().deleteContact(id: contact.id)
            contacts.removeAll { $0.id == contact.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct ContactsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if vm.contacts.isEmpty && !vm.isLoading {
                        ContentUnavailableView("No contacts", systemImage: "person.crop.rectangle.stack")
                    } else {
                        ForEach(vm.contacts) { contact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name).font(.body.weight(.medium))
                                if let phone = contact.phone, !phone.isEmpty {
                                    Label(phone, systemImage: "phone").font(.caption).foregroundStyle(.secondary)
                                }
                                if let email = contact.email, !email.isEmpty {
                                    Label(email, systemImage: "envelope").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(contact) }
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
                            TextField("Phone", text: $phone).keyboardType(.phonePad)
                            TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        }
                        .navigationTitle("New contact")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    Task {
                                        await vm.add(name: name, phone: phone, email: email)
                                        name = ""; phone = ""; email = ""
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
                ProgressView().onAppear { holder.model = ContactsViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Contacts")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: ContactsViewModel?
}
