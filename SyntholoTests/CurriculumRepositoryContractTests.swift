import CoreFoundation
import FirebaseFirestore
import Foundation
import XCTest
@testable import Syntholo

final class CurriculumRepositoryContractTests: XCTestCase {
    func testFreshLoadUsesOnlyExactImmutableGraphPathsInRequiredOrder() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents()
        )
        let cache = RecordingCurriculumCache()
        let scope = try RepositoryFixture.scope()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: scope
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.fresh(snapshot)])
        let paths = await store.requestedPaths()
        XCTAssertEqual(paths, RepositoryFixture.singleLessonReadOrder)
        XCTAssertFalse(paths.contains { $0.hasPrefix("programs/") })
        XCTAssertFalse(paths.contains { $0.hasPrefix("evaluationContractVersions/") })
        XCTAssertFalse(paths.contains { $0.hasPrefix("contentVersionHeads/") })
        XCTAssertFalse(paths.contains { $0.hasPrefix("contentPublicationAudit/") })

        let loadScopes = await cache.loadScopes()
        let replacements = await cache.replacements()
        XCTAssertEqual(loadScopes, [scope])
        XCTAssertEqual(replacements.count, 1)
        XCTAssertEqual(replacements.first?.snapshot, snapshot)
        XCTAssertEqual(replacements.first?.scope, scope)
    }

    func testValidSavedSnapshotIsYieldedExactlyOnceBeforeFreshReplacement() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents()
        )
        let cache = RecordingCurriculumCache(snapshot: snapshot)
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.saved(snapshot), .fresh(snapshot)])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 1)
    }

    func testRemotePublicationDisappearancePreservesSavedSnapshot() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        var documents = try RepositoryFixture.documents()
        documents.removeValue(forKey: RepositoryFixture.configurationPath)
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache(snapshot: snapshot)
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .saved(snapshot),
            .unavailable(error: .notPublished, saved: snapshot),
        ])
        let paths = await store.requestedPaths()
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(paths, [RepositoryFixture.configurationPath])
        XCTAssertEqual(replacementCount, 0)
    }

    func testNoCacheMissingHeaderOrUnsupportedLocaleYieldsOnlyEmpty() async throws {
        do {
            var documents = try RepositoryFixture.documents()
            documents.removeValue(forKey: RepositoryFixture.configurationPath)
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )
            let paths = await store.requestedPaths()
            XCTAssertEqual(events, [.empty])
            XCTAssertEqual(paths, [RepositoryFixture.configurationPath])
        }

        do {
            let locale = try CurriculumLocale("fr-FR")
            let store = RecordingCurriculumDocumentStore(
                documents: try RepositoryFixture.documents()
            )
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope(locale: locale)
            )

            let events = await collectEvents(from: repository, locale: locale)
            let paths = await store.requestedPaths()
            XCTAssertEqual(events, [.empty])
            XCTAssertEqual(paths, [RepositoryFixture.configurationPath])
        }
    }

    func testConfigurationCompatibilityHeaderStopsBeforeLocaleResolutionAndKeepsSaved() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        var documents = try RepositoryFixture.documents()
        var configuration = try XCTUnwrap(
            documents[RepositoryFixture.configurationPath]
        )
        configuration["minimumClientSchemaVersion"] = .integer(2)
        documents[RepositoryFixture.configurationPath] = configuration
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache(snapshot: snapshot)
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .saved(snapshot),
            .updateRequired(requiredSchema: 2, saved: snapshot),
        ])
        let paths = await store.requestedPaths()
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(paths, [RepositoryFixture.configurationPath])
        XCTAssertEqual(replacementCount, 0)
    }

    func testCatalogPointerPerformsTheRequiredSecondCompatibilityCheck() async throws {
        var documents = try RepositoryFixture.documents()
        var pointer = try XCTUnwrap(documents[RepositoryFixture.catalogPointerPath])
        pointer["minimumClientSchemaVersion"] = .integer(2)
        documents[RepositoryFixture.catalogPointerPath] = pointer
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .updateRequired(requiredSchema: 2, saved: nil),
        ])
        let paths = await store.requestedPaths()
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(paths, [
            RepositoryFixture.configurationPath,
            RepositoryFixture.catalogPointerPath,
        ])
        XCTAssertEqual(replacementCount, 0)
    }

    func testFutureCompatibilityMinimumIsReadBeforeStrictV1Fields() async throws {
        for path in [
            RepositoryFixture.configurationPath,
            RepositoryFixture.catalogPointerPath,
        ] {
            var documents = try RepositoryFixture.documents()
            var document = try XCTUnwrap(documents[path])
            document["minimumClientSchemaVersion"] = .integer(2)
            document["futureField"] = .string("ignored only after the update gate")
            documents[path] = document
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .updateRequired(requiredSchema: 2, saved: nil),
            ])
            let paths = await store.requestedPaths()
            XCTAssertEqual(paths.last, path)
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testAdvertisedMissingPointerTargetAndDescendantAreUnavailableNotEmpty() async throws {
        let cases: [(
            removePath: String,
            expectedID: String,
            expectedLastRead: String
        )] = [
            (
                RepositoryFixture.catalogPointerPath,
                RepositoryFixture.locale.token.rawValue,
                RepositoryFixture.catalogPointerPath
            ),
            (
                RepositoryFixture.catalogVersionPath,
                RepositoryFixture.catalogVersionID,
                RepositoryFixture.catalogVersionPath
            ),
            (
                RepositoryFixture.programPath,
                RepositoryFixture.programVersionID,
                RepositoryFixture.programPath
            ),
            (
                RepositoryFixture.modulePath,
                RepositoryFixture.moduleVersionID,
                RepositoryFixture.modulePath
            ),
            (
                RepositoryFixture.lessonPath,
                RepositoryFixture.lessonVersionID,
                RepositoryFixture.lessonPath
            ),
            (
                RepositoryFixture.rubricPath,
                RepositoryFixture.rubricVersionID,
                RepositoryFixture.rubricPath
            ),
            (
                RepositoryFixture.assetPath,
                RepositoryFixture.assetVersionID,
                RepositoryFixture.assetPath
            ),
        ]

        for item in cases {
            var documents = try RepositoryFixture.documents()
            documents.removeValue(forKey: item.removePath)
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .unavailable(
                    error: .brokenReference(id: item.expectedID),
                    saved: nil
                ),
            ], "Unexpected event for missing \(item.removePath)")
            let paths = await store.requestedPaths()
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(paths.last, item.expectedLastRead)
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testMismatchedReturnedImmutableIdentitiesAreBrokenReferences() async throws {
        let cases: [(
            path: String,
            identityKey: String,
            returnedID: String,
            expectedID: String
        )] = [
            (
                RepositoryFixture.catalogVersionPath,
                "catalogVersionID",
                "catalog--en-us--v2",
                RepositoryFixture.catalogVersionID
            ),
            (
                RepositoryFixture.programPath,
                "programVersionID",
                "ai-foundations--en-us--v2",
                RepositoryFixture.programVersionID
            ),
            (
                RepositoryFixture.modulePath,
                "moduleVersionID",
                "synthetic-module--en-us--v2",
                RepositoryFixture.moduleVersionID
            ),
            (
                RepositoryFixture.lessonPath,
                "lessonVersionID",
                "synthetic-lesson--en-us--v2",
                RepositoryFixture.lessonVersionID
            ),
            (
                RepositoryFixture.rubricPath,
                "rubricVersionID",
                "synthetic-rubric--en-us--v2",
                RepositoryFixture.rubricVersionID
            ),
            (
                RepositoryFixture.assetPath,
                "assetVersionID",
                "synthetic-diagram--en-us--v2",
                RepositoryFixture.assetVersionID
            ),
        ]

        for item in cases {
            var documents = try RepositoryFixture.documents()
            var returnedDocument = try XCTUnwrap(documents[item.path])
            returnedDocument[item.identityKey] = .string(item.returnedID)
            documents[item.path] = returnedDocument
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .unavailable(
                    error: .brokenReference(id: item.expectedID),
                    saved: nil
                ),
            ], "Unexpected event for mismatched identity at \(item.path)")
            let paths = await store.requestedPaths()
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(paths.last, item.path)
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testUnsupportedImmutableSchemaBehindCompatibleHeadersIsUnavailable() async throws {
        var documents = try RepositoryFixture.documents()
        var program = try XCTUnwrap(documents[RepositoryFixture.programPath])
        program["schemaVersion"] = .integer(2)
        documents[RepositoryFixture.programPath] = program
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(
                error: .unsupportedSchema(found: 2, supported: 1),
                saved: nil
            ),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testUnsupportedImmutableMinimumBehindCompatibleHeadersIsUnavailable() async throws {
        var documents = try RepositoryFixture.documents()
        var program = try XCTUnwrap(documents[RepositoryFixture.programPath])
        program["minimumClientSchemaVersion"] = .integer(2)
        documents[RepositoryFixture.programPath] = program
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(
                error: .minimumClientUnsupported(required: 2, supported: 1),
                saved: nil
            ),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testMalformedRemoteValueIsClassifiedWithItsExactDocumentPath() async throws {
        var documents = try RepositoryFixture.documents()
        var program = try XCTUnwrap(documents[RepositoryFixture.programPath])
        program["title"] = .integer(1)
        documents[RepositoryFixture.programPath] = program
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(
                error: .malformedDocument(path: RepositoryFixture.programPath),
                saved: nil
            ),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testFirestoreValueNormalizationPreservesNanosecondsAndRejectsFractions() throws {
        let timestamp = Timestamp(
            seconds: 1_800_000_000,
            nanoseconds: 123_456_789
        )

        XCTAssertEqual(
            try CurriculumDocumentValue.normalizingFirestoreValue(timestamp),
            .timestamp(
                CurriculumTimestamp(
                    seconds: 1_800_000_000,
                    nanoseconds: 123_456_789
                )
            )
        )
        XCTAssertEqual(
            try CurriculumDocumentValue.normalizingFirestoreValue(NSNumber(value: 7)),
            .integer(7)
        )
        XCTAssertEqual(
            try CurriculumDocumentValue.normalizingFirestoreValue(NSNumber(value: true)),
            .bool(true)
        )
        XCTAssertThrowsError(
            try CurriculumDocumentValue.normalizingFirestoreValue(NSNumber(value: 1.5))
        )
        XCTAssertThrowsError(
            try CurriculumDocumentValue.normalizingFirestoreValue(NSNumber(value: 7.0))
        )
    }

    func testProductionDocumentNormalizationPreservesMalformedDocumentPath() throws {
        let path = RepositoryFixture.programPath

        XCTAssertThrowsError(
            try CurriculumFirestoreDocumentNormalizer.normalize(
                ["title": NSNumber(value: 7.0)],
                path: path
            )
        ) { error in
            XCTAssertEqual(
                error as? CurriculumDocumentStoreError,
                .malformedDocument(path: path)
            )
        }
    }

    func testMalformedConfigurationArraysAndTimestampFailAtTheHeader() async throws {
        var variants: [CurriculumDocument] = []
        let baseDocuments = try RepositoryFixture.documents()
        let baseConfiguration = try XCTUnwrap(
            baseDocuments[RepositoryFixture.configurationPath]
        )

        var duplicateLocales = baseConfiguration
        duplicateLocales["supportedLocales"] = .array([
            .string("en-US"),
            .string("en-US"),
        ])
        duplicateLocales["catalogPointerIDs"] = .array([
            .string("en-us"),
            .string("en-us"),
        ])
        variants.append(duplicateLocales)

        var mismatchedPointer = baseConfiguration
        mismatchedPointer["catalogPointerIDs"] = .array([.string("fr-fr")])
        variants.append(mismatchedPointer)

        var mismatchedCounts = baseConfiguration
        mismatchedCounts["catalogPointerIDs"] = .array([])
        variants.append(mismatchedCounts)

        var wrongDefault = baseConfiguration
        wrongDefault["defaultLocale"] = .string("fr-FR")
        variants.append(wrongDefault)

        var additionalLocale = baseConfiguration
        additionalLocale["supportedLocales"] = .array([
            .string("en-US"),
            .string("fr-FR"),
        ])
        additionalLocale["catalogPointerIDs"] = .array([
            .string("en-us"),
            .string("fr-fr"),
        ])
        variants.append(additionalLocale)

        var timestampMap = baseConfiguration
        timestampMap["updatedAt"] = .map([
            "seconds": .integer(1_800_000_000),
            "nanoseconds": .integer(123_456_789),
        ])
        variants.append(timestampMap)

        for configuration in variants {
            var documents = baseDocuments
            documents[RepositoryFixture.configurationPath] = configuration
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .unavailable(
                    error: .malformedDocument(
                        path: RepositoryFixture.configurationPath
                    ),
                    saved: nil
                ),
            ])
            let paths = await store.requestedPaths()
            XCTAssertEqual(paths, [RepositoryFixture.configurationPath])
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testMalformedCatalogPointerFailsBeforeImmutableReads() async throws {
        let baseDocuments = try RepositoryFixture.documents()
        let basePointer = try XCTUnwrap(
            baseDocuments[RepositoryFixture.catalogPointerPath]
        )
        var variants: [CurriculumDocument] = []

        var unknownField = basePointer
        unknownField["unexpected"] = .bool(true)
        variants.append(unknownField)

        var wrongLocale = basePointer
        wrongLocale["locale"] = .string("fr-FR")
        variants.append(wrongLocale)

        var wrongCatalogLocale = basePointer
        wrongCatalogLocale["publishedCatalogVersionID"] = .string(
            "catalog--fr-fr--v1"
        )
        variants.append(wrongCatalogLocale)

        var timestampMap = basePointer
        timestampMap["updatedAt"] = .map([
            "seconds": .integer(1_800_000_000),
            "nanoseconds": .integer(123_456_789),
        ])
        variants.append(timestampMap)

        for pointer in variants {
            var documents = baseDocuments
            documents[RepositoryFixture.catalogPointerPath] = pointer
            let store = RecordingCurriculumDocumentStore(documents: documents)
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .unavailable(
                    error: .malformedDocument(
                        path: RepositoryFixture.catalogPointerPath
                    ),
                    saved: nil
                ),
            ])
            let paths = await store.requestedPaths()
            XCTAssertEqual(paths, [
                RepositoryFixture.configurationPath,
                RepositoryFixture.catalogPointerPath,
            ])
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testTimestampShapedMapCannotImpersonateAFirestoreTimestamp() async throws {
        var documents = try RepositoryFixture.documents()
        var program = try XCTUnwrap(documents[RepositoryFixture.programPath])
        program["publishedAt"] = .map([
            "seconds": .integer(1_800_000_000),
            "nanoseconds": .integer(123_456_789),
        ])
        documents[RepositoryFixture.programPath] = program
        let repository = FirestoreCurriculumRepository(
            store: RecordingCurriculumDocumentStore(documents: documents),
            cache: RecordingCurriculumCache(),
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(
                error: .malformedDocument(path: RepositoryFixture.programPath),
                saved: nil
            ),
        ])
    }

    func testDigestMismatchRejectsCompleteRemoteGraphAndPreservesCache() async throws {
        let saved = try CurriculumTestSupport.snapshot()
        var documents = try RepositoryFixture.documents()
        var program = try XCTUnwrap(documents[RepositoryFixture.programPath])
        program["title"] = .string("Changed without refreshing the digest")
        documents[RepositoryFixture.programPath] = program
        let store = RecordingCurriculumDocumentStore(documents: documents)
        let cache = RecordingCurriculumCache(snapshot: saved)
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .saved(saved),
            .unavailable(
                error: .digestMismatch(id: RepositoryFixture.programVersionID),
                saved: saved
            ),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testBrokenOwnershipGraphIsContentUnavailableAndNeverCached() async throws {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var modules = try XCTUnwrap(root["moduleVersions"] as? [[String: Any]])
        modules[0]["programID"] = "other-program"
        try CurriculumTestSupport.refreshContentDigest(&modules[0])
        root["moduleVersions"] = modules
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(root: root)
        )
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(error: .contentUnavailable, saved: nil),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testInvalidAssetSemanticsAreContentUnavailableNotBrokenReference() async throws {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var assets = try XCTUnwrap(root["assetVersions"] as? [[String: Any]])
        assets[0]["accessibilityDescription"] = "   "
        try CurriculumTestSupport.refreshContentDigest(&assets[0])
        root["assetVersions"] = assets
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: RecordingCurriculumDocumentStore(
                documents: try RepositoryFixture.documents(root: root)
            ),
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .unavailable(error: .contentUnavailable, saved: nil),
        ])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testProductionFirestoreErrorClassifierPreservesFailureSemantics() {
        let cases: [(Int, CurriculumDocumentStoreError)] = [
            (FirestoreErrorCode.unauthenticated.rawValue, .authenticationRequired),
            (FirestoreErrorCode.permissionDenied.rawValue, .backendFailure),
            (FirestoreErrorCode.unavailable.rawValue, .networkUnavailable),
            (FirestoreErrorCode.deadlineExceeded.rawValue, .networkUnavailable),
            (FirestoreErrorCode.cancelled.rawValue, .operationCancelled),
        ]

        for (code, expected) in cases {
            let error = NSError(
                domain: FirestoreErrorDomain,
                code: code
            )
            XCTAssertEqual(
                CurriculumFirestoreErrorClassifier.classify(error),
                expected,
                "Unexpected classification for Firestore error code \(code)"
            )
        }

        XCTAssertEqual(
            CurriculumFirestoreErrorClassifier.classify(
                NSError(domain: "not.firestore", code: 1)
            ),
            .backendFailure
        )
    }

    func testRemoteStoreFailuresMapToStableRepositoryErrors() async throws {
        let cases: [(CurriculumDocumentStoreError, CurriculumRepositoryError)] = [
            (.authenticationRequired, .authenticationRequired),
            (.networkUnavailable, .networkUnavailable),
            (.operationCancelled, .operationCancelled),
            (
                .malformedDocument(path: RepositoryFixture.configurationPath),
                .malformedDocument(path: RepositoryFixture.configurationPath)
            ),
            (.backendFailure, .backendFailure),
        ]

        for (storeError, expectedError) in cases {
            let store = RecordingCurriculumDocumentStore(
                documents: try RepositoryFixture.documents(),
                failures: [RepositoryFixture.configurationPath: storeError]
            )
            let cache = RecordingCurriculumCache()
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [
                .unavailable(error: expectedError, saved: nil),
            ], "Unexpected mapping for \(storeError)")
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(replacementCount, 0)
        }
    }

    func testInvalidCacheIsIgnoredWhileRemoteRecoversAndReplacesIt() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        for cacheError in [CurriculumCacheError.corrupt, .wrongSource] {
            let store = RecordingCurriculumDocumentStore(
                documents: try RepositoryFixture.documents()
            )
            let cache = RecordingCurriculumCache(loadError: cacheError)
            let repository = FirestoreCurriculumRepository(
                store: store,
                cache: cache,
                scope: try RepositoryFixture.scope()
            )

            let events = await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )

            XCTAssertEqual(events, [.fresh(snapshot)])
            let replacementCount = await cache.replacementCount()
            XCTAssertEqual(replacementCount, 1)
        }
    }

    func testCacheReplacementFailureDoesNotClaimFreshnessOrEraseSavedFallback() async throws {
        let saved = try CurriculumTestSupport.snapshot()
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents()
        )
        let cache = RecordingCurriculumCache(
            snapshot: saved,
            replaceError: .writeFailed
        )
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [
            .saved(saved),
            .unavailable(error: .backendFailure, saved: saved),
        ])
        let replacementCount = await cache.replacementCount()
        let currentSnapshot = await cache.currentSnapshot()
        XCTAssertEqual(replacementCount, 1)
        XCTAssertEqual(currentSnapshot, saved)
    }

    func testSharedRubricAndAssetReadsAreDeduplicatedWithoutChangingReferenceOrder() async throws {
        let root = try CurriculumTestSupport.twoLessonPublishedClientObject()
        let data = try CurriculumTestSupport.data(from: root)
        let expected = try CurriculumJSONCodec.decodeSnapshot(from: data)
        try CurriculumValidator.validate(expected)
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(root: root)
        )
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.fresh(expected)])
        let paths = await store.requestedPaths()
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("lessonVersions/") },
            [
                "lessonVersions/synthetic-lesson--en-us--v1",
                "lessonVersions/synthetic-lesson-two--en-us--v1",
            ]
        )
        XCTAssertEqual(
            paths.filter { $0 == RepositoryFixture.rubricPath }.count,
            1
        )
        XCTAssertEqual(
            paths.filter { $0 == RepositoryFixture.assetPath }.count,
            1
        )
        XCTAssertEqual(
            expected.lessonVersions.map(\.lessonVersionID.rawValue),
            [
                "synthetic-lesson--en-us--v1",
                "synthetic-lesson-two--en-us--v1",
            ]
        )
        XCTAssertEqual(
            expected.rubricVersions.map(\.rubricVersionID.rawValue),
            [RepositoryFixture.rubricVersionID]
        )
        XCTAssertEqual(
            expected.assetVersions.map(\.assetVersionID.rawValue),
            [RepositoryFixture.assetVersionID]
        )
    }

    func testNonlexicalCatalogProgramOrderIsPreserved() async throws {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        let originalProgram = try XCTUnwrap(
            (root["programVersions"] as? [[String: Any]])?.first
        )
        var comingSoonProgram = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.comingSoonProgramData()
        )
        comingSoonProgram["programVersionID"] = "aaa-coming-soon--en-us--v1"
        comingSoonProgram["programID"] = "aaa-coming-soon"
        try CurriculumTestSupport.refreshContentDigest(&comingSoonProgram)
        root["programVersions"] = [originalProgram, comingSoonProgram]

        var catalog = try XCTUnwrap(root["catalogVersion"] as? [String: Any])
        var entries = try XCTUnwrap(
            catalog["programEntries"] as? [[String: Any]]
        )
        entries.append([
            "programPointerID": "aaa-coming-soon--en-us",
            "programVersionID": "aaa-coming-soon--en-us--v1",
        ])
        catalog["programEntries"] = entries
        try CurriculumTestSupport.refreshContentDigest(&catalog)
        root["catalogVersion"] = catalog

        let expected = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: root)
        )
        try CurriculumValidator.validate(expected)
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(root: root)
        )
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: RecordingCurriculumCache(),
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.fresh(expected)])
        let paths = await store.requestedPaths()
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("programVersions/") },
            [
                "programVersions/ai-foundations--en-us--v1",
                "programVersions/aaa-coming-soon--en-us--v1",
            ]
        )
        XCTAssertEqual(
            expected.programVersions.map(\.programVersionID.rawValue),
            [
                "ai-foundations--en-us--v1",
                "aaa-coming-soon--en-us--v1",
            ]
        )
    }

    func testNonlexicalModuleAndLessonReferenceOrderIsPreserved() async throws {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        let secondModuleVersionID = "aaa-module--en-us--v1"
        let secondLessonVersionID = "aaa-lesson--en-us--v1"

        var programs = try XCTUnwrap(root["programVersions"] as? [[String: Any]])
        programs[0]["moduleVersionIDs"] = [
            RepositoryFixture.moduleVersionID,
            secondModuleVersionID,
        ]
        try CurriculumTestSupport.refreshContentDigest(&programs[0])
        root["programVersions"] = programs

        var modules = try XCTUnwrap(root["moduleVersions"] as? [[String: Any]])
        var secondModule = modules[0]
        secondModule["moduleVersionID"] = secondModuleVersionID
        secondModule["moduleID"] = "aaa-module"
        secondModule["title"] = "Synthetic contract module two"
        secondModule["lessonVersionIDs"] = [secondLessonVersionID]
        try CurriculumTestSupport.refreshContentDigest(&secondModule)
        modules.append(secondModule)
        root["moduleVersions"] = modules

        var lessons = try XCTUnwrap(root["lessonVersions"] as? [[String: Any]])
        var secondLesson = lessons[0]
        secondLesson["lessonVersionID"] = secondLessonVersionID
        secondLesson["lessonID"] = "aaa-lesson"
        secondLesson["moduleID"] = "aaa-module"
        secondLesson["title"] = "Synthetic contract lesson two"
        secondLesson["prerequisiteLessonIDs"] = ["synthetic-lesson"]
        try CurriculumTestSupport.refreshContentDigest(&secondLesson)
        lessons.append(secondLesson)
        root["lessonVersions"] = lessons

        let expected = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: root)
        )
        try CurriculumValidator.validate(expected)
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(root: root)
        )
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: RecordingCurriculumCache(),
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.fresh(expected)])
        let paths = await store.requestedPaths()
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("modules/") },
            [
                RepositoryFixture.modulePath,
                "modules/\(secondModuleVersionID)",
            ]
        )
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("lessonVersions/") },
            [
                RepositoryFixture.lessonPath,
                "lessonVersions/\(secondLessonVersionID)",
            ]
        )
        XCTAssertEqual(
            expected.moduleVersions.map(\.moduleVersionID.rawValue),
            [RepositoryFixture.moduleVersionID, secondModuleVersionID]
        )
        XCTAssertEqual(
            expected.lessonVersions.map(\.lessonVersionID.rawValue),
            [RepositoryFixture.lessonVersionID, secondLessonVersionID]
        )
    }

    func testDistinctRubricAndAssetReadsUseFirstEncounterOrder() async throws {
        var root = try CurriculumTestSupport.twoLessonPublishedClientObject()
        var lessons = try XCTUnwrap(root["lessonVersions"] as? [[String: Any]])
        var secondLesson = lessons[1]
        let secondRubricID = "aaa-rubric--en-us--v1"
        let secondAssetID = "aaa-diagram--en-us--v1"
        secondLesson["rubricVersionID"] = secondRubricID
        secondLesson["assetVersionIDs"] = [secondAssetID]
        var blocks = try XCTUnwrap(secondLesson["blocks"] as? [[String: Any]])
        for index in blocks.indices
            where blocks[index]["type"] as? String == "stillDiagram" {
            blocks[index]["assetVersionID"] = secondAssetID
        }
        secondLesson["blocks"] = blocks
        try CurriculumTestSupport.refreshContentDigest(&secondLesson)
        lessons[1] = secondLesson
        root["lessonVersions"] = lessons

        var rubrics = try XCTUnwrap(root["rubricVersions"] as? [[String: Any]])
        var secondRubric = rubrics[0]
        secondRubric["rubricVersionID"] = secondRubricID
        secondRubric["rubricID"] = "aaa-rubric"
        try CurriculumTestSupport.refreshContentDigest(&secondRubric)
        rubrics.append(secondRubric)
        root["rubricVersions"] = rubrics

        var assets = try XCTUnwrap(root["assetVersions"] as? [[String: Any]])
        var secondAsset = assets[0]
        secondAsset["assetVersionID"] = secondAssetID
        secondAsset["assetID"] = "aaa-diagram"
        try CurriculumTestSupport.refreshContentDigest(&secondAsset)
        assets.append(secondAsset)
        root["assetVersions"] = assets

        let expected = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: root)
        )
        try CurriculumValidator.validate(expected)
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(root: root)
        )
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: RecordingCurriculumCache(),
            scope: try RepositoryFixture.scope()
        )

        let events = await collectEvents(
            from: repository,
            locale: RepositoryFixture.locale
        )

        XCTAssertEqual(events, [.fresh(expected)])
        let paths = await store.requestedPaths()
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("rubricVersions/") },
            [
                RepositoryFixture.rubricPath,
                "rubricVersions/\(secondRubricID)",
            ]
        )
        XCTAssertEqual(
            paths.filter { $0.hasPrefix("assetVersions/") },
            [
                RepositoryFixture.assetPath,
                "assetVersions/\(secondAssetID)",
            ]
        )
    }

    func testCancellingIterationCancelsRemoteResolutionAndPerformsNoCacheReplacement() async throws {
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents(),
            blockedPath: RepositoryFixture.assetPath
        )
        let cache = RecordingCurriculumCache()
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let consumer = Task {
            await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )
        }

        var observedBlock = false
        for _ in 0..<200 {
            if await store.isBlocked() {
                observedBlock = true
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(observedBlock, "The exact-get store never reached the final asset read")

        consumer.cancel()
        let events = await consumer.value
        await store.releaseBlockedReads()
        var observedExit = false
        for _ in 0..<200 {
            if await store.hasBlockedReadExited() {
                observedExit = true
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(observedExit, "Cancelled exact read did not exit")

        XCTAssertEqual(events, [])
        let replacementCount = await cache.replacementCount()
        XCTAssertEqual(replacementCount, 0)
    }

    func testCancellingPendingCacheReplacementDoesNotMutateOrClaimFreshness() async throws {
        let store = RecordingCurriculumDocumentStore(
            documents: try RepositoryFixture.documents()
        )
        let cache = RecordingCurriculumCache(blockReplacement: true)
        let repository = FirestoreCurriculumRepository(
            store: store,
            cache: cache,
            scope: try RepositoryFixture.scope()
        )

        let consumer = Task {
            await collectEvents(
                from: repository,
                locale: RepositoryFixture.locale
            )
        }

        var observedBlock = false
        for _ in 0..<200 {
            if await cache.isReplacementBlocked() {
                observedBlock = true
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(observedBlock, "Cache replacement was never reached")

        consumer.cancel()
        let events = await consumer.value
        await cache.releaseBlockedReplacement()
        var observedExit = false
        for _ in 0..<200 {
            if await cache.hasBlockedReplacementExited() {
                observedExit = true
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(observedExit, "Cancelled cache replacement did not exit")

        XCTAssertEqual(events, [])
        let replacementCount = await cache.replacementCount()
        let currentSnapshot = await cache.currentSnapshot()
        XCTAssertEqual(replacementCount, 0)
        XCTAssertNil(currentSnapshot)
    }
}

private actor RecordingCurriculumDocumentStore: CurriculumDocumentStore {
    private let documents: [String: CurriculumDocument]
    private let failures: [String: CurriculumDocumentStoreError]
    private let blockedPath: String?
    private var paths: [String] = []
    private var blockedContinuation: CheckedContinuation<Void, Never>?
    private var waitingAtBlockedPath = false
    private var blockedReadExited = false

    init(
        documents: [String: CurriculumDocument],
        failures: [String: CurriculumDocumentStoreError] = [:],
        blockedPath: String? = nil
    ) {
        self.documents = documents
        self.failures = failures
        self.blockedPath = blockedPath
    }

    func get(path: String) async throws -> CurriculumDocument? {
        paths.append(path)

        if path == blockedPath {
            defer { blockedReadExited = true }
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    blockedContinuation = continuation
                    waitingAtBlockedPath = true
                }
            } onCancel: {
                Task { await self.releaseBlockedReads() }
            }
            try Task.checkCancellation()
        }

        if let failure = failures[path] {
            throw failure
        }
        return documents[path]
    }

    func requestedPaths() -> [String] {
        paths
    }

    func isBlocked() -> Bool {
        waitingAtBlockedPath
    }

    func releaseBlockedReads() {
        waitingAtBlockedPath = false
        let continuation = blockedContinuation
        blockedContinuation = nil
        continuation?.resume()
    }

    func hasBlockedReadExited() -> Bool {
        blockedReadExited
    }
}

private actor RecordingCurriculumCache: CurriculumCache {
    struct Replacement: Equatable, Sendable {
        let snapshot: CurriculumSnapshot
        let scope: CurriculumCacheScope
    }

    private var snapshot: CurriculumSnapshot?
    private let loadError: CurriculumCacheError?
    private let replaceError: CurriculumCacheError?
    private let blockReplacement: Bool
    private var recordedLoadScopes: [CurriculumCacheScope] = []
    private var recordedReplacements: [Replacement] = []
    private var blockedReplacementContinuation: CheckedContinuation<Void, Never>?
    private var waitingAtReplacement = false
    private var blockedReplacementExited = false

    init(
        snapshot: CurriculumSnapshot? = nil,
        loadError: CurriculumCacheError? = nil,
        replaceError: CurriculumCacheError? = nil,
        blockReplacement: Bool = false
    ) {
        self.snapshot = snapshot
        self.loadError = loadError
        self.replaceError = replaceError
        self.blockReplacement = blockReplacement
    }

    func load(for scope: CurriculumCacheScope) async throws -> CurriculumSnapshot? {
        recordedLoadScopes.append(scope)
        if let loadError {
            throw loadError
        }
        return snapshot
    }

    func replace(
        with snapshot: CurriculumSnapshot,
        for scope: CurriculumCacheScope
    ) async throws {
        if blockReplacement {
            defer { blockedReplacementExited = true }
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    blockedReplacementContinuation = continuation
                    waitingAtReplacement = true
                }
            } onCancel: {
                Task { await self.releaseBlockedReplacement() }
            }
            try Task.checkCancellation()
        }

        recordedReplacements.append(
            Replacement(snapshot: snapshot, scope: scope)
        )
        if let replaceError {
            throw replaceError
        }
        self.snapshot = snapshot
    }

    func loadScopes() -> [CurriculumCacheScope] {
        recordedLoadScopes
    }

    func replacements() -> [Replacement] {
        recordedReplacements
    }

    func replacementCount() -> Int {
        recordedReplacements.count
    }

    func currentSnapshot() -> CurriculumSnapshot? {
        snapshot
    }

    func isReplacementBlocked() -> Bool {
        waitingAtReplacement
    }

    func releaseBlockedReplacement() {
        waitingAtReplacement = false
        let continuation = blockedReplacementContinuation
        blockedReplacementContinuation = nil
        continuation?.resume()
    }

    func hasBlockedReplacementExited() -> Bool {
        blockedReplacementExited
    }
}

private enum RepositoryFixture {
    static let locale = try! CurriculumLocale("en-US")
    static let configurationPath = "featureConfiguration/curriculum"
    static let catalogPointerPath = "catalogs/en-us"
    static let catalogVersionID = "catalog--en-us--v1"
    static let programVersionID = "ai-foundations--en-us--v1"
    static let moduleVersionID = "synthetic-module--en-us--v1"
    static let lessonVersionID = "synthetic-lesson--en-us--v1"
    static let rubricVersionID = "synthetic-rubric--en-us--v1"
    static let assetVersionID = "synthetic-diagram--en-us--v1"

    static let catalogVersionPath = "catalogVersions/\(catalogVersionID)"
    static let programPath = "programVersions/\(programVersionID)"
    static let modulePath = "modules/\(moduleVersionID)"
    static let lessonPath = "lessonVersions/\(lessonVersionID)"
    static let rubricPath = "rubricVersions/\(rubricVersionID)"
    static let assetPath = "assetVersions/\(assetVersionID)"

    static let singleLessonReadOrder = [
        configurationPath,
        catalogPointerPath,
        catalogVersionPath,
        programPath,
        modulePath,
        lessonPath,
        rubricPath,
        assetPath,
    ]

    static func scope(
        locale: CurriculumLocale = RepositoryFixture.locale
    ) throws -> CurriculumCacheScope {
        try CurriculumCacheScope(
            environment: .development,
            projectID: "syntholo-local",
            projectNumber: "emulator",
            locale: locale
        )
    }

    static func documents(
        root suppliedRoot: [String: Any]? = nil
    ) throws -> [String: CurriculumDocument] {
        let root = try suppliedRoot ?? CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var result: [String: CurriculumDocument] = [
            configurationPath: featureConfiguration(),
            catalogPointerPath: catalogPointer(),
        ]

        let catalog = try requiredDocument(root["catalogVersion"])
        let catalogID = try requiredString(catalog["catalogVersionID"])
        result["catalogVersions/\(catalogID)"] = try document(from: catalog)

        try appendDocuments(
            from: root,
            arrayKey: "programVersions",
            identifierKey: "programVersionID",
            collection: "programVersions",
            to: &result
        )
        try appendDocuments(
            from: root,
            arrayKey: "moduleVersions",
            identifierKey: "moduleVersionID",
            collection: "modules",
            to: &result
        )
        try appendDocuments(
            from: root,
            arrayKey: "lessonVersions",
            identifierKey: "lessonVersionID",
            collection: "lessonVersions",
            to: &result
        )
        try appendDocuments(
            from: root,
            arrayKey: "rubricVersions",
            identifierKey: "rubricVersionID",
            collection: "rubricVersions",
            to: &result
        )
        try appendDocuments(
            from: root,
            arrayKey: "assetVersions",
            identifierKey: "assetVersionID",
            collection: "assetVersions",
            to: &result
        )
        return result
    }

    private static func featureConfiguration() -> CurriculumDocument {
        [
            "schemaVersion": .integer(1),
            "minimumClientSchemaVersion": .integer(1),
            "defaultLocale": .string("en-US"),
            "supportedLocales": .array([.string("en-US")]),
            "catalogPointerIDs": .array([.string("en-us")]),
            "updatedAt": .timestamp(timestamp),
        ]
    }

    private static func catalogPointer() -> CurriculumDocument {
        [
            "locale": .string("en-US"),
            "publishedCatalogVersionID": .string(catalogVersionID),
            "schemaVersion": .integer(1),
            "minimumClientSchemaVersion": .integer(1),
            "updatedAt": .timestamp(timestamp),
        ]
    }

    private static let timestamp = CurriculumTimestamp(
        seconds: 1_800_000_000,
        nanoseconds: 123_456_789
    )

    private static func appendDocuments(
        from root: [String: Any],
        arrayKey: String,
        identifierKey: String,
        collection: String,
        to result: inout [String: CurriculumDocument]
    ) throws {
        guard let values = root[arrayKey] as? [[String: Any]] else {
            throw RepositoryFixtureError.invalidFixture
        }
        for value in values {
            let identifier = try requiredString(value[identifierKey])
            result["\(collection)/\(identifier)"] = try document(from: value)
        }
    }

    private static func document(
        from value: [String: Any]
    ) throws -> CurriculumDocument {
        try value.mapValues(documentValue)
    }

    private static func documentValue(
        _ value: Any
    ) throws -> CurriculumDocumentValue {
        if value is NSNull {
            return .null
        }
        if let value = value as? String {
            return .string(value)
        }
        if let value = value as? [Any] {
            return .array(try value.map(documentValue))
        }
        if let value = value as? [String: Any] {
            if Set(value.keys) == ["seconds", "nanoseconds"],
               let seconds = value["seconds"] as? NSNumber,
               let nanoseconds = value["nanoseconds"] as? NSNumber,
               CFGetTypeID(seconds) != CFBooleanGetTypeID(),
               CFGetTypeID(nanoseconds) != CFBooleanGetTypeID() {
                return .timestamp(
                    CurriculumTimestamp(
                        seconds: seconds.int64Value,
                        nanoseconds: nanoseconds.int32Value
                    )
                )
            }
            return .map(try value.mapValues(documentValue))
        }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            let double = value.doubleValue
            guard double.isFinite,
                  double.rounded(.towardZero) == double,
                  double >= Double(Int.min),
                  double <= Double(Int.max) else {
                throw RepositoryFixtureError.invalidFixture
            }
            return .integer(value.intValue)
        }
        throw RepositoryFixtureError.invalidFixture
    }

    private static func requiredDocument(
        _ value: Any?
    ) throws -> [String: Any] {
        guard let value = value as? [String: Any] else {
            throw RepositoryFixtureError.invalidFixture
        }
        return value
    }

    private static func requiredString(_ value: Any?) throws -> String {
        guard let value = value as? String else {
            throw RepositoryFixtureError.invalidFixture
        }
        return value
    }
}

private enum RepositoryFixtureError: Error {
    case invalidFixture
}

private func collectEvents(
    from repository: any CurriculumRepository,
    locale: CurriculumLocale
) async -> [CurriculumLoadEvent] {
    var events: [CurriculumLoadEvent] = []
    for await event in repository.load(locale: locale) {
        events.append(event)
    }
    return events
}
