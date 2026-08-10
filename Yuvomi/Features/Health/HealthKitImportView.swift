import SwiftUI

@MainActor
final class HealthKitImportViewModel: ObservableObject {
    @Published var selectedMetrics: Set<HealthKitMapping.Metric>
    @Published var dayWindow: Int = 30
    @Published private(set) var previewCount: Int?
    @Published private(set) var isWorking = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let dependencies: AppDependencies
    private let importer = HealthKitImporter()
    private var prefs = HealthKitImportPreferences()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.selectedMetrics = HealthKitImportPreferences().enabledMetrics
    }

    var isAvailable: Bool { importer.isAvailable }

    func persistSelection() {
        prefs.enabledMetrics = selectedMetrics
    }

    func requestAccess() async {
        errorMessage = nil
        statusMessage = nil
        guard isAvailable else {
            errorMessage = HealthKitImportError.unavailable.errorDescription
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await importer.requestAuthorization(metrics: selectedMetrics)
            statusMessage = "Health access requested. Import only reads data you allow."
            persistSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func preview() async {
        errorMessage = nil
        statusMessage = nil
        guard isAvailable else {
            errorMessage = HealthKitImportError.unavailable.errorDescription
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let drafts = try await importer.fetchDrafts(metrics: selectedMetrics, days: dayWindow)
            previewCount = drafts.count
            statusMessage = "Found \(drafts.count) sample(s) in the last \(dayWindow) days."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importNow() async {
        errorMessage = nil
        statusMessage = nil
        guard isAvailable else {
            errorMessage = HealthKitImportError.unavailable.errorDescription
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            persistSelection()
            let api = try dependencies.makeAPI()
            let existing = try await api.fetchVitals()
            let drafts = try await importer.fetchDrafts(metrics: selectedMetrics, days: dayWindow)
            var imported = 0
            var skipped = 0
            for draft in drafts {
                if HealthKitMapping.isDuplicate(draft: draft, existing: existing) {
                    skipped += 1
                    continue
                }
                _ = try await api.createVital(
                    type: draft.type,
                    valueNum: draft.valueNum,
                    valueNum2: draft.valueNum2,
                    unit: draft.unit,
                    measuredAt: HealthKitMapping.measuredAtString(draft.measuredAt),
                    visibility: "private",
                    note: draft.sourceNote
                )
                imported += 1
            }
            prefs.lastImportAt = Date()
            statusMessage = "Imported \(imported) vital(s), skipped \(skipped) duplicate(s). Visibility: private."
            previewCount = drafts.count
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct HealthKitImportView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear {
                    holder.model = HealthKitImportViewModel(dependencies: dependencies)
                }
            }
        }
        .navigationTitle("Apple Health")
    }

    @ViewBuilder
    private func content(_ vm: HealthKitImportViewModel) -> some View {
        List {
            Section {
                Text("Import *your* vitals from Apple Health into *your* private Yuvomi health profile on your server. Nothing is shared with the household unless you change visibility later in the web app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !vm.isAvailable {
                Section {
                    Label(
                        "Apple Health isn’t available here (typical on Simulator). Test on a physical iPhone.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                    .font(.footnote)
                }
            }

            Section("Metrics") {
                ForEach(HealthKitMapping.Metric.allCases) { metric in
                    Toggle(isOn: Binding(
                        get: { vm.selectedMetrics.contains(metric) },
                        set: { on in
                            if on { vm.selectedMetrics.insert(metric) }
                            else { vm.selectedMetrics.remove(metric) }
                            vm.persistSelection()
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                            Text("→ \(metric.yuvomiType) · \(metric.defaultUnit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Window") {
                Picker("Import last", selection: Binding(
                    get: { vm.dayWindow },
                    set: { vm.dayWindow = $0 }
                )) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            if let status = vm.statusMessage {
                Section { Text(status).foregroundStyle(YuvomiColors.health).font(.footnote) }
            }
            if let count = vm.previewCount {
                Section { LabeledContent("Samples found", value: "\(count)") }
            }

            Section {
                Button {
                    Task { await vm.requestAccess() }
                } label: {
                    Label("Request Health access", systemImage: "heart.text.square")
                }
                .disabled(vm.isWorking || !vm.isAvailable)

                Button {
                    Task { await vm.preview() }
                } label: {
                    Label("Preview import", systemImage: "eye")
                }
                .disabled(vm.isWorking || !vm.isAvailable || vm.selectedMetrics.isEmpty)

                Button {
                    Task { await vm.importNow() }
                } label: {
                    if vm.isWorking {
                        HStack { ProgressView(); Text("Working…") }
                    } else {
                        Label("Import into Yuvomi", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(vm.isWorking || !vm.isAvailable || vm.selectedMetrics.isEmpty)
            } footer: {
                Text("One-way only: Health → Yuvomi. Duplicates (same type, minute, and value) are skipped. Default visibility is private.")
            }
        }
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: HealthKitImportViewModel?
}
