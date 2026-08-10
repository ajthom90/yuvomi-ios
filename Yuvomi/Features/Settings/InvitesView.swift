import SwiftUI

@MainActor
final class InvitesViewModel: ObservableObject {
    @Published private(set) var invites: [Invite] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCreatedToken: String?

    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            invites = try await dependencies.makeAPI().fetchInvites()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func create(username: String, displayName: String) async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let result = try await dependencies.makeAPI().createInvite(
                username: username.isEmpty ? nil : username,
                displayName: name
            )
            lastCreatedToken = result.token
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func revoke(_ invite: Invite) async {
        do {
            try await dependencies.makeAPI().revokeInvite(id: invite.id)
            invites.removeAll { $0.id == invite.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct InvitesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showCreate = false
    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if let token = vm.lastCreatedToken {
                        Section("Invite link token (copy now)") {
                            Text(token)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text("Shown only once. Share securely with the new member.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("Pending invites") {
                        if vm.invites.isEmpty && !vm.isLoading {
                            Text("No pending invites.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.invites) { invite in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(invite.displayName ?? invite.username ?? "Invite #\(invite.id)")
                                        .font(.body.weight(.medium))
                                    Text("\(invite.role ?? "member") · \(invite.familyRole ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await vm.revoke(invite) }
                                    } label: { Label("Revoke", systemImage: "xmark") }
                                }
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreate = true } label: { Image(systemName: "plus") }
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
                .sheet(isPresented: $showCreate) {
                    NavigationStack {
                        Form {
                            TextField("Display name", text: $displayName)
                            TextField("Username (optional)", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .navigationTitle("Invite member")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showCreate = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Create") {
                                    Task {
                                        await vm.create(username: username, displayName: displayName)
                                        username = ""; displayName = ""
                                        showCreate = false
                                    }
                                }
                                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            } else {
                ProgressView().onAppear { holder.model = InvitesViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Invites")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: InvitesViewModel?
}
