import Foundation

@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var filter: TaskFilter = .active

    enum TaskFilter: String, CaseIterable, Identifiable {
        case active, done, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .active: "Active"
            case .done: "Done"
            case .all: "All"
            }
        }
    }

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var filteredTasks: [TaskItem] {
        switch filter {
        case .active:
            tasks.filter { !$0.isDone && !$0.isArchived }
        case .done:
            tasks.filter(\.isDone)
        case .all:
            tasks
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let api = try dependencies.makeAPI()
            tasks = try await api.fetchTasks()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addTask(title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let api = try dependencies.makeAPI()
            let created = try await api.createTask(title: trimmed)
            tasks.insert(created, at: 0)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func toggleDone(_ task: TaskItem) async {
        let newStatus = task.isDone ? "open" : "done"
        do {
            let api = try dependencies.makeAPI()
            try await api.updateTaskStatus(id: task.id, status: newStatus)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = newStatus
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await load()
        }
    }

    func setStatus(_ task: TaskItem, status: String) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.updateTaskStatus(id: task.id, status: status)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].status = status
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ task: TaskItem) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
