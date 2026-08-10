import SwiftUI

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await dependencies.makeAPI().fetchFamilyMembers()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct FamilyView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if vm.members.isEmpty && !vm.isLoading {
                        ContentUnavailableView("No family members", systemImage: "person.3")
                    } else {
                        ForEach(vm.members) { member in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: member.avatarColor ?? "#4F4DC9") ?? YuvomiColors.people)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(String(member.displayName.prefix(1)))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName).font(.body.weight(.medium))
                                    if let role = member.familyRole {
                                        Text(role.capitalized).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .task { await vm.load() }
            } else {
                ProgressView().onAppear { holder.model = FamilyViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Family")
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: FamilyViewModel?
}
