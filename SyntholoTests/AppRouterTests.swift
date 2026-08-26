import XCTest
@testable import Syntholo

@MainActor
final class AppRouterTests: XCTestCase {
    func testInitialRouteIsLearn() {
        XCTAssertEqual(AppRouter().selectedRoute, .learn)
    }

    func testSelectingAnotherRouteUpdatesState() {
        let router = AppRouter()
        router.select(.practice)
        XCTAssertEqual(router.selectedRoute, .practice)
    }
}
