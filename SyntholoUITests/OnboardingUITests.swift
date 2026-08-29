import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    private func launchOnboarding(
        reset: Bool = true,
        providerFixture: String? = nil,
        storageKey: String = UUID().uuidString,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--onboarding-storage-key=\(storageKey)",
        ]
        if reset {
            app.launchArguments.append("--onboarding-reset")
        }
        if let providerFixture {
            app.launchArguments.append("--provider-fixture=\(providerFixture)")
        }
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    private func launchSession(arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    func testUnderThirteenIsBlockedBeforeAccountCreation() {
        let app = launchOnboarding()

        assertNoEarlyInterruption(in: app)
        app.buttons["Start learning"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["I’m under 13"].tap()

        XCTAssertTrue(app.staticTexts["Close Syntholo"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.count, 0)
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)
        XCTAssertFalse(app.buttons["Continue with Google"].exists)
        XCTAssertFalse(app.buttons["Continue with email"].exists)
        assertNoEarlyInterruption(in: app)
    }

    func testTeenCompletesWithEmailAndReachesFirstLessonHandoff() {
        let app = launchOnboarding()

        reachAccountCreation(in: app, ageButton: "I’m 13–17")
        assertAllProvidersAreAvailable(in: app)
        app.buttons["Continue with email"].tap()
        submitEmailAccount(in: app)

        assertFirstLessonHandoff(in: app)
        completeFirstLessonHandoff(in: app)
    }

    func testAdultCompletesWithAppleAndReachesFirstLessonHandoff() {
        let app = launchOnboarding(providerFixture: "success")

        reachAccountCreation(in: app, ageButton: "I’m 18 or older")
        assertAllProvidersAreAvailable(in: app)
        app.buttons["onboarding.auth.apple.fixture"].tap()

        assertFirstLessonHandoff(in: app)
        completeFirstLessonHandoff(in: app)
    }

    func testAdultCompletesWithGoogleAndReachesFirstLessonHandoff() {
        let app = launchOnboarding(providerFixture: "success")

        reachAccountCreation(in: app, ageButton: "I’m 18 or older")
        assertAllProvidersAreAvailable(in: app)
        app.buttons["Continue with Google"].tap()

        assertFirstLessonHandoff(in: app)
        completeFirstLessonHandoff(in: app)
    }

    func testProviderAuthenticationCancellationKeepsAccountWithoutError() {
        let app = launchOnboarding(providerFixture: "cancelled")
        reachAccountCreation(in: app, ageButton: "I’m 18 or older")

        app.buttons["onboarding.auth.apple.fixture"].tap()
        assertProviderCancellationAttempt("apple", in: app)
        assertAccountRemainsWithoutError(in: app)

        app.buttons["Continue with Google"].tap()
        assertProviderCancellationAttempt("google", in: app)
        assertAccountRemainsWithoutError(in: app)
    }

    func testProfileSaveFailureRetriesWithoutRepeatingAuthentication() {
        let app = launchOnboarding(
            providerFixture: "success",
            extraArguments: ["--profile-fixture=fail-once"]
        )
        reachAccountCreation(in: app, ageButton: "I’m 18 or older")
        app.buttons["onboarding.auth.apple.fixture"].tap()

        XCTAssertTrue(
            app.buttons["Retry saving profile"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["Continue with Apple"].exists)
        XCTAssertFalse(app.buttons["Continue with Google"].exists)
        XCTAssertFalse(app.buttons["Continue with email"].exists)
        assertNoEarlyInterruption(in: app)

        app.buttons["Retry saving profile"].tap()

        assertFirstLessonHandoff(in: app)
    }

    func testKillAndRelaunchResumesTheExactPersistedStep() {
        let storageKey = "relaunch-\(UUID().uuidString)"
        let app = launchOnboarding(storageKey: storageKey)
        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        XCTAssertTrue(
            app.buttons["Choose AI for School"].waitForExistence(timeout: 2)
        )
        app.terminate()

        let relaunchedApp = launchOnboarding(
            reset: false,
            storageKey: storageKey
        )

        XCTAssertTrue(
            relaunchedApp.buttons["Choose AI for School"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(relaunchedApp.buttons["Start learning"].exists)
        XCTAssertFalse(relaunchedApp.buttons["Continue with Apple"].exists)
        assertNoEarlyInterruption(in: relaunchedApp)
    }

    func testCompletedProfileRestoresDirectlyToLearn() {
        let app = launchSession(arguments: [])

        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Learn"].exists)
        XCTAssertFalse(app.buttons["Start learning"].exists)
        XCTAssertFalse(app.buttons["Start the first lesson"].exists)
    }

    func testNoPaywallSocialCatalogOrNotificationAppearsBeforeHandoff() {
        let app = launchOnboarding(providerFixture: "success")

        assertNoEarlyInterruption(in: app)
        app.buttons["Start learning"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["I’m 18 or older"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Study smarter"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Beginner-friendly"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Choose AI for School"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Supportive"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["onboarding.auth.apple.fixture"].tap()

        assertFirstLessonHandoff(in: app)
        assertNoEarlyInterruption(in: app)
    }

    func testUnconfiguredGooglePresentsSetupMessageAndKeepsProvidersVisible() {
        let app = launchOnboarding()
        reachAccountCreation(in: app, ageButton: "I’m 18 or older")

        app.buttons["Continue with Google"].tap()

        XCTAssertTrue(
            app.staticTexts[
                "Google sign-in needs local setup. See docs/setup/firebase.md."
            ].waitForExistence(timeout: 2)
        )
        assertAllProvidersAreAvailable(in: app)
    }

    func testEmailFormCancellationReturnsWithoutError() {
        let app = launchOnboarding()
        reachAccountCreation(in: app, ageButton: "I’m 18 or older")
        app.buttons["Continue with email"].tap()

        XCTAssertTrue(app.navigationBars["Email account"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Email address"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        app.buttons["Cancel"].tap()

        assertAccountRemainsWithoutError(in: app)
    }

    func testProfileCheckFailureUsesDistinctRetry() {
        let app = launchSession(
            arguments: ["--profile-load-fixture=fail-once-existing"]
        )

        XCTAssertTrue(
            app.buttons["Retry checking profile"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["We couldn’t check your profile"].exists)
        XCTAssertFalse(app.buttons["Retry saving profile"].exists)
        assertNoEarlyInterruption(in: app)

        app.buttons["Retry checking profile"].tap()

        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 3))
    }

    func testLoadingSessionNeverFlashesLearnBeforeSignedOutRoute() {
        let app = launchSession(
            arguments: ["--session-fixture=delayed-signed-out"]
        )

        XCTAssertTrue(
            app.staticTexts["Loading Syntholo…"].waitForExistence(timeout: 2)
        )
        XCTAssertFalse(app.tabBars.buttons["Learn"].exists)
        XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 5))
    }

    func testAlternatePathStaysSelectedWithoutReplacingRecommendation() {
        let app = launchOnboarding(
            extraArguments: [
                "--path-options-expanded",
                "--path-state-proof",
            ]
        )
        XCTAssertTrue(
            app.buttons["Start learning"].waitForExistence(timeout: 5),
            "Welcome did not expose Start learning."
        )
        app.buttons["Start learning"].tap()
        XCTAssertTrue(
            app.buttons["I’m 18 or older"].waitForExistence(timeout: 5),
            "Age selection did not appear after starting."
        )
        app.buttons["I’m 18 or older"].tap()
        XCTAssertTrue(
            app.buttons["Study smarter"].waitForExistence(timeout: 5),
            "Goal selection did not appear after age confirmation."
        )
        app.buttons["Study smarter"].tap()
        XCTAssertTrue(
            app.buttons["Beginner-friendly"].waitForExistence(timeout: 5),
            "Experience selection did not appear after choosing a goal."
        )
        app.buttons["Beginner-friendly"].tap()
        let initialAlternate = app.buttons["AI for Work"]
        XCTAssertTrue(
            initialAlternate.waitForExistence(timeout: 5),
            "Expanded path fixture did not expose the visible AI for Work choice."
        )
        initialAlternate.tap()
        XCTAssertTrue(
            app.buttons["Supportive"].waitForExistence(timeout: 5),
            "Selecting AI for Work did not advance to coach selection."
        )

        app.buttons["Back"].tap()

        XCTAssertTrue(
            app.buttons["Choose AI for School"].waitForExistence(timeout: 5),
            "Back did not restore the AI for School recommendation action."
        )
        XCTAssertTrue(
            app.staticTexts["Recommended route"].waitForExistence(timeout: 5),
            "Back did not restore the recommendation label."
        )
        XCTAssertTrue(
            app.staticTexts["AI for School"].waitForExistence(timeout: 5),
            "AI for School was no longer the visible recommendation."
        )

        let pathState = app.descendants(matching: .any)["onboarding.path"]
        XCTAssertTrue(
            pathState.waitForExistence(timeout: 5),
            "Back did not restore the path page state surface."
        )
        let expectedState = NSPredicate(
            format: "value == %@",
            "recommended=school;selected=work"
        )
        let stateExpectation = XCTNSPredicateExpectation(
            predicate: expectedState,
            object: pathState
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [stateExpectation], timeout: 5),
            .completed,
            "App state did not preserve AI for Work separately from the AI for School recommendation."
        )
    }

    private func reachAccountCreation(
        in app: XCUIApplication,
        ageButton: String
    ) {
        XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 2))
        app.buttons["Start learning"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons[ageButton].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Study smarter"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Beginner-friendly"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Choose AI for School"].tap()
        assertNoEarlyInterruption(in: app)
        app.buttons["Supportive"].tap()
        assertNoEarlyInterruption(in: app)
    }

    private func submitEmailAccount(in app: XCUIApplication) {
        let email = app.textFields["Email address"]
        XCTAssertTrue(email.waitForExistence(timeout: 2))
        email.tap()
        email.typeText("learner@example.com")
        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("password123")
        app.buttons["Create account"].tap()
    }

    private func assertAllProvidersAreAvailable(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.buttons["Continue with Apple"].exists, file: file, line: line)
        XCTAssertTrue(app.buttons["Continue with Google"].exists, file: file, line: line)
        XCTAssertTrue(app.buttons["Continue with email"].exists, file: file, line: line)
    }

    private func assertAccountRemainsWithoutError(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.buttons["Continue with Apple"].waitForExistence(timeout: 2),
            file: file,
            line: line
        )
        assertAllProvidersAreAvailable(in: app, file: file, line: line)
        XCTAssertFalse(app.staticTexts["onboarding.auth.error"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Start the first lesson"].exists, file: file, line: line)
        assertNoEarlyInterruption(in: app, file: file, line: line)
    }

    private func assertFirstLessonHandoff(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.buttons["Start the first lesson"].waitForExistence(timeout: 3),
            file: file,
            line: line
        )
        XCTAssertFalse(app.tabBars.buttons["Learn"].exists, file: file, line: line)
    }

    private func completeFirstLessonHandoff(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.buttons["Start the first lesson"].tap()
        XCTAssertTrue(
            app.tabBars.buttons["Learn"].waitForExistence(timeout: 3),
            file: file,
            line: line
        )
        XCTAssertTrue(app.navigationBars["Learn"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Start the first lesson"].exists, file: file, line: line)
    }

    private func assertProviderCancellationAttempt(
        _ provider: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let accountRoot = app.descendants(matching: .any)
            .matching(identifier: "onboarding.account")
            .firstMatch
        let marker = "\(provider):cancelled"
        let predicate = NSPredicate(format: "value == %@", marker)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: accountRoot
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 2),
            .completed,
            "The \(provider) cancellation fixture never completed.",
            file: file,
            line: line
        )
    }

    private func assertNoEarlyInterruption(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(app.tabBars.buttons["Social"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Browse programs"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["View catalog"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["View plans"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Upgrade to Pro"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["Turn on notifications"].exists, file: file, line: line)
        XCTAssertEqual(app.alerts.count, 0, file: file, line: line)
    }
}

@MainActor
final class OnboardingAccessibilityAuditUITests: XCTestCase {
    private let auditTypes: XCUIAccessibilityAuditType = [
        .contrast,
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
        .dynamicType,
        .textClipped,
        .trait,
    ]

    private func launchOnboarding(
        providerFixture: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--onboarding-reset",
            "--onboarding-storage-key=a11y-\(UUID().uuidString)",
        ]
        if let providerFixture {
            app.launchArguments.append("--provider-fixture=\(providerFixture)")
        }
        app.launchArguments.append(contentsOf: extraArguments)
        app.launch()
        return app
    }

    private func launchSession(arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    func testSelectionAndAccountLayoutsPassAccessibilityAudits() throws {
        let app = launchOnboarding()

        try audit(app, waitingFor: app.buttons["Start learning"])
        app.buttons["Start learning"].tap()
        try audit(app, waitingFor: app.buttons["I’m 18 or older"])
        app.buttons["I’m 18 or older"].tap()
        try audit(app, waitingFor: app.buttons["Study smarter"])
        app.buttons["Study smarter"].tap()
        try audit(app, waitingFor: app.buttons["Beginner-friendly"])
        app.buttons["Beginner-friendly"].tap()
        try audit(app, waitingFor: app.buttons["Choose AI for School"])
        app.buttons["Choose AI for School"].tap()
        try audit(app, waitingFor: app.buttons["Supportive"])
        app.buttons["Supportive"].tap()
        let nativeAppleControl = app.buttons["onboarding.auth.apple.native"]
        try audit(app, waitingFor: nativeAppleControl)
        XCTAssertFalse(app.buttons["onboarding.auth.apple.fixture"].exists)
    }

    func testExpandedOtherPathsLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding(
            extraArguments: ["--path-options-expanded"]
        )
        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()

        try audit(app, waitingFor: app.buttons["AI for Work"])
    }

    func testAgeRestrictedLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding()
        app.buttons["Start learning"].tap()
        app.buttons["I’m under 13"].tap()

        try audit(app, waitingFor: app.staticTexts["Close Syntholo"])
    }

    func testEmailAccountLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding()
        reachAccountCreation(in: app)
        app.buttons["Continue with email"].tap()

        try audit(app, waitingFor: app.navigationBars["Email account"])
    }

    func testProfileSavingLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding(
            providerFixture: "success",
            extraArguments: ["--profile-fixture=hold-save"]
        )
        reachAccountCreation(in: app)
        app.buttons["onboarding.auth.apple.fixture"].tap()

        try audit(app, waitingFor: app.staticTexts["Saving your profile…"])
    }

    func testProfileSaveRecoveryLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding(
            providerFixture: "success",
            extraArguments: ["--profile-fixture=fail-once"]
        )
        reachAccountCreation(in: app)
        app.buttons["onboarding.auth.apple.fixture"].tap()

        try audit(app, waitingFor: app.buttons["Retry saving profile"])
    }

    func testProfileCheckingLayoutPassesAccessibilityAudits() throws {
        let app = launchSession(
            arguments: ["--profile-load-fixture=fail-once-hold-existing"]
        )
        XCTAssertTrue(
            app.buttons["Retry checking profile"].waitForExistence(timeout: 3)
        )
        app.buttons["Retry checking profile"].tap()

        try audit(app, waitingFor: app.staticTexts["Checking your profile"])
    }

    func testProfileCheckRecoveryLayoutPassesAccessibilityAudits() throws {
        let app = launchSession(
            arguments: ["--profile-load-fixture=fail-once-existing"]
        )

        try audit(app, waitingFor: app.buttons["Retry checking profile"])
    }

    func testFirstLessonHandoffLayoutPassesAccessibilityAudits() throws {
        let app = launchOnboarding(providerFixture: "success")
        reachAccountCreation(in: app)
        app.buttons["onboarding.auth.apple.fixture"].tap()

        try audit(app, waitingFor: app.buttons["Start the first lesson"])
    }

    func testSessionLoadingLayoutPassesAccessibilityAudits() throws {
        let app = launchSession(
            arguments: ["--session-fixture=delayed-signed-out"]
        )

        try audit(app, waitingFor: app.staticTexts["Loading Syntholo…"])
    }

    private func reachAccountCreation(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 2))
        app.buttons["Start learning"].tap()
        app.buttons["I’m 18 or older"].tap()
        app.buttons["Study smarter"].tap()
        app.buttons["Beginner-friendly"].tap()
        app.buttons["Choose AI for School"].tap()
        app.buttons["Supportive"].tap()
    }

    private func audit(
        _ app: XCUIApplication,
        waitingFor element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 3), file: file, line: line)
        try app.performAccessibilityAudit(for: auditTypes)
    }
}
