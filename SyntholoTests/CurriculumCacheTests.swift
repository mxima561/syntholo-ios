import Foundation
import XCTest
@testable import Syntholo

final class CurriculumCacheTests: XCTestCase {
    private static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000.125)

    func testRoundTripPersistsTheCompleteValidatedEnvelope() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let snapshot = try CurriculumTestSupport.snapshot()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        try await cache.replace(with: snapshot, for: scope)

        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, snapshot)

        let envelope = try object(at: cacheURL(rootURL: rootURL, scope: scope))
        XCTAssertEqual((envelope["envelopeVersion"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(
            (envelope["savedAtUTCMilliseconds"] as? NSNumber)?.int64Value,
            1_800_000_000_125
        )
        XCTAssertEqual(envelope["locale"] as? String, "en-US")
        XCTAssertEqual(envelope["catalogPointerID"] as? String, "en-us")
        XCTAssertEqual(
            envelope["catalogVersionID"] as? String,
            "catalog--en-us--v1"
        )

        let source = try XCTUnwrap(envelope["source"] as? [String: Any])
        XCTAssertEqual(source["environment"] as? String, "development")
        XCTAssertEqual(source["projectID"] as? String, "syntholo-local")
        XCTAssertEqual(source["projectNumber"] as? String, "emulator")
        XCTAssertEqual(
            (envelope["programEntries"] as? [[String: Any]])?.count,
            snapshot.catalogVersion.programEntries.count
        )
        XCTAssertEqual(
            (envelope["documentDigests"] as? [[String: Any]])?.count,
            1
                + snapshot.programVersions.count
                + snapshot.moduleVersions.count
                + snapshot.lessonVersions.count
                + snapshot.rubricVersions.count
                + snapshot.assetVersions.count
        )
        XCTAssertNotNil(envelope["snapshot"] as? [String: Any])
    }

    func testSecondValidWriteAtomicallyReplacesTheFirstEnvelope() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let first = try CurriculumTestSupport.snapshot()
        let second = try snapshot(programTitle: "Synthetic replacement title")
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        try await cache.replace(with: first, for: scope)
        try await cache.replace(with: second, for: scope)

        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, second)
        let directoryURL = cacheURL(rootURL: rootURL, scope: scope)
            .deletingLastPathComponent()
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: directoryURL.path).sorted(),
            ["catalog-snapshot-v1.json"]
        )
    }

    func testCancellationAfterCommitGateLinearizesCannotInterruptTheWrite() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let first = try CurriculumTestSupport.snapshot()
        let second = try snapshot(programTitle: "Linearized replacement title")
        let fileSystem = FaultInjectingCurriculumCacheFileSystem()
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { Self.fixedNow },
            fileSystem: fileSystem
        )
        try await cache.replace(with: first, for: scope)
        fileSystem.blockAtomicWrites = true

        let replacement = Task {
            try await cache.replace(with: second, for: scope)
        }
        XCTAssertTrue(
            fileSystem.waitUntilAtomicWriteIsBlocked(),
            "The cache never reached its atomic commit point"
        )

        replacement.cancel()
        XCTAssertTrue(replacement.isCancelled)
        fileSystem.releaseAtomicWrites()

        try await replacement.value
        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, second)
    }

    func testEnvironmentProjectAndLocaleNamespacesNeverCross() async throws {
        let rootURL = try temporaryRoot()
        let primary = try launchScope()
        let environment = try CurriculumCacheScope(
            environment: .staging,
            projectID: "syntholo-local",
            projectNumber: "123456789012",
            locale: CurriculumLocale("en-US")
        )
        let project = try CurriculumCacheScope(
            environment: .development,
            projectID: "syntholo-other",
            projectNumber: "123456789013",
            locale: CurriculumLocale("en-US")
        )
        let locale = try CurriculumCacheScope(
            environment: .development,
            projectID: "syntholo-local",
            projectNumber: "emulator",
            locale: CurriculumLocale("fr-FR")
        )
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        let paths = [primary, environment, project, locale].map {
            cacheURL(rootURL: rootURL, scope: $0).path
        }
        XCTAssertEqual(Set(paths).count, 4)
        XCTAssertTrue(
            paths[0].hasSuffix(
                "/Curriculum/development/syntholo-local/en-US/catalog-snapshot-v1.json"
            )
        )

        let snapshot = try CurriculumTestSupport.snapshot()
        try await cache.replace(with: snapshot, for: primary)

        let primarySnapshot = try await cache.load(for: primary)
        let environmentSnapshot = try await cache.load(for: environment)
        let projectSnapshot = try await cache.load(for: project)
        let localeSnapshot = try await cache.load(for: locale)
        XCTAssertEqual(primarySnapshot, snapshot)
        XCTAssertNil(environmentSnapshot)
        XCTAssertNil(projectSnapshot)
        XCTAssertNil(localeSnapshot)
    }

    func testMissingCacheReturnsNilWithoutCreatingAQuarantine() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let clock = CacheClockRecorder(date: Self.fixedNow)
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { clock.now() }
        )

        let loaded = try await cache.load(for: scope)
        XCTAssertNil(loaded)
        XCTAssertEqual(clock.callCount, 0)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: cacheURL(rootURL: rootURL, scope: scope).path
            )
        )
    }

    func testCorruptBytesAreRejectedAndQuarantined() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"snapshot":"truncated""#.utf8).write(to: url)
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: scope).path
            )
        )
    }

    func testUnknownOrMissingEnvelopeFieldsFailClosed() async throws {
        for mutation in [
            EnvelopeMutation.unknownField,
            .missingField,
            .unknownSourceField,
        ] {
            let rootURL = try temporaryRoot()
            let scope = try launchScope()
            let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
            try await cache.replace(
                with: CurriculumTestSupport.snapshot(),
                for: scope
            )
            let url = cacheURL(rootURL: rootURL, scope: scope)
            var envelope = try object(at: url)
            switch mutation {
            case .unknownField:
                envelope["unexpected"] = true
            case .missingField:
                envelope.removeValue(forKey: "catalogVersionID")
            case .unknownSourceField:
                var source = envelope["source"] as! [String: Any]
                source["unexpected"] = true
                envelope["source"] = source
            }
            try data(from: envelope).write(to: url, options: .atomic)

            await assertCacheError(.corrupt) {
                _ = try await cache.load(for: scope)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testEscapedEquivalentDuplicateEnvelopeKeyIsRejected() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        let originalData = try Data(contentsOf: url)
        let original = try XCTUnwrap(String(data: originalData, encoding: .utf8))
        let duplicate = original.replacingOccurrences(
            of: #""envelopeVersion":1"#,
            with: #""envelopeVersion":1,"\u0065nvelopeVersion":1"#
        )
        XCTAssertNotEqual(duplicate, original)
        try Data(duplicate.utf8).write(to: url, options: .atomic)

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }
    }

    func testOversizedEnvelopeIsRejectedBeforeDecoding() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x20, count: 10 * 1_024 * 1_024 + 1)
            .write(to: url, options: .atomic)
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: scope).path
            )
        )
    }

    func testUnsupportedEnvelopeVersionIsRejectedAndQuarantined() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) { $0["envelopeVersion"] = 2 }

        await assertCacheError(
            .unsupportedEnvelopeVersion(found: 2, supported: 1)
        ) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: scope).path
            )
        )
    }

    func testWrongSourceEnvelopeIsRejectedEvenInsideTheRequestedDirectory() async throws {
        for mutation in SourceMutation.allCases {
            let rootURL = try temporaryRoot()
            let scope = try launchScope()
            let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
            try await cache.replace(
                with: CurriculumTestSupport.snapshot(),
                for: scope
            )
            let url = cacheURL(rootURL: rootURL, scope: scope)
            try mutateObject(at: url) { envelope in
                var source = envelope["source"] as! [String: Any]
                switch mutation {
                case .environment:
                    source["environment"] = "staging"
                case .projectID:
                    source["projectID"] = "syntholo-other"
                case .projectNumber:
                    source["projectNumber"] = "123456789012"
                case .locale:
                    envelope["locale"] = "fr-FR"
                }
                envelope["source"] = source
            }

            await assertCacheError(.wrongSource) {
                _ = try await cache.load(for: scope)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testHeaderSnapshotParityMismatchIsRejected() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) {
            $0["catalogVersionID"] = "catalog--en-us--v2"
        }

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }
    }

    func testMalformedGraphIsRejectedAfterEnvelopeParityPasses() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) { envelope in
            var snapshot = envelope["snapshot"] as! [String: Any]
            var programs = snapshot["programVersions"] as! [[String: Any]]
            let moduleID = (programs[0]["moduleVersionIDs"] as! [String])[0]
            programs[0]["moduleVersionIDs"] = [moduleID, moduleID]
            try CurriculumTestSupport.refreshContentDigest(&programs[0])
            snapshot["programVersions"] = programs
            envelope["snapshot"] = snapshot
            try synchronizeDigestManifest(
                in: &envelope,
                kind: "programVersion",
                versionID: programs[0]["programVersionID"] as! String,
                contentDigest: programs[0]["contentDigest"] as! String
            )
        }

        await assertInvalidSnapshotIssue(.duplicateReference) {
            _ = try await cache.load(for: scope)
        }
    }

    func testDocumentDigestMismatchIsRejectedAndQuarantined() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) { envelope in
            var snapshot = envelope["snapshot"] as! [String: Any]
            var programs = snapshot["programVersions"] as! [[String: Any]]
            programs[0]["title"] = "Tampered title without a matching digest"
            snapshot["programVersions"] = programs
            envelope["snapshot"] = snapshot
        }

        await assertInvalidSnapshotIssue(.digestMismatch) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDigestManifestMismatchIsRejectedBeforeReturningTheSnapshot() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) { envelope in
            var manifest = envelope["documentDigests"] as! [[String: Any]]
            manifest[0]["contentDigest"] = String(repeating: "a", count: 64)
            envelope["documentDigests"] = manifest
        }

        await assertCacheError(
            .digestManifestMismatch(identifier: "catalog--en-us--v1")
        ) {
            _ = try await cache.load(for: scope)
        }
    }

    func testDigestManifestOrderMultiplicityAndCompletenessAreExact() async throws {
        for mutation in ManifestMutation.allCases {
            let rootURL = try temporaryRoot()
            let scope = try launchScope()
            let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
            try await cache.replace(
                with: CurriculumTestSupport.snapshot(),
                for: scope
            )
            let url = cacheURL(rootURL: rootURL, scope: scope)
            try mutateObject(at: url) { envelope in
                var manifest = envelope["documentDigests"] as! [[String: Any]]
                switch mutation {
                case .reordered:
                    manifest.swapAt(0, 1)
                case .duplicate:
                    manifest.append(manifest[0])
                case .missing:
                    manifest.removeLast()
                }
                envelope["documentDigests"] = manifest
            }

            await assertDigestManifestError {
                _ = try await cache.load(for: scope)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testIncompatibleSnapshotIsRejectedAfterItsDigestIsRefreshed() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        try await cache.replace(with: CurriculumTestSupport.snapshot(), for: scope)
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try mutateObject(at: url) { envelope in
            var snapshot = envelope["snapshot"] as! [String: Any]
            var catalog = snapshot["catalogVersion"] as! [String: Any]
            catalog["minimumClientSchemaVersion"] = 2
            try CurriculumTestSupport.refreshContentDigest(&catalog)
            snapshot["catalogVersion"] = catalog
            envelope["snapshot"] = snapshot
            try synchronizeDigestManifest(
                in: &envelope,
                kind: "catalogVersion",
                versionID: catalog["catalogVersionID"] as! String,
                contentDigest: catalog["contentDigest"] as! String
            )
        }

        await assertInvalidSnapshotIssue(.minimumClientUnsupported) {
            _ = try await cache.load(for: scope)
        }
    }

    func testSavedTimestampOutsideTheSupportedRangeIsRejected() async throws {
        let invalidValues: [Int64] = [
            -62_135_596_800_001,
            253_402_300_800_000,
        ]
        for invalidValue in invalidValues {
            let rootURL = try temporaryRoot()
            let scope = try launchScope()
            let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
            try await cache.replace(
                with: CurriculumTestSupport.snapshot(),
                for: scope
            )
            let url = cacheURL(rootURL: rootURL, scope: scope)
            try mutateObject(at: url) {
                $0["savedAtUTCMilliseconds"] = NSNumber(value: invalidValue)
            }

            await assertCacheError(.corrupt) {
                _ = try await cache.load(for: scope)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testFailedAtomicWritePreservesThePriorValidSnapshot() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let fileSystem = FaultInjectingCurriculumCacheFileSystem()
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { Self.fixedNow },
            fileSystem: fileSystem
        )
        let first = try CurriculumTestSupport.snapshot()
        let second = try snapshot(programTitle: "This write must fail")
        try await cache.replace(with: first, for: scope)
        fileSystem.failWrites = true

        await assertCacheError(.writeFailed) {
            try await cache.replace(with: second, for: scope)
        }

        fileSystem.failWrites = false
        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, first)
    }

    func testTransientReadFailurePreservesThePriorValidSnapshot() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let fileSystem = FaultInjectingCurriculumCacheFileSystem()
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { Self.fixedNow },
            fileSystem: fileSystem
        )
        let snapshot = try CurriculumTestSupport.snapshot()
        try await cache.replace(with: snapshot, for: scope)
        fileSystem.failReads = true

        await assertCacheError(.readFailed) {
            _ = try await cache.load(for: scope)
        }

        let canonicalURL = cacheURL(rootURL: rootURL, scope: scope)
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonicalURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: scope).path
            )
        )
        fileSystem.failReads = false
        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, snapshot)
    }

    func testInvalidInjectedWriteClockPreservesThePriorValidSnapshot() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let clock = CacheClockRecorder(date: Self.fixedNow)
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { clock.now() }
        )
        let first = try CurriculumTestSupport.snapshot()
        let second = try snapshot(programTitle: "Invalid clock replacement")
        try await cache.replace(with: first, for: scope)
        clock.setDate(Date(timeIntervalSince1970: 253_402_300_800))

        await assertCacheError(.writeFailed) {
            try await cache.replace(with: second, for: scope)
        }

        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, first)
    }

    func testInvalidReplacementFailsBeforeTouchingThePriorValidSnapshot() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })
        let valid = try CurriculumTestSupport.snapshot()
        try await cache.replace(with: valid, for: scope)
        let invalid = try snapshotWithUnrefreshedProgramTitle()

        await assertInvalidSnapshotIssue(.digestMismatch) {
            try await cache.replace(with: invalid, for: scope)
        }

        let loaded = try await cache.load(for: scope)
        XCTAssertEqual(loaded, valid)
    }

    func testQuarantineNameUsesTheInjectedUTCMillisecondExactly() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let url = cacheURL(rootURL: rootURL, scope: scope)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: url)
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertEqual(
            quarantineURL(rootURL: rootURL, scope: scope).lastPathComponent,
            "catalog-snapshot-v1.invalid-1800000000125.json"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: scope).path
            )
        )
    }

    func testQuarantineFailureStaysInvalidAndDoesNotDeleteAnotherValidScope() async throws {
        let rootURL = try temporaryRoot()
        let validScope = try launchScope(projectID: "syntholo-valid")
        let invalidScope = try launchScope(projectID: "syntholo-invalid")
        let fileSystem = FaultInjectingCurriculumCacheFileSystem()
        let cache = FileCurriculumCache(
            rootURL: rootURL,
            now: { Self.fixedNow },
            fileSystem: fileSystem
        )
        let snapshot = try CurriculumTestSupport.snapshot()
        try await cache.replace(with: snapshot, for: validScope)
        try await cache.replace(with: snapshot, for: invalidScope)

        let invalidURL = cacheURL(rootURL: rootURL, scope: invalidScope)
        try Data("not-json".utf8).write(to: invalidURL, options: .atomic)
        fileSystem.failQuarantines = true

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: invalidScope)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: invalidURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: quarantineURL(rootURL: rootURL, scope: invalidScope).path
            )
        )
        let validLoaded = try await cache.load(for: validScope)
        XCTAssertEqual(validLoaded, snapshot)
    }

    func testExistingQuarantineCollisionDoesNotOverwriteOrValidateThePrimary() async throws {
        let rootURL = try temporaryRoot()
        let scope = try launchScope()
        let cacheURL = cacheURL(rootURL: rootURL, scope: scope)
        let quarantineURL = quarantineURL(rootURL: rootURL, scope: scope)
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let invalidData = Data("not-json".utf8)
        let priorQuarantine = Data("prior-quarantine".utf8)
        try invalidData.write(to: cacheURL)
        try priorQuarantine.write(to: quarantineURL)
        let cache = FileCurriculumCache(rootURL: rootURL, now: { Self.fixedNow })

        await assertCacheError(.corrupt) {
            _ = try await cache.load(for: scope)
        }

        XCTAssertEqual(try Data(contentsOf: cacheURL), invalidData)
        XCTAssertEqual(try Data(contentsOf: quarantineURL), priorQuarantine)
    }

    func testScopeRejectsUnsafeProjectPathComponents() throws {
        XCTAssertThrowsError(
            try CurriculumCacheScope(
                environment: .production,
                projectID: "../production",
                projectNumber: "123456789012",
                locale: CurriculumLocale("en-US")
            )
        ) { error in
            XCTAssertEqual(error as? CurriculumCacheError, .invalidScope)
        }
        XCTAssertThrowsError(
            try CurriculumCacheScope(
                environment: .production,
                projectID: "syntholo-production",
                projectNumber: "not/a/number",
                locale: CurriculumLocale("en-US")
            )
        ) { error in
            XCTAssertEqual(error as? CurriculumCacheError, .invalidScope)
        }
    }

    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyntholoCurriculumCacheTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func launchScope(
        projectID: String = "syntholo-local"
    ) throws -> CurriculumCacheScope {
        try CurriculumCacheScope(
            environment: .development,
            projectID: projectID,
            projectNumber: "emulator",
            locale: CurriculumLocale("en-US")
        )
    }

    private func cacheURL(
        rootURL: URL,
        scope: CurriculumCacheScope
    ) -> URL {
        FileCurriculumCache.cacheFileURL(rootURL: rootURL, scope: scope)
    }

    private func quarantineURL(
        rootURL: URL,
        scope: CurriculumCacheScope
    ) -> URL {
        cacheURL(rootURL: rootURL, scope: scope)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "catalog-snapshot-v1.invalid-1800000000125.json",
                isDirectory: false
            )
    }

    private func snapshot(programTitle: String) throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var programs = root["programVersions"] as! [[String: Any]]
        programs[0]["title"] = programTitle
        try CurriculumTestSupport.refreshContentDigest(&programs[0])
        root["programVersions"] = programs
        let data = try CurriculumTestSupport.data(from: root)
        let snapshot = try CurriculumJSONCodec.decodeSnapshot(from: data)
        try CurriculumValidator.validate(snapshot)
        return snapshot
    }

    private func snapshotWithUnrefreshedProgramTitle() throws -> CurriculumSnapshot {
        let data = try CurriculumTestSupport.mutatedPublishedClientData { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["title"] = "Tampered without digest refresh"
            root["programVersions"] = programs
        }
        return try CurriculumJSONCodec.decodeSnapshot(from: data)
    }

    private func object(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
    }

    private func data(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func mutateObject(
        at url: URL,
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws {
        var value = try object(at: url)
        try mutation(&value)
        try data(from: value).write(to: url, options: .atomic)
    }

    private func synchronizeDigestManifest(
        in envelope: inout [String: Any],
        kind: String,
        versionID: String,
        contentDigest: String
    ) throws {
        var manifest = try XCTUnwrap(
            envelope["documentDigests"] as? [[String: Any]]
        )
        let index = try XCTUnwrap(
            manifest.firstIndex {
                $0["kind"] as? String == kind
                    && $0["versionID"] as? String == versionID
            }
        )
        manifest[index]["contentDigest"] = contentDigest
        envelope["documentDigests"] = manifest
    }

    private func assertCacheError(
        _ expected: CurriculumCacheError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected cache error \(expected)")
        } catch {
            XCTAssertEqual(error as? CurriculumCacheError, expected)
        }
    }

    private func assertInvalidSnapshotIssue(
        _ expected: CurriculumValidationIssue.Code,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected invalid snapshot issue \(expected)")
        } catch let CurriculumCacheError.invalidSnapshot(issues) {
            XCTAssertTrue(
                issues.contains { $0.code == expected },
                "Expected \(expected), received \(issues)"
            )
        } catch {
            XCTFail("Expected invalid snapshot error, received \(error)")
        }
    }

    private func assertDigestManifestError(
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected digest manifest mismatch")
        } catch CurriculumCacheError.digestManifestMismatch {
            return
        } catch {
            XCTFail("Expected digest manifest mismatch, received \(error)")
        }
    }
}

