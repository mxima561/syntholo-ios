import XCTest
@testable import Syntholo

final class DesignTokenTests: XCTestCase {
    func testSpacingScaleIsStrictlyIncreasing() {
        let values = [Space.xs, Space.sm, Space.md, Space.lg, Space.xl]
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(Set(values).count, values.count)
    }

    func testMinimumControlHeightMeetsAccessibilityTarget() {
        XCTAssertGreaterThanOrEqual(Layout.minimumControlHeight, 44)
    }
}
