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
}
