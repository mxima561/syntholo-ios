import XCTest
@testable import Syntholo

@MainActor
final class AppRouterTests: XCTestCase {
    func testInitialStateSelectsLearnWithEmptyLearnPath() {
        let router = AppRouter()

        XCTAssertEqual(router.selectedRoute, .learn)
        XCTAssertTrue(router.learnPath.isEmpty)
    }

    func testFourTabContractRemainsLearnPracticeSocialProfile() {
        XCTAssertEqual(
            AppRoute.allCases,
            [.learn, .practice, .social, .profile]
        )
    }

    func testSelectingAnotherRouteUpdatesState() {
        let router = AppRouter()
        router.select(.practice)
        XCTAssertEqual(router.selectedRoute, .practice)
    }

    func testSelectingAnotherTabPreservesExistingLearnPath() throws {
        let router = AppRouter()
        let reference = try makeLessonReference()
        router.presentFirstLesson(reference)

        router.select(.practice)

        XCTAssertEqual(router.selectedRoute, .practice)
        XCTAssertEqual(router.learnPath, [.lesson(reference)])
    }

    func testPresentFirstLessonReplacesStalePathAndRetainsExactImmutableIdentity() throws {
        let router = AppRouter()
        let staleReference = try makeLessonReference(
            locale: "en-US",
            catalogVersion: 2,
            programVersion: 3,
            moduleVersion: 5,
            lessonVersion: 7,
            rubricVersion: 11
        )
        let expectedReference = try makeLessonReference(
            locale: "fr-CA",
            catalogVersion: 13,
            programVersion: 17,
            moduleVersion: 19,
            lessonVersion: 23,
            rubricVersion: 29
        )
        router.presentFirstLesson(staleReference)
        router.select(.social)

        router.presentFirstLesson(expectedReference)

        XCTAssertEqual(router.selectedRoute, .learn)
        XCTAssertEqual(router.learnPath, [.lesson(expectedReference)])
        guard let firstRoute = router.learnPath.first,
              case let .lesson(actualReference) = firstRoute else {
            return XCTFail("Expected exactly one typed lesson route")
        }
        XCTAssertEqual(actualReference.locale.rawValue, "fr-CA")
        XCTAssertEqual(
            actualReference.catalogVersionID.rawValue,
            "catalog--fr-ca--v13"
        )
        XCTAssertEqual(
            actualReference.programVersionID.rawValue,
            "ai-foundations--fr-ca--v17"
        )
        XCTAssertEqual(
            actualReference.moduleVersionID.rawValue,
            "foundations-module--fr-ca--v19"
        )
        XCTAssertEqual(
            actualReference.lessonVersionID.rawValue,
            "first-preview--fr-ca--v23"
        )
        XCTAssertEqual(
            actualReference.rubricVersionID.rawValue,
            "first-preview-rubric--fr-ca--v29"
        )
    }

    func testShowLearnHomeSelectsLearnAndClearsPreviewPath() throws {
        let router = AppRouter()
        router.presentFirstLesson(try makeLessonReference())
        router.select(.profile)

        router.showLearnHome()

        XCTAssertEqual(router.selectedRoute, .learn)
        XCTAssertTrue(router.learnPath.isEmpty)
    }

    private func makeLessonReference(
        locale localeValue: String = "en-US",
        catalogVersion: Int = 1,
        programVersion: Int = 1,
        moduleVersion: Int = 1,
        lessonVersion: Int = 1,
        rubricVersion: Int = 1
    ) throws -> LessonVersionReference {
        let locale = try CurriculumLocale(localeValue)
        return LessonVersionReference(
            locale: locale,
            catalogVersionID: CurriculumCatalogVersionID(
                locale: locale,
                version: try CurriculumVersion(catalogVersion)
            ),
            programVersionID: CurriculumVersionID(
                stableID: try CurriculumStableID("ai-foundations"),
                locale: locale,
                version: try CurriculumVersion(programVersion)
            ),
            moduleVersionID: CurriculumVersionID(
                stableID: try CurriculumStableID("foundations-module"),
                locale: locale,
                version: try CurriculumVersion(moduleVersion)
            ),
            lessonVersionID: CurriculumVersionID(
                stableID: try CurriculumStableID("first-preview"),
                locale: locale,
                version: try CurriculumVersion(lessonVersion)
            ),
            rubricVersionID: CurriculumVersionID(
                stableID: try CurriculumStableID("first-preview-rubric"),
                locale: locale,
                version: try CurriculumVersion(rubricVersion)
            )
        )
    }
}
