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

    private func launchOnboarding(
        extraArguments: [String] = []
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--onboarding-reset",
            "--auth-fixture=success"
        ] + extraArguments
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

        reachAccountCreation(in: app, recordingScreenshots: true)
        attachScreenshot(named: "Task5-Account", of: app)

        XCTAssertTrue(app.buttons["onboarding.auth.apple"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        XCTAssertTrue(app.buttons["Continue with email"].exists)
    }

    func testUnconfiguredGooglePresentsSetupMessageAndKeepsProvidersVisible() {
        let app = launchOnboarding()
        reachAccountCreation(in: app)

        app.buttons["Continue with Google"].tap()

        XCTAssertTrue(
            app.staticTexts[
                "Google sign-in needs local setup. See docs/setup/firebase.md."
            ].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.buttons["onboarding.auth.apple"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
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

    func testEmailFormIsWiredAndCancellationReturnsWithoutError() {
        let app = launchOnboarding()
        reachAccountCreation(in: app)

        app.buttons["Continue with email"].tap()

        XCTAssertTrue(app.navigationBars["Email account"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Email address"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["onboarding.auth.error"].exists)
    }

    func testProfileFailureShowsRetryThenHandoffWithoutRepeatingAuth() {
        let app = launchOnboarding(
            extraArguments: ["--profile-fixture=fail-once"]
        )
        reachAccountCreation(in: app)
        app.buttons["Continue with email"].tap()
        let email = app.textFields["Email address"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("learner@example.com")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("password123")
        app.buttons["Create account"].tap()

        XCTAssertTrue(
            app.buttons["Retry saving profile"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)
        XCTAssertFalse(app.buttons["Continue with Google"].exists)
        XCTAssertFalse(app.buttons["Continue with email"].exists)

        app.buttons["Retry saving profile"].tap()

        XCTAssertTrue(
            app.buttons["Start the first lesson"].waitForExistence(timeout: 3)
        )
    }

    func testLoadingSessionNeverFlashesLearnBeforeSignedOutRoute() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--session-fixture=delayed-signed-out"
        ]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Loading Syntholo…"].waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.tabBars.buttons["Learn"].exists)
        XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 5))
    }

    func testProfileRetryPassesAccessibilityAudit() throws {
        let app = launchOnboarding(
            extraArguments: ["--profile-fixture=fail-once"]
        )
        reachAccountCreation(in: app)
        app.buttons["Continue with email"].tap()
        let email = app.textFields["Email address"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("learner@example.com")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("password123")
        app.buttons["Create account"].tap()
        XCTAssertTrue(
            app.buttons["Retry saving profile"].waitForExistence(timeout: 3)
        )

        try app.performAccessibilityAudit(for: onboardingAuditTypes)
    }

    private func reachAccountCreation(
        in app: XCUIApplication,
        recordingScreenshots: Bool = false
    ) {
        if recordingScreenshots {
            attachScreenshot(named: "Task5-Welcome", of: app)
        }
        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        if recordingScreenshots {
            attachScreenshot(named: "Task5-Path", of: app)
        }
        app.buttons["Choose AI for School"].tap()
        if recordingScreenshots {
            attachScreenshot(named: "Task5-Coach", of: app)
        }
        app.buttons["Supportive"].tap()
    }
}
