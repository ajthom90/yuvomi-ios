import Foundation

struct HealthKitImportPreferences {
    private let defaults: UserDefaults
    private enum Key {
        static let enabledMetrics = "healthkit.enabledMetrics"
        static let lastImportAt = "healthkit.lastImportAt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabledMetrics: Set<HealthKitMapping.Metric> {
        get {
            guard let raw = defaults.stringArray(forKey: Key.enabledMetrics) else {
                return [.weight, .bloodPressure, .glucose, .spo2]
            }
            return Set(raw.compactMap(HealthKitMapping.Metric.init(rawValue:)))
        }
        set {
            defaults.set(newValue.map(\.rawValue).sorted(), forKey: Key.enabledMetrics)
        }
    }

    var lastImportAt: Date? {
        get { defaults.object(forKey: Key.lastImportAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastImportAt) }
    }
}
