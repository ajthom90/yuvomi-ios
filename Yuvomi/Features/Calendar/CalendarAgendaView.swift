import SwiftUI

struct CalendarAgendaView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var holder = Holder()
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var allDay = false

    var body: some View {
        Group {
            if let vm = holder.model {
                content(vm)
            } else {
                ProgressView().onAppear { holder.model = CalendarViewModel(dependencies: dependencies) }
            }
        }
        .navigationTitle("Calendar")
    }

    @ViewBuilder
    private func content(_ vm: CalendarViewModel) -> some View {
        List {
            Section {
                Picker("Range", selection: Binding(
                    get: { vm.rangeDays },
                    set: { newValue in
                        vm.rangeDays = newValue
                        Task { await vm.load() }
                    }
                )) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
            }

            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }

            if vm.sections.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No events",
                    systemImage: "calendar",
                    description: Text("Nothing in this range, or calendars are still syncing.")
                )
            } else {
                ForEach(vm.sections, id: \.day) { section in
                    Section(header: Text(formatDay(section.day))) {
                        ForEach(section.events) { event in
                            EventRow(event: event)
                                .swipeActions {
                                    if event.isLocal {
                                        Button(role: .destructive) {
                                            Task { await vm.delete(event) }
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                        }
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
                    TextField("Title", text: $newTitle)
                    Toggle("All day", isOn: $allDay)
                    DatePicker("Starts", selection: $startDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $endDate, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                }
                .navigationTitle("New event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            Task {
                                await vm.addEvent(title: newTitle, start: startDate, end: endDate, allDay: allDay)
                                newTitle = ""
                                showAdd = false
                            }
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func formatDay(_ key: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        if let date = df.date(from: key) {
            return date.formatted(date: .complete, time: .omitted)
        }
        return key
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body.weight(.medium))
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cal = event.calName {
                        Text(cal)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15), in: Capsule())
                    }
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var color: Color {
        if let hex = event.color, let c = Color(hex: hex) { return c }
        return YuvomiColors.time
    }

    private var timeLabel: String {
        if event.allDay { return "All day" }
        let raw = event.startDatetime
        if raw.count >= 16 {
            // 2026-08-11T18:00 or with seconds
            let part = raw.dropFirst(11).prefix(5)
            return String(part)
        }
        return raw
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

@MainActor
private final class Holder: ObservableObject {
    @Published var model: CalendarViewModel?
}
