import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isShowingCached = false
    @Published private(set) var cacheDate: Date?

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let userId = dependencies.authStore.currentUser?.id
            ?? dependencies.authStore.profile?.userId
            ?? 0

        do {
            let api = try dependencies.makeAPI()
            let data = try await api.fetchDashboardData()
            let snap = try DashboardSnapshot(data: data)
            snapshot = snap
            isShowingCached = false
            cacheDate = nil

            let key = ResponseCache.key(
                host: api.server.host,
                userId: userId,
                path: "/dashboard"
            )
            try? await dependencies.cache.store(key: key, data: data)

            if dependencies.authStore.currentUser == nil {
                if let me = try? await api.me() {
                    dependencies.authStore.setCurrentUser(me.user)
                }
            }
        } catch {
            // Fall back to cache
            if let profile = dependencies.authStore.profile,
               let server = try? ServerURL(raw: profile.serverURL) {
                let key = ResponseCache.key(host: server.host, userId: userId, path: "/dashboard")
                if let cached = await dependencies.cache.load(key: key),
                   let snap = try? DashboardSnapshot(data: cached.data, fetchedAt: cached.savedAt) {
                    snapshot = snap
                    isShowingCached = true
                    cacheDate = cached.savedAt
                    errorMessage = nil
                    return
                }
            }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if error as? APIError == .unauthorized {
                try? dependencies.authStore.clearAll()
            }
        }
    }
}
