import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var newTitle = ""
    @State private var showAdd = false

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = TasksViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Task title", text: $newTitle)
                }
                .navigationTitle("New task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false; newTitle = "" }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                await holder.model?.addTask(title: newTitle)
                                newTitle = ""
                                showAdd = false
                            }
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func content(_ vm: TasksViewModel) -> some View {
        List {
            Section {
                Picker("Filter", selection: Binding(
                    get: { vm.filter },
                    set: { vm.filter = $0 }
                )) {
                    ForEach(TasksViewModel.TaskFilter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }

            if vm.filteredTasks.isEmpty && !vm.isLoading {
                ContentUnavailableView("No tasks", systemImage: "checkmark.circle", description: Text("Add a task or change the filter."))
            } else {
                ForEach(vm.filteredTasks) { task in
                    TaskRow(task: task) {
                        Task { await vm.toggleDone(task) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(task) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        if !task.isDone {
                            Button {
                                Task { await vm.setStatus(task, status: "in_progress") }
                            } label: { Label("Start", systemImage: "play.fill") }
                            .tint(YuvomiColors.work)
                        }
                    }
                }
            }
        }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .overlay {
            if vm.isLoading && vm.tasks.isEmpty {
                ProgressView()
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? YuvomiColors.work : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                HStack(spacing: 8) {
                    if task.priority != "none" {
                        Text(task.priorityLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(priorityColor)
                    }
                    if let due = task.dueDate {
                        Label(due, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if task.status == "in_progress" {
                        Text("In progress")
                            .font(.caption)
                            .foregroundStyle(YuvomiColors.work)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch task.priority {
        case "urgent", "high": .red
        case "medium": .orange
        case "low": .blue
        default: .secondary
        }
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: TasksViewModel?
}
