import XCTest
@testable import Syntholo

final class PrimaryButtonTests: XCTestCase {
    func testConfigurationExposesAccessibleHeight() {
        XCTAssertEqual(PrimaryButtonConfiguration.default.minimumHeight, 48)
    }
}
