import XCTest

private enum CurriculumUITestFixture: String {
    case fresh
    case saved
    case savedToFresh = "saved-to-fresh"
    case offlineNoCache = "offline-no-cache"
    case incompatibleWithFallback = "incompatible-with-fallback"
    case incompatibleWithoutFallback = "incompatible-without-fallback"
    case empty
    case malformed
    case failOnceRetry = "fail-once-retry"
    case loading

    var launchArgument: String {
        "--curriculum-fixture=\(rawValue)"
    }
}

private enum CurriculumUITestContract {
    static let programID = "curriculum.program.ai-foundations--en-us--v1"
    static let moduleID = "curriculum.module.synthetic-module--en-us--v1"
    static let lessonID = "curriculum.lesson.synthetic-lesson--en-us--v1"
    static let lessonTitle = "Synthetic contract lesson"
    static let lessonObjective =
        "Validate a synthetic placeholder graph without supplying editorial curriculum."
}

@MainActor
final class CurriculumUITests: XCTestCase {
    func testFreshCatalogNavigatesExactProgramModuleAndLessonPreview() {
        let app = launch(fixture: .fresh)

        assertCatalog(in: app)
        assertNoStatus(in: app)
        navigateToPreview(in: app)
        assertExactPreview(in: app)

        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()
        XCTAssertTrue(
            element("curriculum.module.detail", in: app)
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.tabBars.buttons["Learn"].waitForExistence(timeout: 3)
        )
    }

