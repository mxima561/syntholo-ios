import Foundation
import XCTest
@testable import Syntholo

final class CurriculumModelsTests: XCTestCase {
    func testIdentifierMatrixEnforcesStableLocalePointerVersionAndDigestBoundaries() throws {
        let stableMaximum = String(repeating: "a", count: 64)
        let locale = try CurriculumLocale("en-US")
        let version = try CurriculumVersion(2_147_483_647)

        XCTAssertEqual(try CurriculumStableID("abc").rawValue, "abc")
        XCTAssertEqual(try CurriculumStableID(stableMaximum).rawValue, stableMaximum)
        XCTAssertThrowsError(try CurriculumStableID("ab"))
        XCTAssertThrowsError(try CurriculumStableID(String(repeating: "a", count: 65)))
        XCTAssertThrowsError(try CurriculumStableID("Uppercase"))
        XCTAssertThrowsError(try CurriculumStableID("bad--id"))
        XCTAssertThrowsError(try CurriculumStableID("bad/path"))

        XCTAssertEqual(locale.token.rawValue, "en-us")
        XCTAssertEqual(try CurriculumLocale(requesting: "fr-fr").rawValue, "fr-FR")
        XCTAssertEqual(
            try CurriculumLocale(requesting: "zh-hant-tw").rawValue,
            "zh-Hant-TW"
        )
        XCTAssertEqual(
            try CurriculumLocale(requesting: "X-Private").rawValue,
            "x-private"
        )
        XCTAssertThrowsError(try CurriculumLocale("en-us"))
        XCTAssertThrowsError(try CurriculumLocale(requesting: "bad_locale"))
        XCTAssertThrowsError(
            try CurriculumLocale(requesting: "sl-rozaj-ROZAJ")
        )

        XCTAssertEqual(version.rawValue, 2_147_483_647)
        XCTAssertThrowsError(try CurriculumVersion(0))
        XCTAssertThrowsError(try CurriculumVersion(2_147_483_648))

        let pointer = CurriculumProgramPointerID(
            stableID: try CurriculumStableID("ai-foundations"),
            locale: locale
        )
        XCTAssertEqual(pointer.rawValue, "ai-foundations--en-us")
        XCTAssertEqual(
            try CurriculumProgramPointerID(pointer.rawValue),
            pointer
        )
        XCTAssertThrowsError(try CurriculumProgramPointerID("ai-foundations/en-us"))

        let versionID = CurriculumVersionID(
            stableID: try CurriculumStableID("ai-foundations"),
            locale: locale,
            version: version
        )
        XCTAssertEqual(
            versionID.rawValue,
            "ai-foundations--en-us--v2147483647"
        )
        XCTAssertEqual(try CurriculumVersionID(versionID.rawValue), versionID)
        XCTAssertThrowsError(try CurriculumVersionID("ai-foundations--en-us--v0"))
        XCTAssertThrowsError(
            try CurriculumVersionID("ai-foundations--en-us--v2147483648")
        )

        let lexicalReferencePrefix = String(repeating: "a", count: 80)
        XCTAssertNoThrow(
            try CurriculumProgramPointerID("\(lexicalReferencePrefix)--en-us")
        )
        XCTAssertNoThrow(
            try CurriculumVersionID("\(lexicalReferencePrefix)--en-us--v1")
        )
        XCTAssertThrowsError(try CurriculumStableID(lexicalReferencePrefix))

        let catalogID = CurriculumCatalogVersionID(locale: locale, version: version)
        XCTAssertEqual(catalogID.rawValue, "catalog--en-us--v2147483647")
        XCTAssertEqual(try CurriculumCatalogVersionID(catalogID.rawValue), catalogID)

        XCTAssertNoThrow(
            try CurriculumDigest(String(repeating: "a", count: 64))
        )
        XCTAssertThrowsError(
            try CurriculumDigest(String(repeating: "A", count: 64))
        )
        XCTAssertThrowsError(
            try CurriculumDigest(String(repeating: "a", count: 63))
        )
    }

