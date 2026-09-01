import XCTest

@MainActor
final class AppShellUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    func testLaunchesOnLearnAndShowsEveryPrimaryTab() {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Learn"].exists)
        XCTAssertTrue(app.tabBars.buttons["Practice"].exists)
        XCTAssertTrue(app.tabBars.buttons["Social"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
        XCTAssertTrue(app.navigationBars["Learn"].exists)
    }

    func testEveryPrimaryTabOpensItsDestination() {
        let app = launchApp()

        for title in ["Practice", "Social", "Profile", "Learn"] {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        }
    }
}

@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--curriculum-fixture=loading",
        ]
        app.launch()
        return app
    }

    private func auditPrimaryTab(
        named title: String,
        for auditType: XCUIAccessibilityAuditType
    ) throws {
        let app = launchApp()
        defer { app.terminate() }

        app.tabBars.buttons[title].tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: auditType)
    }

    func testLearnContrastAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .contrast)
    }

    func testLearnElementDetectionAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .elementDetection)
    }

    func testLearnHitRegionAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .hitRegion)
    }

    func testLearnSufficientElementDescriptionAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .sufficientElementDescription)
    }

    func testLearnDynamicTypeAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .dynamicType)
    }

    func testLearnTextClippedAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .textClipped)
    }

    func testLearnTraitAudit() throws {
        try auditPrimaryTab(named: "Learn", for: .trait)
    }

    func testPracticeContrastAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .contrast)
    }

    func testPracticeElementDetectionAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .elementDetection)
    }

    func testPracticeHitRegionAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .hitRegion)
    }

    func testPracticeSufficientElementDescriptionAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .sufficientElementDescription)
    }

    func testPracticeDynamicTypeAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .dynamicType)
    }

    func testPracticeTextClippedAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .textClipped)
    }

    func testPracticeTraitAudit() throws {
        try auditPrimaryTab(named: "Practice", for: .trait)
    }

    func testSocialContrastAudit() throws {
        try auditPrimaryTab(named: "Social", for: .contrast)
    }

    func testSocialElementDetectionAudit() throws {
        try auditPrimaryTab(named: "Social", for: .elementDetection)
    }

    func testSocialHitRegionAudit() throws {
        try auditPrimaryTab(named: "Social", for: .hitRegion)
    }

    func testSocialSufficientElementDescriptionAudit() throws {
        try auditPrimaryTab(named: "Social", for: .sufficientElementDescription)
    }

    func testSocialDynamicTypeAudit() throws {
        try auditPrimaryTab(named: "Social", for: .dynamicType)
    }

    func testSocialTextClippedAudit() throws {
        try auditPrimaryTab(named: "Social", for: .textClipped)
    }

    func testSocialTraitAudit() throws {
        try auditPrimaryTab(named: "Social", for: .trait)
    }

    func testProfileContrastAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .contrast)
    }

    func testProfileElementDetectionAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .elementDetection)
    }

    func testProfileHitRegionAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .hitRegion)
    }

    func testProfileSufficientElementDescriptionAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .sufficientElementDescription)
    }

    func testProfileDynamicTypeAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .dynamicType)
    }

    func testProfileTextClippedAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .textClipped)
    }

    func testProfileTraitAudit() throws {
        try auditPrimaryTab(named: "Profile", for: .trait)
    }
}