    func testSavedSnapshotShowsTerminalSavedStatusAndRetry() {
        let app = launch(fixture: .saved)

        assertCatalog(in: app)
        XCTAssertTrue(element("curriculum.status.saved", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Couldn’t refresh curriculum"].exists)
        XCTAssertTrue(element("curriculum.status.retry", in: app).exists)
    }

    func testSavedToFreshKeepsCatalogAndRemovesRefreshingStatus() {
        let app = launch(fixture: .savedToFresh)
        let savedStatus = element("curriculum.status.saved", in: app)

        XCTAssertTrue(savedStatus.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Saved curriculum"].exists)
        assertCatalog(in: app)
        XCTAssertTrue(savedStatus.waitForNonExistence(timeout: 10))
        assertCatalog(in: app)
        assertNoStatus(in: app)
    }

    func testOfflineWithoutCacheShowsSafeRetryableUnavailableState() {
        let app = launch(fixture: .offlineNoCache)

        XCTAssertTrue(element("curriculum.status.unavailable", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("curriculum.status.retry", in: app).exists)
        XCTAssertFalse(element("curriculum.catalog", in: app).exists)
        XCTAssertTrue(app.staticTexts["Your place is safe. Check your connection and try again."].exists)
    }

    func testIncompatibleWithFallbackKeepsCatalogBelowUpdateBanner() {
        let app = launch(fixture: .incompatibleWithFallback)

        assertCatalog(in: app)
        XCTAssertTrue(element("curriculum.status.update-required", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(element("curriculum.status.retry", in: app).exists)
    }

    func testIncompatibleWithoutFallbackShowsUpdateRequiredWithoutCatalog() {
        let app = launch(fixture: .incompatibleWithoutFallback)

        XCTAssertTrue(element("curriculum.status.update-required", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Update Syntholo"].exists)
        XCTAssertFalse(element("curriculum.catalog", in: app).exists)
        XCTAssertFalse(element("curriculum.status.retry", in: app).exists)
    }

    func testEmptyFixtureShowsHonestEmptyStateWithoutRetry() {
        let app = launch(fixture: .empty)

        XCTAssertTrue(element("curriculum.status.empty", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No curriculum is published yet"].exists)
        XCTAssertFalse(element("curriculum.catalog", in: app).exists)
        XCTAssertFalse(element("curriculum.status.retry", in: app).exists)
    }

    func testMalformedFixtureCollapsesToLearnerSafeUnavailableState() {
        let app = launch(fixture: .malformed)

        XCTAssertTrue(element("curriculum.status.unavailable", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("curriculum.status.retry", in: app).exists)
        XCTAssertFalse(element("curriculum.catalog", in: app).exists)
        XCTAssertFalse(app.containsLabelFragment("debug-fixture/catalog"))
        XCTAssertFalse(app.containsLabelFragment("malformedDocument"))
    }

    func testFailOnceRetryReusesRepositoryAndRecoversToFreshCatalog() {
        let app = launch(fixture: .failOnceRetry)
        let unavailable = element("curriculum.status.unavailable", in: app)

        XCTAssertTrue(unavailable.waitForExistence(timeout: 3))
        element("curriculum.status.retry", in: app).tap()

        assertCatalog(in: app)
        XCTAssertTrue(unavailable.waitForNonExistence(timeout: 3))
        assertNoStatus(in: app)
    }

    func testLoadingFixtureRemainsLoadingWithoutCatalogOrRetry() {
        let app = launch(fixture: .loading)

        XCTAssertTrue(element("curriculum.status.loading", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(element("curriculum.catalog", in: app).exists)
        XCTAssertFalse(element("curriculum.status.retry", in: app).exists)
    }

    private func launch(fixture: CurriculumUITestFixture) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", fixture.launchArgument]
        app.launch()
        return app
    }

    private func assertCatalog(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element("curriculum.catalog", in: app).waitForExistence(timeout: 4),
            file: file,
            line: line
        )
        XCTAssertTrue(
            element(CurriculumUITestContract.programID, in: app).exists,
            file: file,
            line: line
        )
    }

    private func assertNoStatus(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for identifier in [
            "curriculum.status.saved",
            "curriculum.status.empty",
            "curriculum.status.update-required",
            "curriculum.status.unavailable",
        ] {
            XCTAssertFalse(
                element(identifier, in: app).exists,
                identifier,
                file: file,
                line: line
            )
        }
    }
}

@MainActor
final class CurriculumAccessibilityAuditUITests: XCTestCase {
    func testCatalogContrastAudit() throws {
        try auditCatalog(for: .contrast)
    }

    func testCatalogElementDetectionAudit() throws {
        try auditCatalog(for: .elementDetection)
    }

    func testCatalogHitRegionAudit() throws {
        try auditCatalog(for: .hitRegion)
    }

    func testCatalogSufficientElementDescriptionAudit() throws {
        try auditCatalog(for: .sufficientElementDescription)
    }

    func testCatalogTextClippedAudit() throws {
        try auditCatalog(for: .textClipped)
    }

    func testCatalogTraitAudit() throws {
        try auditCatalog(for: .trait)
    }

    func testCatalogAccessibility5TextLayoutAudit() throws {
        let baseline = launch(fixture: .fresh)
        let baselineTitle = element("curriculum.catalog.title", in: baseline)
        XCTAssertTrue(baselineTitle.waitForExistence(timeout: 4))
        let baselineHeight = baselineTitle.frame.height
        baseline.terminate()

        let accessibility5 = launch(
            fixture: .fresh,
            maximumDynamicType: true
        )
        let scaledTitle = element("curriculum.catalog.title", in: accessibility5)
        XCTAssertTrue(scaledTitle.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(scaledTitle.frame.height, baselineHeight)
        try accessibility5.performAccessibilityAudit(for: .textClipped)
        scroll(
            accessibility5,
            to: CurriculumUITestContract.programID
        )
        try accessibility5.performAccessibilityAudit(for: .textClipped)
    }

    func testPreviewContrastAudit() throws {
        try auditPreview(for: .contrast)
    }

    func testPreviewElementDetectionAudit() throws {
        try auditPreview(for: .elementDetection)
    }

    func testPreviewHitRegionAudit() throws {
        try auditPreview(for: .hitRegion)
    }

    func testPreviewSufficientElementDescriptionAudit() throws {
        try auditPreview(for: .sufficientElementDescription)
    }

    func testPreviewTextClippedAudit() throws {
        try auditPreview(for: .textClipped)
    }

    func testPreviewTraitAudit() throws {
        try auditPreview(for: .trait)
    }

    func testPreviewAccessibility5TextLayoutAudit() throws {
        let baseline = launch(fixture: .fresh)
        navigateToPreview(in: baseline)
        let baselineTitle = element("curriculum.lesson.preview.title", in: baseline)
        let baselineObjective = element(
            "curriculum.lesson.preview.objective",
            in: baseline
        )
        XCTAssertTrue(baselineTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(baselineObjective.exists)
        let baselineTitleHeight = baselineTitle.frame.height
        let baselineObjectiveHeight = baselineObjective.frame.height
        baseline.terminate()

        let accessibility5 = launch(
            fixture: .fresh,
            maximumDynamicType: true
        )
        navigateToPreview(in: accessibility5)
        let scaledTitle = element(
            "curriculum.lesson.preview.title",
            in: accessibility5
        )
        let scaledObjective = element(
            "curriculum.lesson.preview.objective",
            in: accessibility5
        )
        XCTAssertTrue(scaledTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(scaledObjective.exists)
        XCTAssertGreaterThan(scaledTitle.frame.height, baselineTitleHeight)
        XCTAssertGreaterThan(
            scaledObjective.frame.height,
            baselineObjectiveHeight
        )
        try auditPreviewViewports(in: accessibility5, for: .textClipped)
    }

    private func auditCatalog(
        for auditType: XCUIAccessibilityAuditType
    ) throws {
        let app = launch(fixture: .fresh)
        defer { app.terminate() }
        XCTAssertTrue(
            element("curriculum.catalog", in: app)
                .waitForExistence(timeout: 4)
        )
        try app.performAccessibilityAudit(for: auditType)
        scroll(app, to: CurriculumUITestContract.programID)
        try app.performAccessibilityAudit(for: auditType)
    }

    private func auditPreview(
        for auditType: XCUIAccessibilityAuditType
    ) throws {
        let app = launch(fixture: .fresh)
        defer { app.terminate() }
        navigateToPreview(in: app)
        try auditPreviewViewports(in: app, for: auditType)
    }

    private func auditPreviewViewports(
        in app: XCUIApplication,
        for auditType: XCUIAccessibilityAuditType
    ) throws {
        XCTAssertTrue(
            element("curriculum.lesson.preview", in: app)
                .waitForExistence(timeout: 4)
        )
        for identifier in [
            "curriculum.lesson.preview.header",
            "curriculum.concept.synthetic-concept",
            "curriculum.diagram.synthetic-diagram-block",
            "curriculum.question.synthetic-question",
            "curriculum.lesson.criteria",
        ] {
            try auditPreviewCard(
                identifier,
                in: app,
                for: auditType
            )
        }
    }

    private func launch(
        fixture: CurriculumUITestFixture,
        maximumDynamicType: Bool = false
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", fixture.launchArgument]
        if maximumDynamicType {
            app.launchArguments.append(
                "--dynamic-type-size=accessibility5"
            )
        }
        app.launch()
        return app
    }

    private func scroll(
        _ app: XCUIApplication,
        to identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier, in: app)
        for _ in 0..<12 where !target.exists {
            app.swipeUp()
        }

        guard target.exists else {
            XCTFail(
                "Could not find \(identifier)",
                file: file,
                line: line
            )
            return
        }

        let viewport = catalogViewport(in: app)
        let fits = target.frame.height <= viewport.height
        position(
            target,
            at: fits ? .fullyVisible : .top,
            in: viewport,
            app: app
        )
        Thread.sleep(forTimeInterval: 0.25)

        XCTAssertTrue(
            fits
                ? isNearFullyVisible(target.frame, in: viewport)
                : oversizedCardCoversViewport(
                    target.frame,
                    in: viewport,
                    at: .top
                ),
            "Could not scroll to \(identifier); frame: \(target.frame)",
            file: file,
            line: line
        )
    }

    private enum ScrollAlignment {
        case fullyVisible
        case top
        case bottom
    }

    private func auditPreviewCard(
        _ identifier: String,
        in app: XCUIApplication,
        for auditType: XCUIAccessibilityAuditType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let target = element(identifier, in: app)
        for _ in 0..<16 where !target.exists {
            app.swipeUp()
        }

        guard target.exists else {
            XCTFail(
                "Could not find preview card \(identifier)",
                file: file,
                line: line
            )
            return
        }

        let viewport = previewViewport(
            in: app,
            file: file,
            line: line
        )
        if target.frame.height <= viewport.height {
            position(
                target,
                at: .fullyVisible,
                in: viewport,
                app: app
            )
            Thread.sleep(forTimeInterval: 0.25)
            XCTAssertTrue(
                isNearFullyVisible(target.frame, in: viewport),
                "Preview card was not near-fully visible: \(identifier); frame: \(target.frame); viewport: \(viewport)",
                file: file,
                line: line
            )
            try performLoggedAccessibilityAudit(
                for: auditType,
                in: app,
                context: "\(identifier):fully-visible"
            )
            return
        }

        position(target, at: .top, in: viewport, app: app)
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertTrue(
            oversizedCardCoversViewport(
                target.frame,
                in: viewport,
                at: .top
            ),
            "Oversized preview card top was not visible: \(identifier); frame: \(target.frame); viewport: \(viewport)",
            file: file,
            line: line
        )
        try performLoggedAccessibilityAudit(
            for: auditType,
            in: app,
            context: "\(identifier):top"
        )

        position(target, at: .bottom, in: viewport, app: app)
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertTrue(
            oversizedCardCoversViewport(
                target.frame,
                in: viewport,
                at: .bottom
            ),
            "Oversized preview card bottom was not visible: \(identifier); frame: \(target.frame); viewport: \(viewport)",
            file: file,
            line: line
        )
        try performLoggedAccessibilityAudit(
            for: auditType,
            in: app,
            context: "\(identifier):bottom"
        )
    }

    private func performLoggedAccessibilityAudit(
        for auditType: XCUIAccessibilityAuditType,
        in app: XCUIApplication,
        context: String
    ) throws {
        try app.performAccessibilityAudit(for: auditType) { issue in
            let element = issue.element
            let details = """
            Preview accessibility audit issue
            context=\(context)
            auditType=\(issue.auditType)
            compact=\(issue.compactDescription)
            detailed=\(issue.detailedDescription)
            identifier=\(element?.identifier ?? "<none>")
            label=\(element?.label ?? "<none>")
            frame=\(String(describing: element?.frame))
            """

            let detailsAttachment = XCTAttachment(string: details)
            detailsAttachment.name = "Accessibility Audit Issue - \(context)"
            detailsAttachment.lifetime = .keepAlways
            self.add(detailsAttachment)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "UI Snapshot - \(context)"
            screenshot.lifetime = .keepAlways
            self.add(screenshot)

            print(details)
            return false
        }
    }

    private func position(
        _ target: XCUIElement,
        at alignment: ScrollAlignment,
        in viewport: CGRect,
        app: XCUIApplication
    ) {
        var previousAnchor: CGFloat?
        for _ in 0..<30 {
            guard target.exists else {
                return
            }
            let frame = target.frame
            let adjustment = verticalAdjustment(
                for: frame,
                at: alignment,
                in: viewport
            )
            if abs(adjustment) <= 8 {
                return
            }

            let anchor = alignment == .bottom
                ? frame.maxY
                : frame.minY
            if let previousAnchor,
               abs(previousAnchor - anchor) < 0.5 {
                return
            }
            previousAnchor = anchor
            dragContent(by: adjustment, in: app)
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func verticalAdjustment(
        for frame: CGRect,
        at alignment: ScrollAlignment,
        in viewport: CGRect
    ) -> CGFloat {
        switch alignment {
        case .fullyVisible:
            if frame.minY < viewport.minY {
                return viewport.minY - frame.minY
            }
            if frame.maxY > viewport.maxY {
                return viewport.maxY - frame.maxY
            }
            return 0
        case .top:
            return viewport.minY - frame.minY
        case .bottom:
            return viewport.maxY - frame.maxY
        }
    }

    private func dragContent(
        by adjustment: CGFloat,
        in app: XCUIApplication
    ) {
        let applicationHeight = app.frame.height
        guard applicationHeight > 0 else {
            return
        }
        let normalizedDistance = min(
            max(abs(adjustment) / applicationHeight, 0.02),
            0.45
        )
        let lowerY = 0.5 - normalizedDistance / 2
        let upperY = 0.5 + normalizedDistance / 2
        if adjustment > 0 {
            drag(in: app, fromY: lowerY, toY: upperY)
        } else {
            drag(in: app, fromY: upperY, toY: lowerY)
        }
    }

    private func isNearFullyVisible(
        _ frame: CGRect,
        in viewport: CGRect
    ) -> Bool {
        guard frame.width > 0,
              frame.height > 0 else {
            return false
        }
        let intersection = frame.intersection(viewport)
        guard !intersection.isNull else {
            return false
        }
        return intersection.width >= frame.width * 0.98
            && intersection.height >= frame.height * 0.98
    }

    private func oversizedCardCoversViewport(
        _ frame: CGRect,
        in viewport: CGRect,
        at alignment: ScrollAlignment
    ) -> Bool {
        let intersection = frame.intersection(viewport)
        guard !intersection.isNull,
              frame.width > 0,
              frame.height > viewport.height else {
            return false
        }
        let isEdgeAligned: Bool
        switch alignment {
        case .top:
            isEdgeAligned = abs(frame.minY - viewport.minY) <= 32
        case .bottom:
            isEdgeAligned = abs(frame.maxY - viewport.maxY) <= 32
        case .fullyVisible:
            return false
        }
        return isEdgeAligned
            && intersection.width >= min(frame.width, viewport.width) * 0.98
            && intersection.height >= viewport.height * 0.90
    }

    private func previewViewport(
        in app: XCUIApplication,
        file: StaticString,
        line: UInt
    ) -> CGRect {
        let windowBounds = visibleWindowBounds(in: app)
        let navigation = element(
            "curriculum.lesson.preview.navigation",
            in: app
        )
        guard navigation.waitForExistence(timeout: 3) else {
            XCTFail(
                "Preview navigation header did not appear",
                file: file,
                line: line
            )
            return windowBounds
        }

        let top = max(windowBounds.minY, navigation.frame.maxY)
        let bottom = visibleContentBottom(
            in: app,
            windowBounds: windowBounds,
            below: top
        )
        return validatedViewport(
            CGRect(
                x: windowBounds.minX,
                y: top,
                width: windowBounds.width,
                height: bottom - top
            ).insetBy(dx: 4, dy: 4),
            fallback: windowBounds,
            file: file,
            line: line
        )
    }

    private func catalogViewport(in app: XCUIApplication) -> CGRect {
        let windowBounds = visibleWindowBounds(in: app)
        let navigation = app.navigationBars.firstMatch
        let top: CGFloat
        if navigation.exists,
           !navigation.frame.isEmpty,
           navigation.frame.intersects(windowBounds) {
            top = max(windowBounds.minY, navigation.frame.maxY)
        } else {
            top = windowBounds.minY
        }
        let bottom = visibleContentBottom(
            in: app,
            windowBounds: windowBounds,
            below: top
        )
        let viewport = CGRect(
            x: windowBounds.minX,
            y: top,
            width: windowBounds.width,
            height: bottom - top
        ).insetBy(dx: 4, dy: 4)
        return viewport.width > 0 && viewport.height > 0
            ? viewport
            : windowBounds
    }

    private func visibleWindowBounds(in app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch
        if window.exists, !window.frame.isEmpty {
            return window.frame
        }
        return app.frame
    }

    private func visibleContentBottom(
        in app: XCUIApplication,
        windowBounds: CGRect,
        below top: CGFloat
    ) -> CGFloat {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists,
              !tabBar.frame.isEmpty,
              tabBar.frame.intersects(windowBounds),
              tabBar.frame.minY > top else {
            return windowBounds.maxY
        }
        return min(windowBounds.maxY, tabBar.frame.minY)
    }

    private func validatedViewport(
        _ viewport: CGRect,
        fallback: CGRect,
        file: StaticString,
        line: UInt
    ) -> CGRect {
        guard viewport.width > 0,
              viewport.height > 0 else {
            XCTFail(
                "Derived an invalid preview viewport: \(viewport)",
                file: file,
                line: line
            )
            return fallback
        }
        return viewport
    }

    private func drag(
        in app: XCUIApplication,
        fromY: CGFloat,
        toY: CGFloat
    ) {
        app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: fromY)
        )
        .press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: toY)
            ),
            withVelocity: 100,
            thenHoldForDuration: 0.1
        )
    }
}

@MainActor
private func element(
    _ identifier: String,
    in app: XCUIApplication
) -> XCUIElement {
    app.descendants(matching: .any)
        .matching(identifier: identifier)
        .firstMatch
}

@MainActor
private func navigateToPreview(in app: XCUIApplication) {
    let catalog = element("curriculum.catalog", in: app)
    XCTAssertTrue(catalog.waitForExistence(timeout: 4))

    tapNavigationElement(
        CurriculumUITestContract.programID,
        destination: "curriculum.program.detail",
        in: app
    )

    tapNavigationElement(
        CurriculumUITestContract.moduleID,
        destination: "curriculum.module.detail",
        in: app
    )

    tapNavigationElement(
        CurriculumUITestContract.lessonID,
        destination: "curriculum.lesson.preview",
        in: app
    )
}

@MainActor
private func tapNavigationElement(
    _ sourceIdentifier: String,
    destination destinationIdentifier: String,
    in app: XCUIApplication
) {
    let source = element(sourceIdentifier, in: app)
    let destination = element(destinationIdentifier, in: app)

    for _ in 0..<10 where !source.exists || !source.isHittable {
        app.swipeUp()
    }
    XCTAssertTrue(
        waitForHittable(source, timeout: 5),
        "Navigation element was not hittable: \(sourceIdentifier)"
    )
    source.tap()

    if !destination.waitForExistence(timeout: 5),
       source.exists,
       source.isHittable {
        source.tap()
    }

    XCTAssertTrue(
        destination.waitForExistence(timeout: 5),
        "Navigation destination did not appear: \(destinationIdentifier)"
    )
}

@MainActor
private func waitForHittable(
    _ element: XCUIElement,
    timeout: TimeInterval
) -> Bool {
    let expectation = XCTNSPredicateExpectation(
        predicate: NSPredicate(
            format: "exists == true AND hittable == true"
        ),
        object: element
    )
    return XCTWaiter.wait(
        for: [expectation],
        timeout: timeout
    ) == .completed
}

@MainActor
private extension XCUIApplication {
    func containsLabelFragment(_ fragment: String) -> Bool {
        descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "label CONTAINS[c] %@",
                    fragment
                )
            )
            .firstMatch
            .exists
    }
}

@MainActor
private func assertExactPreview(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let title = element("curriculum.lesson.preview.title", in: app)
    let objective = element("curriculum.lesson.preview.objective", in: app)
    XCTAssertTrue(title.waitForExistence(timeout: 3), file: file, line: line)
    XCTAssertEqual(
        title.label,
        CurriculumUITestContract.lessonTitle,
        file: file,
        line: line
    )
    XCTAssertTrue(objective.exists, file: file, line: line)
    XCTAssertEqual(
        objective.label,
        CurriculumUITestContract.lessonObjective,
        file: file,
        line: line
    )
}
