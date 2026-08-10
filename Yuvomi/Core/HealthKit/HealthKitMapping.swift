import Foundation

/// Pure mapping helpers (unit-testable without HealthKit).
enum HealthKitMapping {
    enum Metric: String, CaseIterable, Identifiable, Codable {
        case weight
        case bloodPressure = "blood_pressure"
        case temperature
        case glucose
        case spo2
        case heartRate = "heart_rate"

        var id: String { rawValue }

        var yuvomiType: String { rawValue }

        var title: String {
            switch self {
            case .weight: "Weight"
            case .bloodPressure: "Blood pressure"
            case .temperature: "Temperature"
            case .glucose: "Blood glucose"
            case .spo2: "Blood oxygen (SpO₂)"
            case .heartRate: "Heart rate"
            }
        }

        var defaultUnit: String {
            switch self {
            case .weight: "kg"
            case .bloodPressure: "mmHg"
            case .temperature: "°C"
            case .glucose: "mg/dL"
            case .spo2: "%"
            case .heartRate: "bpm"
            }
        }
    }

    struct SampleDraft: Equatable {
        let type: String
        let valueNum: Double
        let valueNum2: Double?
        let unit: String
        let measuredAt: Date
        let sourceNote: String
    }

    static func measuredAtString(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.string(from: date)
    }

    /// Skip if an existing vital has same type and measured_at within the same minute.
    static func isDuplicate(draft: SampleDraft, existing: [HealthVital]) -> Bool {
        let key = measuredAtString(draft.measuredAt)
        let prefix = String(key.prefix(16)) // yyyy-MM-dd'T'HH:mm
        return existing.contains { vital in
            guard vital.type == draft.type else { return false }
            guard let at = vital.measuredAt else { return false }
            return at.hasPrefix(prefix)
                && abs((vital.valueNum ?? 0) - draft.valueNum) < 0.01
        }
    }
}