private enum EnvelopeMutation {
    case unknownField
    case missingField
    case unknownSourceField
}

private enum SourceMutation: CaseIterable {
    case environment
    case projectID
    case projectNumber
    case locale
}

private enum ManifestMutation: CaseIterable {
    case reordered
    case duplicate
    case missing
}

private final class CacheClockRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    private var recordedCallCount = 0

    init(date: Date) {
        self.date = date
    }

    var callCount: Int {
        lock.withLock { recordedCallCount }
    }

    func now() -> Date {
        lock.withLock {
            recordedCallCount += 1
            return date
        }
    }

    func setDate(_ date: Date) {
        lock.withLock {
            self.date = date
        }
    }
}

private final class FaultInjectingCurriculumCacheFileSystem:
    CurriculumCacheFileSystem,
    @unchecked Sendable
{
    private enum Failure: Error {
        case injected
    }

    private let lock = NSLock()
    private var shouldFailReads = false
    private var shouldFailWrites = false
    private var shouldFailQuarantines = false
    private var shouldBlockAtomicWrites = false
    private let atomicWriteEntered = DispatchSemaphore(value: 0)
    private let atomicWriteRelease = DispatchSemaphore(value: 0)

    var failReads: Bool {
        get { lock.withLock { shouldFailReads } }
        set { lock.withLock { shouldFailReads = newValue } }
    }

    var failWrites: Bool {
        get { lock.withLock { shouldFailWrites } }
        set { lock.withLock { shouldFailWrites = newValue } }
    }

    var failQuarantines: Bool {
        get { lock.withLock { shouldFailQuarantines } }
        set { lock.withLock { shouldFailQuarantines = newValue } }
    }

    var blockAtomicWrites: Bool {
        get { lock.withLock { shouldBlockAtomicWrites } }
        set { lock.withLock { shouldBlockAtomicWrites = newValue } }
    }

    func waitUntilAtomicWriteIsBlocked() -> Bool {
        atomicWriteEntered.wait(timeout: .now() + 2) == .success
    }

    func releaseAtomicWrites() {
        atomicWriteRelease.signal()
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func readData(at url: URL, maximumBytes: Int) throws -> Data {
        if failReads {
            throw Failure.injected
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumBytes else {
            throw CurriculumCacheFileSystemError.inputTooLarge
        }
        return data
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func atomicallyReplace(with data: Data, at url: URL) throws {
        if blockAtomicWrites {
            atomicWriteEntered.signal()
            atomicWriteRelease.wait()
        }
        if failWrites {
            throw Failure.injected
        }
        try data.write(to: url, options: .atomic)
    }

    func quarantineItem(at sourceURL: URL, to destinationURL: URL) throws {
        if failQuarantines {
            throw Failure.injected
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
