import XCTest

final class AppShellUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testLaunchesOnLearnAndShowsEveryPrimaryTab() {
        XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
        XCTAssertTrue(app.tabBars.buttons["Practice"].exists)
        XCTAssertTrue(app.tabBars.buttons["Social"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
        XCTAssertTrue(app.navigationBars["Learn"].exists)
    }

    func testEveryPrimaryTabOpensItsDestination() {
        for title in ["Practice", "Social", "Profile", "Learn"] {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        }
    }
}
