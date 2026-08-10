import XCTest
@testable import Yuvomi

final class ModuleKindTests: XCTestCase {
    func testAllModulesHaveTitlesAndImages() {
        for module in ModuleKind.allCases {
            XCTAssertFalse(module.title.isEmpty, module.rawValue)
            XCTAssertFalse(module.systemImage.isEmpty, module.rawValue)
        }
    }

    func testTasksIsPhase1WorkFamily() {
        XCTAssertEqual(ModuleKind.tasks.phase, 1)
        XCTAssertEqual(ModuleKind.shopping.phase, 1)
        XCTAssertEqual(ModuleKind.meals.phase, 2)
        XCTAssertEqual(ModuleKind.home.phase, 0)
    }

    func testMoreGridExcludesPrimaryTabs() {
        let more = ModuleKind.moreGridModules
        XCTAssertFalse(more.contains(.home))
        XCTAssertFalse(more.contains(.tasks))
        XCTAssertFalse(more.contains(.settings))
        XCTAssertTrue(more.contains(.recipes))
    }
}
