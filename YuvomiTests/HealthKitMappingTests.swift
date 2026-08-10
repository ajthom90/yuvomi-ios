import XCTest
@testable import Yuvomi

final class HealthKitMappingTests: XCTestCase {
    func testMeasuredAtFormat() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 10
        comps.hour = 14
        comps.minute = 30
        comps.second = 5
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let s = HealthKitMapping.measuredAtString(date)
        XCTAssertTrue(s.contains("2026-08-10"))
        XCTAssertTrue(s.contains("14:30"))
    }

    func testDuplicateDetection() {
        let date = Date()
        let draft = HealthKitMapping.SampleDraft(
            type: "weight",
            valueNum: 80,
            valueNum2: nil,
            unit: "kg",
            measuredAt: date,
            sourceNote: "test"
        )
        let existingJSON = """
        {"id":1,"user_id":1,"type":"weight","value_num":80,"value_num2":null,"unit":"kg","measured_at":"\(HealthKitMapping.measuredAtString(date))","note":null,"visibility":"private"}
        """.data(using: .utf8)!
        let existing = try! JSONDecoder().decode(HealthVital.self, from: existingJSON)
        XCTAssertTrue(HealthKitMapping.isDuplicate(draft: draft, existing: [existing]))
    }

    func testMetricDefaults() {
        XCTAssertEqual(HealthKitMapping.Metric.weight.yuvomiType, "weight")
        XCTAssertEqual(HealthKitMapping.Metric.bloodPressure.yuvomiType, "blood_pressure")
        XCTAssertFalse(HealthKitMapping.Metric.allCases.isEmpty)
    }
}
