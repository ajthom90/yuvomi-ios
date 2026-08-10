import SwiftUI

@MainActor
final class HealthViewModel: ObservableObject {
    @Published private(set) var vitals: [HealthVital] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private let dependencies: AppDependencies
    init(dependencies: AppDependencies) { self.dependencies = dependencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            vitals = try await dependencies.makeAPI().fetchVitals()
                .sorted { ($0.measuredAt ?? "") > ($1.measuredAt ?? "") }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func add(type: String, value: Double, value2: Double?, unit: String, at: Date) async {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        do {
            _ = try await dependencies.makeAPI().createVital(
                type: type,
                valueNum: value,
                valueNum2: value2,
                unit: unit.isEmpty ? nil : unit,
                measuredAt: df.string(from: at)
            )
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ vital: HealthVital) async {
        do {
            try await dependencies.makeAPI().deleteVital(id: vital.id)
            vitals.removeAll { $0.id == vital.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct HealthView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var type = "weight"
    @State private var valueText = ""
    @State private var value2Text = ""
    @State private var unit = "kg"
    @State private var measuredAt = Date()

    private let types: [(id: String, title: String, unit: String)] = [
        ("weight", "Weight", "kg"),
        ("blood_pressure", "Blood pressure", "mmHg"),
        ("temperature", "Temperature", "°C"),
        ("glucose", "Glucose", "mg/dL"),
        ("spo2", "SpO₂", "%"),
        ("mood", "Mood", ""),
    ]

    var body: some View {
        Group {
            if let vm = holder.model {
                List {
                    Section {
                        NavigationLink {
                            HealthKitImportView()
                        } label: {
                            Label("Import from Apple Health", systemImage: "heart.text.square.fill")
                        }
                    } footer: {
                        Text("Optional one-way import into your private Yuvomi health profile.")
                    }

                    if let error = vm.errorMessage {
                        Section { Text(error).foregroundStyle(.red).font(.footnote) }
                    }
                    if vm.vitals.isEmpty && !vm.isLoading {
                        ContentUnavailableView(
                            "No vitals yet",
                            systemImage: "heart",
                            description: Text("Log weight, BP, and more — or import from Apple Health. Data stays on your server.")
                        )
                    } else {
                        ForEach(vm.vitals) { vital in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vital.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.body.weight(.medium))
                                    Text(vital.measuredAt ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(vital.displayValue)
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(YuvomiColors.health)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.delete(vital) }
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
                            Picker("Type", selection: $type) {
                                ForEach(types, id: \.id) { t in
                                    Text(t.title).tag(t.id)
                                }
                            }
                            .onChange(of: type) { _, new in
                                unit = types.first(where: { $0.id == new })?.unit ?? ""
                            }
                            TextField(type == "blood_pressure" ? "Systolic" : "Value", text: $valueText)
                                .keyboardType(.decimalPad)
                            if type == "blood_pressure" {
                                TextField("Diastolic", text: $value2Text)
                                    .keyboardType(.decimalPad)
                            }
                            TextField("Unit", text: $unit)
                            DatePicker("Measured", selection: $measuredAt)
                        }
                        .navigationTitle("Log vital")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAdd = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    Task {
                                        let v = Double(valueText.replacingOccurrences(of: ",", with: ".")) ?? 0
                                        let v2 = Double(value2Text.replacingOccurrences(of: ",", with: "."))
                                        await vm.add(type: type, value: v, value2: v2, unit: unit, at: measuredAt)
                                        valueText = ""; value2Text = ""
                                        showAdd = false
                                    }
                                }
                                .disabled(valueText.isEmpty)
                            }
                        }
                    }
                }
            } else {
                ProgressView().onAppear { holder.model = HealthViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Health")
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: HealthViewModel?
}
