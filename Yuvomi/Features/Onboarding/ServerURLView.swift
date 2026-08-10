import SwiftUI

struct ServerURLView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Binding var serverURLText: String
    let onValidated: (VersionInfo) -> Void

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var setupRequired = false

    var body: some View {
        Form {
            Section {
                TextField("https://yuvomi.example.com", text: $serverURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textContentType(.URL)
            } header: {
                Text("Server URL")
            } footer: {
                Text("Use the same address you open in a browser. Prefer HTTPS. Local network addresses work when the phone can reach them.")
            }

            if setupRequired {
                Section {
                    Text("This instance still needs the first admin account. Finish setup in a browser, then return here.")
                        .foregroundStyle(.orange)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isWorking {
                    ProgressView()
                } else {
                    Button("Continue") { Task { await validate() } }
                        .disabled(serverURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func validate() async {
        errorMessage = nil
        setupRequired = false
        isWorking = true
        defer { isWorking = false }

        do {
            let api = try dependencies.makeUnauthenticatedAPI(serverRaw: serverURLText)
            let info = try await api.fetchVersion()
            if info.setupRequired {
                setupRequired = true
                errorMessage = "Complete initial setup in the web app first."
                return
            }
            // Normalize stored text
            let normalized = try ServerURL(raw: serverURLText)
            serverURLText = normalized.baseURL.absoluteString
            onValidated(info)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
