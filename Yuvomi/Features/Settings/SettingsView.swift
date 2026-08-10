import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var authStore: AuthSessionStore
    @State private var isSigningOut = false
    @State private var cacheClearedMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Account") {
                if let user = authStore.currentUser {
                    LabeledContent("Name", value: user.displayName)
                    LabeledContent("Username", value: user.username)
                    LabeledContent("Role", value: user.role)
                } else if let profile = authStore.profile {
                    LabeledContent("Name", value: profile.displayName ?? "—")
                    LabeledContent("Username", value: profile.username ?? "—")
                }
                if let method = authStore.profile?.method {
                    LabeledContent("Sign-in", value: method == .apiToken ? "API token" : "Password session")
                }
            }

            Section("Server") {
                LabeledContent("URL", value: authStore.profile?.serverURL ?? "—")
            }

            Section("Household") {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                if authStore.currentUser?.isAdmin == true || authStore.profile?.method == .apiToken {
                    NavigationLink {
                        InvitesView()
                    } label: {
                        Label("Invites", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("Data") {
                Button("Clear offline cache") {
                    Task {
                        do {
                            try await dependencies.cache.clearAll()
                            cacheClearedMessage = "Cache cleared."
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                if let cacheClearedMessage {
                    Text(cacheClearedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("App", value: Bundle.main.appVersionString)
                Link("Source on GitHub", destination: URL(string: "https://github.com/ajthom90/yuvomi-ios")!)
                Link("Yuvomi server", destination: URL(string: "https://github.com/ulsklyc/yuvomi")!)
                Text("Community native client. MIT License. Data stays on your server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await signOut() }
                } label: {
                    if isSigningOut {
                        HStack {
                            ProgressView()
                            Text("Signing out…")
                        }
                    } else {
                        Text("Sign out")
                    }
                }
                .disabled(isSigningOut)
            }
        }
        .navigationTitle("Settings")
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        if let api = try? dependencies.makeAPI() {
            try? await api.logout()
        }
        try? await dependencies.cache.clearAll()
        try? authStore.clearAll()
    }
}

private extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