    func testPublishedModelsDecodeExactFieldsFromTheSyntheticLearnerProjection() throws {
        let data = try CurriculumTestSupport.publishedClientData()
        let snapshot = try CurriculumJSONCodec.decodeSnapshot(from: data)

        XCTAssertEqual(snapshot.locale.rawValue, "en-US")
        XCTAssertEqual(snapshot.catalogPointerID.rawValue, "en-us")
        XCTAssertEqual(
            snapshot.catalogVersion.catalogVersionID.rawValue,
            "catalog--en-us--v1"
        )
        XCTAssertEqual(snapshot.programVersions.count, 1)
        XCTAssertEqual(snapshot.moduleVersions.count, 1)
        XCTAssertEqual(snapshot.lessonVersions.count, 1)
        XCTAssertEqual(snapshot.rubricVersions.count, 1)
        XCTAssertEqual(snapshot.assetVersions.count, 1)
        XCTAssertEqual(
            snapshot.programVersions[0].title,
            "SYNTHETIC-CONTRACT-FIXTURE-NEVER-PUBLISH"
        )
        XCTAssertEqual(snapshot.lessonVersions[0].blocks.count, 3)
        guard case let .singleAnswerQuestion(question) =
            snapshot.lessonVersions[0].blocks[2] else {
            return XCTFail("Expected the closed single-answer block case.")
        }
        XCTAssertEqual(question.options.map(\.optionID.rawValue), [
            "synthetic-option-a",
            "synthetic-option-b",
        ])

        let raw = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(raw.contains("evaluationContractVersions"))
        XCTAssertFalse(raw.contains("evaluationContractID"))
        XCTAssertNil(
            Bundle.main.url(
                forResource: "minimal-curriculum-v1.published-client",
                withExtension: "json"
            )
        )
        XCTAssertNil(
            Bundle.main.url(
                forResource: "curriculum-v1.digest-vectors",
                withExtension: "json"
            )
        )
        XCTAssertNil(
            Bundle.main.url(
                forResource: "minimal-coming-soon-program-v1.published-client",
                withExtension: "json"
            )
        )
    }

    func testClosedUnionsPreserveRequiredNullAndRejectUnknownKeysOrDiscriminators() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let encoded = try CurriculumJSONCodec.encodeSnapshot(snapshot)
        let root = try CurriculumTestSupport.object(from: encoded)
        let assets = try XCTUnwrap(root["assetVersions"] as? [[String: Any]])
        let payload = try XCTUnwrap(assets[0]["payload"] as? [String: Any])
        let connectors = try XCTUnwrap(payload["connectors"] as? [[String: Any]])
        let rights = try XCTUnwrap(assets[0]["rights"] as? [String: Any])

        XCTAssertTrue(connectors[0]["label"] is NSNull)
        XCTAssertTrue(rights["sourceURL"] is NSNull)
        XCTAssertTrue(rights["license"] is NSNull)

        let omissionData = try CurriculumTestSupport.mutatedPublishedClientData { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var blocks = lessons[0]["blocks"] as! [[String: Any]]
            blocks[0].removeValue(forKey: "heading")
            lessons[0]["blocks"] = blocks
            root["lessonVersions"] = lessons
        }
        let omissionSnapshot = try CurriculumJSONCodec.decodeSnapshot(from: omissionData)
        let omissionEncoded = try CurriculumJSONCodec.encodeSnapshot(omissionSnapshot)
        let omissionRoot = try CurriculumTestSupport.object(from: omissionEncoded)
        let omissionLessons = omissionRoot["lessonVersions"] as! [[String: Any]]
        let omissionBlocks = omissionLessons[0]["blocks"] as! [[String: Any]]
        XCTAssertNil(omissionBlocks[0]["heading"])

