import Foundation
import HealthKit

/// One-way HealthKit → Yuvomi vitals import (private visibility).
@MainActor
final class HealthKitImporter {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func typesToRead(for metrics: Set<HealthKitMapping.Metric>) -> Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for metric in metrics {
            switch metric {
            case .weight:
                if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { set.insert(t) }
            case .bloodPressure:
                if let t = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) { set.insert(t) }
                if let s = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) { set.insert(s) }
                if let d = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) { set.insert(d) }
            case .temperature:
                if let t = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) { set.insert(t) }
            case .glucose:
                if let t = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) { set.insert(t) }
            case .spo2:
                if let t = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) { set.insert(t) }
            case .heartRate:
                if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { set.insert(t) }
            }
        }
        return set
    }

    func requestAuthorization(metrics: Set<HealthKitMapping.Metric>) async throws {
        guard isAvailable else {
            throw HealthKitImportError.unavailable
        }
        let read = typesToRead(for: metrics)
        try await store.requestAuthorization(toShare: [], read: read)
    }

    func fetchDrafts(
        metrics: Set<HealthKitMapping.Metric>,
        days: Int
    ) async throws -> [HealthKitMapping.SampleDraft] {
        guard isAvailable else { throw HealthKitImportError.unavailable }
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -max(1, days), to: end) ?? end
        var drafts: [HealthKitMapping.SampleDraft] = []

        for metric in metrics {
            switch metric {
            case .weight:
                drafts += try await quantitySamples(
                    identifier: .bodyMass,
                    unit: HKUnit.gramUnit(with: .kilo),
                    unitLabel: "kg",
                    type: metric.yuvomiType,
                    start: start,
                    end: end
                )
            case .temperature:
                drafts += try await quantitySamples(
                    identifier: .bodyTemperature,
                    unit: HKUnit.degreeCelsius(),
                    unitLabel: "°C",
                    type: metric.yuvomiType,
                    start: start,
                    end: end
                )
            case .glucose:
                // mmol/L * 18.0182 ≈ mg/dL; prefer mg/dL for US households
                drafts += try await quantitySamples(
                    identifier: .bloodGlucose,
                    unit: HKUnit(from: "mg/dL"),
                    unitLabel: "mg/dL",
                    type: metric.yuvomiType,
                    start: start,
                    end: end
                )
            case .spo2:
                drafts += try await quantitySamples(
                    identifier: .oxygenSaturation,
                    unit: HKUnit.percent(),
                    unitLabel: "%",
                    type: metric.yuvomiType,
                    start: start,
                    end: end,
                    scale: 100 // HealthKit stores 0–1
                )
            case .heartRate:
                drafts += try await quantitySamples(
                    identifier: .heartRate,
                    unit: HKUnit.count().unitDivided(by: .minute()),
                    unitLabel: "bpm",
                    type: metric.yuvomiType,
                    start: start,
                    end: end
                )
            case .bloodPressure:
                drafts += try await bloodPressureSamples(start: start, end: end)
            }
        }

        return drafts.sorted { $0.measuredAt > $1.measuredAt }
    }

    private func quantitySamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        unitLabel: String,
        type: String,
        start: Date,
        end: Date,
        scale: Double = 1
    ) async throws -> [HealthKitMapping.SampleDraft] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        return samples.map { sample in
            let value = sample.quantity.doubleValue(for: unit) * scale
            let source = sample.sourceRevision.source.name
            return HealthKitMapping.SampleDraft(
                type: type,
                valueNum: value,
                valueNum2: nil,
                unit: unitLabel,
                measuredAt: sample.startDate,
                sourceNote: "Imported from Apple Health (\(source))"
            )
        }
    }

    private func bloodPressureSamples(start: Date, end: Date) async throws -> [HealthKitMapping.SampleDraft] {
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure),
              let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let correlations: [HKCorrelation] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: correlationType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (results as? [HKCorrelation]) ?? [])
            }
            store.execute(query)
        }

        let mmHg = HKUnit.millimeterOfMercury()
        return correlations.compactMap { corr in
            let sys = corr.objects(for: systolicType).compactMap { $0 as? HKQuantitySample }.first
            let dia = corr.objects(for: diastolicType).compactMap { $0 as? HKQuantitySample }.first
            guard let sys, let dia else { return nil }
            let source = corr.sourceRevision.source.name
            return HealthKitMapping.SampleDraft(
                type: HealthKitMapping.Metric.bloodPressure.yuvomiType,
                valueNum: sys.quantity.doubleValue(for: mmHg),
                valueNum2: dia.quantity.doubleValue(for: mmHg),
                unit: "mmHg",
                measuredAt: corr.startDate,
                sourceNote: "Imported from Apple Health (\(source))"
            )
        }
    }
}

enum HealthKitImportError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device (common on Simulator)."
        case .notAuthorized:
            "Health access was not granted. Enable Yuvomi in Settings → Health → Data Access."
        }
    }
}
