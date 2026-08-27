import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    private let onboardingAuditTypes: XCUIAccessibilityAuditType = [
        .contrast,
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
        .dynamicType,
        .textClipped,
        .trait
    ]

    private func launchOnboarding() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--onboarding-reset",
            "--auth-fixture=success"
        ]
        app.launch()
        return app
    }

    private func attachScreenshot(
        named name: String,
        of app: XCUIApplication
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAdultStudyBeginnerPathReachesAccountCreation() {
        let app = launchOnboarding()

        attachScreenshot(named: "Task5-Welcome", of: app)
        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        attachScreenshot(named: "Task5-Path", of: app)
        app.buttons["Choose AI for School"].tap()
        attachScreenshot(named: "Task5-Coach", of: app)
        app.buttons["Supportive"].tap()
        attachScreenshot(named: "Task5-Account", of: app)

        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        XCTAssertTrue(app.buttons["Continue with email"].exists)
    }

    func testOnboardingCheckpointsPassAccessibilityAudits() throws {
        let app = launchOnboarding()

        XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: onboardingAuditTypes)

        app.buttons["Start learning"].tap()
        XCTAssertTrue(app.buttons["I’m 18 or older"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: onboardingAuditTypes)

        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        app.buttons["Choose AI for School"].tap()
        XCTAssertTrue(app.buttons["Supportive"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: onboardingAuditTypes)

        app.buttons["Supportive"].tap()
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 2))
        try app.performAccessibilityAudit(for: onboardingAuditTypes)
    }

    func testUnderThirteenRestrictionIsTerminalAndAccessible() throws {
        let app = launchOnboarding()

        app.buttons["Start learning"].tap()
        app.buttons["I’m under 13"].tap()

        XCTAssertTrue(app.staticTexts["Close Syntholo"].waitForExistence(timeout: 2))
        attachScreenshot(named: "Task5-Age-Restricted", of: app)
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)
        XCTAssertFalse(app.buttons["Continue with Google"].exists)
        XCTAssertFalse(app.buttons["Continue with email"].exists)
        XCTAssertEqual(app.buttons.count, 0)
        try app.performAccessibilityAudit(for: onboardingAuditTypes)
    }

    func testAlternatePathStaysSelectedWithoutReplacingRecommendation() {
        let app = launchOnboarding()

        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        app.buttons["Other paths"].tap()
        app.buttons["AI for Work"].tap()
        XCTAssertTrue(app.buttons["Supportive"].waitForExistence(timeout: 2))

        app.buttons["Back"].tap()

        XCTAssertTrue(app.buttons["Choose AI for School"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Recommended route"].exists)
        XCTAssertTrue(app.staticTexts["AI for School"].exists)
        app.buttons["Other paths"].tap()
        let alternate = app.buttons["AI for Work"]
        XCTAssertTrue(alternate.waitForExistence(timeout: 2))
        XCTAssertTrue(alternate.isSelected)
        attachScreenshot(named: "Task5-Path-Alternate-Selected", of: app)
    }
}