        let invalidMutations: [(inout [String: Any]) -> Void] = [
            { $0["unknown"] = true },
            { root in
                var catalog = root["catalogVersion"] as! [String: Any]
                var entries = catalog["programEntries"] as! [[String: Any]]
                entries[0]["unknown"] = true
                catalog["programEntries"] = entries
                root["catalogVersion"] = catalog
            },
            { root in
                var catalog = root["catalogVersion"] as! [String: Any]
                var timestamp = catalog["publishedAt"] as! [String: Any]
                timestamp["unknown"] = true
                catalog["publishedAt"] = timestamp
                root["catalogVersion"] = catalog
            },
            { root in
                var programs = root["programVersions"] as! [[String: Any]]
                programs[0]["unknown"] = true
                root["programVersions"] = programs
            },
            { root in
                var modules = root["moduleVersions"] as! [[String: Any]]
                modules[0]["unknown"] = true
                root["moduleVersions"] = modules
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                lessons[0]["unknown"] = true
                root["lessonVersions"] = lessons
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var completion = lessons[0]["completionRule"] as! [String: Any]
                completion["unknown"] = true
                lessons[0]["completionRule"] = completion
                root["lessonVersions"] = lessons
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var blocks = lessons[0]["blocks"] as! [[String: Any]]
                blocks[0]["unknown"] = "value"
                lessons[0]["blocks"] = blocks
                root["lessonVersions"] = lessons
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var blocks = lessons[0]["blocks"] as! [[String: Any]]
                var options = blocks[2]["options"] as! [[String: Any]]
                options[0]["unknown"] = true
                blocks[2]["options"] = options
                lessons[0]["blocks"] = blocks
                root["lessonVersions"] = lessons
            },
            { root in
                var rubrics = root["rubricVersions"] as! [[String: Any]]
                rubrics[0]["unknown"] = true
                root["rubricVersions"] = rubrics
            },
            { root in
                var rubrics = root["rubricVersions"] as! [[String: Any]]
                var criteria = rubrics[0]["criteria"] as! [[String: Any]]
                criteria[0]["unknown"] = true
                rubrics[0]["criteria"] = criteria
                root["rubricVersions"] = rubrics
            },
            { root in
                var rubrics = root["rubricVersions"] as! [[String: Any]]
                var scoring = rubrics[0]["clientScoringContract"] as! [String: Any]
                scoring["unknown"] = true
                rubrics[0]["clientScoringContract"] = scoring
                root["rubricVersions"] = rubrics
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                assets[0]["unknown"] = true
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var payload = assets[0]["payload"] as! [String: Any]
                payload["unknown"] = true
                assets[0]["payload"] = payload
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var payload = assets[0]["payload"] as! [String: Any]
                var nodes = payload["nodes"] as! [[String: Any]]
                nodes[0]["unknown"] = true
                payload["nodes"] = nodes
                assets[0]["payload"] = payload
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var payload = assets[0]["payload"] as! [String: Any]
                var connectors = payload["connectors"] as! [[String: Any]]
                connectors[0]["unknown"] = true
                payload["connectors"] = connectors
                assets[0]["payload"] = payload
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var rights = assets[0]["rights"] as! [String: Any]
                rights["unknown"] = true
                assets[0]["rights"] = rights
                root["assetVersions"] = assets
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var blocks = lessons[0]["blocks"] as! [[String: Any]]
                blocks[0]["type"] = "video"
                lessons[0]["blocks"] = blocks
                root["lessonVersions"] = lessons
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var completion = lessons[0]["completionRule"] as! [String: Any]
                completion["kind"] = "unknown"
                lessons[0]["completionRule"] = completion
                root["lessonVersions"] = lessons
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var payload = assets[0]["payload"] as! [String: Any]
                var connectors = payload["connectors"] as! [[String: Any]]
                connectors[0].removeValue(forKey: "label")
                payload["connectors"] = connectors
                assets[0]["payload"] = payload
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var rights = assets[0]["rights"] as! [String: Any]
                rights.removeValue(forKey: "sourceURL")
                assets[0]["rights"] = rights
                root["assetVersions"] = assets
            },
            { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var rights = assets[0]["rights"] as! [String: Any]
                rights.removeValue(forKey: "license")
                assets[0]["rights"] = rights
                root["assetVersions"] = assets
            },
            { root in
                var programs = root["programVersions"] as! [[String: Any]]
                programs[0].removeValue(forKey: "firstLessonVersionID")
                root["programVersions"] = programs
            },
            { root in
                var lessons = root["lessonVersions"] as! [[String: Any]]
                var blocks = lessons[0]["blocks"] as! [[String: Any]]
                blocks[0]["heading"] = NSNull()
                lessons[0]["blocks"] = blocks
                root["lessonVersions"] = lessons
            },
        ]

