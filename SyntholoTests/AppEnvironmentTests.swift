import XCTest
@testable import Syntholo

final class AppEnvironmentTests: XCTestCase {
    func testKnownBuildValuesParse() {
        XCTAssertEqual(AppEnvironment(buildValue: "development"), .development)
        XCTAssertEqual(AppEnvironment(buildValue: "staging"), .staging)
        XCTAssertEqual(AppEnvironment(buildValue: "production"), .production)
    }

    func testUnknownBuildValueFallsBackToDevelopment() {
        XCTAssertEqual(AppEnvironment(buildValue: "preview"), .development)
        XCTAssertEqual(AppEnvironment(buildValue: nil), .development)
    }
}
