import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var rangeDays: Int = 14

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var sections: [(day: String, events: [CalendarEvent])] {
        let grouped = Dictionary(grouping: events) { $0.dayKey }
        return grouped.keys.sorted().map { key in
            let dayEvents = (grouped[key] ?? []).sorted { $0.startDatetime < $1.startDatetime }
            return (key, dayEvents)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: rangeDays, to: today) ?? today
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        let from = df.string(from: today)
        let to = df.string(from: end)

        do {
            let api = try dependencies.makeAPI()
            events = try await api.fetchCalendarEvents(from: from, to: to)
        } catch {
            // Fallback to upcoming if range query fails for any reason.
            do {
                let api = try dependencies.makeAPI()
                events = try await api.fetchUpcomingEvents()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func addEvent(title: String, start: Date, end: Date, allDay: Bool) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let startStr: String
        let endStr: String
        if allDay {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = "yyyy-MM-dd"
            startStr = df.string(from: start)
            endStr = df.string(from: end)
        } else {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            startStr = df.string(from: start)
            endStr = df.string(from: end)
        }
        do {
            let api = try dependencies.makeAPI()
            _ = try await api.createCalendarEvent(title: trimmed, start: startStr, end: endStr, allDay: allDay)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ event: CalendarEvent) async {
        do {
            let api = try dependencies.makeAPI()
            try await api.deleteCalendarEvent(id: event.id)
            events.removeAll { $0.id == event.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