        for mutation in invalidMutations {
            let data = try CurriculumTestSupport.mutatedPublishedClientData(mutation)
            XCTAssertThrowsError(try CurriculumJSONCodec.decodeSnapshot(from: data))
        }

        XCTAssertThrowsError(
            try CurriculumJSONCodec.decodeSnapshot(
                from: Data(repeating: 0x20, count: 9 * 1_024 * 1_024 + 1)
            )
        ) { error in
            XCTAssertEqual(
                error as? CurriculumJSONCodecError,
                .inputTooLarge(maximumBytes: 9 * 1_024 * 1_024)
            )
        }

        let duplicateEscapedKey = Data(
            #"{"locale":"en-US","\u006cocale":"en-US"}"#.utf8
        )
        XCTAssertThrowsError(
            try CurriculumJSONCodec.decodeSnapshot(from: duplicateEscapedKey)
        ) { error in
            XCTAssertEqual(
                error as? CurriculumJSONCodecError,
                .duplicateObjectKey
            )
        }

        let oversizedObject = Data(
            ("{" + (0...32).map { "\"key\($0)\":null" }.joined(separator: ",") + "}")
                .utf8
        )
        XCTAssertThrowsError(
            try CurriculumJSONCodec.decodeSnapshot(from: oversizedObject)
        ) { error in
            XCTAssertEqual(
                error as? CurriculumJSONCodecError,
                .excessiveContainerItems(maximum: 32)
            )
        }

        let oversizedArray = Data(
            ("[" + Array(repeating: "0", count: 181).joined(separator: ",") + "]")
                .utf8
        )
        XCTAssertThrowsError(
            try CurriculumJSONCodec.decodeSnapshot(from: oversizedArray)
        ) { error in
            XCTAssertEqual(
                error as? CurriculumJSONCodecError,
                .excessiveContainerItems(maximum: 180)
            )
        }

        let raw = try XCTUnwrap(
            String(data: CurriculumTestSupport.publishedClientData(), encoding: .utf8)
        )
        let integerMarker = Data("\"expectedDurationMinutes\": ".utf8)
        for replacement in ["1.0", "1e0"] {
            let nonInteger = Data(
                raw.replacingOccurrences(
                    of: "\"expectedDurationMinutes\": 1",
                    with: "\"expectedDurationMinutes\": \(replacement)"
                ).utf8
            )
            let expectedOffset = try XCTUnwrap(
                nonInteger.range(of: integerMarker)?.upperBound
            )
            XCTAssertThrowsError(
                try CurriculumJSONCodec.decodeSnapshot(from: nonInteger)
            ) { error in
                XCTAssertEqual(
                    error as? CurriculumJSONCodecError,
                    .nonIntegerNumber(offset: expectedOffset)
                )
            }
        }

        let booleanInteger = Data(
            raw.replacingOccurrences(
                of: "\"expectedDurationMinutes\": 1",
                with: "\"expectedDurationMinutes\": true"
            ).utf8
        )
        XCTAssertThrowsError(
            try CurriculumJSONCodec.decodeSnapshot(from: booleanInteger)
        ) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("Expected integer type mismatch, received \(error)")
            }
        }
    }

    func testDomainAndRepositoryBoundaryValuesAreHashableEquatableAndSendable() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()

        assertContract(snapshot)
        assertContract(snapshot.catalogVersion)
        assertContract(snapshot.programVersions[0])
        assertContract(snapshot.moduleVersions[0])
        assertContract(snapshot.lessonVersions[0])
        assertContract(snapshot.rubricVersions[0])
        assertContract(snapshot.assetVersions[0])
        XCTAssertEqual(Set([snapshot, snapshot]).count, 1)

        let repository = FixtureCurriculumRepository(events: [
            .saved(snapshot),
            .fresh(snapshot),
        ])
        var received: [CurriculumLoadEvent] = []
        for await event in repository.load(locale: snapshot.locale) {
            received.append(event)
        }

        XCTAssertEqual(received, [.saved(snapshot), .fresh(snapshot)])
        XCTAssertEqual(
            CurriculumLoadEvent.updateRequired(requiredSchema: 2, saved: snapshot),
            .updateRequired(requiredSchema: 2, saved: snapshot)
        )
        XCTAssertEqual(CurriculumLoadEvent.empty, .empty)
        XCTAssertEqual(
            CurriculumLoadEvent.unavailable(
                error: .minimumClientUnsupported(required: 2, supported: 1),
                saved: snapshot
            ),
            .unavailable(
                error: .minimumClientUnsupported(required: 2, supported: 1),
                saved: snapshot
            )
        )
    }

    private func assertContract<T: Codable & Equatable & Hashable & Sendable>(
        _ value: T
    ) {
        XCTAssertEqual(value, value)
    }
}

private struct FixtureCurriculumRepository: CurriculumRepository {
    let events: [CurriculumLoadEvent]

    func load(locale: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

enum CurriculumTestSupport {
    static func publishedClientData() throws -> Data {
        try resourceData(named: "minimal-curriculum-v1.published-client")
    }

    static func digestVectorData() throws -> Data {
        try resourceData(named: "curriculum-v1.digest-vectors")
    }

    static func comingSoonProgramData() throws -> Data {
        try resourceData(named: "minimal-coming-soon-program-v1.published-client")
    }

    static func snapshot() throws -> CurriculumSnapshot {
        try CurriculumJSONCodec.decodeSnapshot(from: publishedClientData())
    }

    static func object(from data: Data) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    static func data(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func mutatedPublishedClientData(
        _ mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        var root = try object(from: publishedClientData())
        mutation(&root)
        return try data(from: root)
    }

    static func twoLessonPublishedClientObject() throws -> [String: Any] {
        var root = try object(from: publishedClientData())
        var lessons = root["lessonVersions"] as! [[String: Any]]
        var secondLesson = lessons[0]
        secondLesson["lessonVersionID"] = "synthetic-lesson-two--en-us--v1"
        secondLesson["lessonID"] = "synthetic-lesson-two"
        secondLesson["title"] = "Synthetic contract lesson two"
        secondLesson["prerequisiteLessonIDs"] = ["synthetic-lesson"]
        try refreshContentDigest(&secondLesson)
        lessons.append(secondLesson)
        root["lessonVersions"] = lessons

        var modules = root["moduleVersions"] as! [[String: Any]]
        modules[0]["lessonVersionIDs"] = [
            "synthetic-lesson--en-us--v1",
            "synthetic-lesson-two--en-us--v1",
        ]
        try refreshContentDigest(&modules[0])
        root["moduleVersions"] = modules
        return root
    }

    static func refreshContentDigest(
        _ document: inout [String: Any]
    ) throws {
        var digestInput = document
        digestInput.removeValue(forKey: "contentDigest")
        digestInput.removeValue(forKey: "publishedAt")
        let value = try JSONDecoder().decode(
            CanonicalJSONValue.self,
            from: data(from: digestInput)
        )
        let canonical = try CurriculumCanonicalJSON.canonicalString(value)
        document["contentDigest"] = CurriculumCanonicalJSON.sha256Hex(
            Data(canonical.utf8)
        )
    }

    private static func resourceData(named name: String) throws -> Data {
        let bundle = Bundle(for: CurriculumModelsTests.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json"),
            "Missing test-only resource \(name).json"
        )
        return try Data(contentsOf: url)
    }
}
