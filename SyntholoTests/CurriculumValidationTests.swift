import Foundation
import XCTest
@testable import Syntholo

final class CurriculumValidationTests: XCTestCase {
    func testSharedJCSVectorsMatchCanonicalUTF8AndSHA256() throws {
        let vectors = try JSONDecoder().decode(
            DigestVectorFile.self,
            from: CurriculumTestSupport.digestVectorData()
        )

        XCTAssertEqual(vectors.schemaVersion, 1)
        XCTAssertEqual(vectors.vectors.count, 6)
        for vector in vectors.vectors {
            let canonical = try CurriculumCanonicalJSON.canonicalString(vector.value)
            XCTAssertEqual(canonical, vector.canonical, vector.name)
            XCTAssertEqual(
                CurriculumCanonicalJSON.sha256Hex(Data(canonical.utf8)),
                vector.sha256,
                vector.name
            )
        }
    }

    func testSyntheticLearnerGraphPassesWithNodeGoldenDigestsAndCatalogOrder() throws {
        let snapshot = try CurriculumTestSupport.snapshot()

        XCTAssertNoThrow(try CurriculumValidator.validate(snapshot))
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.catalogVersion).rawValue,
            "09ee3bde8966cf57e8c06c11e70c818661a30b1344bee08044dcffcda145ac0f"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.programVersions[0]).rawValue,
            "7da67775c59207f426fd295c3e322644eb3b39b23422aef6858871c01181c170"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.moduleVersions[0]).rawValue,
            "fb1206946b1146077ae57ef958d56e3c1c4aefff8baece1a04af7f6802b598c6"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.lessonVersions[0]).rawValue,
            "1dcc5c24fcc01fe41912750effd9252ff956e7e396c2c2774b5223cab87cfbb8"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.rubricVersions[0]).rawValue,
            "955d5ffbab96e7274f64b9b8b22fb835361851975d9c916b0a2325dca1f4819d"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(snapshot.assetVersions[0]).rawValue,
            "8eb3f6dfe240e7be691a74c48de572519284e29bace1ae601257bc0140d00515"
        )
        XCTAssertEqual(
            try CurriculumCanonicalJSON.payloadDigest(
                snapshot.assetVersions[0].payload
            ).rawValue,
            "69b953e837b2a1721ea158884fefc2162a65a63497e93731743ceae5f1d78018"
        )
        XCTAssertEqual(snapshot.assetVersions[0].byteCount, 292)
        XCTAssertEqual(
            snapshot.catalogVersion.programEntries.map(\.programVersionID),
            snapshot.programVersions.map(\.programVersionID)
        )

        let comingSoonData = try CurriculumTestSupport.comingSoonProgramData()
        let comingSoonProgram = try JSONDecoder().decode(
            CurriculumProgramVersion.self,
            from: comingSoonData
        )
        XCTAssertEqual(comingSoonProgram.catalogState, .comingSoon)
        XCTAssertTrue(comingSoonProgram.moduleVersionIDs.isEmpty)
        XCTAssertNil(comingSoonProgram.firstLessonVersionID)
        XCTAssertEqual(
            try CurriculumCanonicalJSON.contentDigest(comingSoonProgram).rawValue,
            "fec6dbef628d2f483b343a666c0293869a662344be51a9639994fc8d3d545419"
        )

        var twoProgramRoot = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var programs = twoProgramRoot["programVersions"] as! [[String: Any]]
        programs.append(try CurriculumTestSupport.object(from: comingSoonData))
        twoProgramRoot["programVersions"] = programs
        var catalog = twoProgramRoot["catalogVersion"] as! [String: Any]
        var entries = catalog["programEntries"] as! [[String: Any]]
        entries.append([
            "programPointerID": "synthetic-coming-soon--en-us",
            "programVersionID": "synthetic-coming-soon--en-us--v1",
        ])
        catalog["programEntries"] = entries
        try CurriculumTestSupport.refreshContentDigest(&catalog)
        twoProgramRoot["catalogVersion"] = catalog
        let twoProgramSnapshot = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: twoProgramRoot)
        )
        XCTAssertNoThrow(try CurriculumValidator.validate(twoProgramSnapshot))
        XCTAssertEqual(
            twoProgramSnapshot.catalogVersion.programEntries.map(\.programVersionID),
            twoProgramSnapshot.programVersions.map(\.programVersionID)
        )
    }

    func testDuplicateIdentityReferenceAndBlockOrderMatrixFailsClosed() throws {
        try assertValidationIssue(.duplicateIdentity) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs.append(programs[0])
            root["programVersions"] = programs
        }
        try assertValidationIssue(.duplicateIdentity) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var duplicateStableLesson = lessons[0]
            duplicateStableLesson["lessonVersionID"] =
                "synthetic-lesson--en-us--v2"
            duplicateStableLesson["version"] = 2
            lessons.append(duplicateStableLesson)
            root["lessonVersions"] = lessons

            var modules = root["moduleVersions"] as! [[String: Any]]
            modules[0]["lessonVersionIDs"] = [
                "synthetic-lesson--en-us--v1",
                "synthetic-lesson--en-us--v2",
            ]
            root["moduleVersions"] = modules
        }
        try assertValidationIssue(.invalidBound) { root in
            let program = (root["programVersions"] as! [[String: Any]])[0]
            root["programVersions"] = Array(repeating: program, count: 6)
        }
        try assertValidationIssue(.invalidBound) { root in
            let lesson = (root["lessonVersions"] as! [[String: Any]])[0]
            root["lessonVersions"] = Array(repeating: lesson, count: 129)
        }
        try assertValidationIssue(.duplicateReference) { root in
            var catalog = root["catalogVersion"] as! [String: Any]
            var entries = catalog["programEntries"] as! [[String: Any]]
            entries.append(entries[0])
            catalog["programEntries"] = entries
            root["catalogVersion"] = catalog
        }
        try assertValidationIssue(.orderMismatch) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var blocks = lessons[0]["blocks"] as! [[String: Any]]
            blocks[1]["order"] = 9
            lessons[0]["blocks"] = blocks
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.orderMismatch) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            var shell = programs[0]
            shell["programVersionID"] = "synthetic-shell--en-us--v1"
            shell["programID"] = "synthetic-shell"
            shell["catalogState"] = "comingSoon"
            shell["moduleVersionIDs"] = []
            shell["firstLessonVersionID"] = NSNull()
            programs.append(shell)
            root["programVersions"] = [programs[1], programs[0]]

            var catalog = root["catalogVersion"] as! [String: Any]
            var entries = catalog["programEntries"] as! [[String: Any]]
            entries.append([
                "programPointerID": "synthetic-shell--en-us",
                "programVersionID": "synthetic-shell--en-us--v1",
            ])
            catalog["programEntries"] = entries
            root["catalogVersion"] = catalog
        }
        try assertValidationIssue(.identityMismatch) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["programVersionID"] = "wrong-program--en-us--v1"
            root["programVersions"] = programs
        }
        try assertValidationIssue(.ownershipMismatch) { root in
            var modules = root["moduleVersions"] as! [[String: Any]]
            modules[0]["programID"] = "wrong-program"
            root["moduleVersions"] = modules
        }
        var orphanRoot = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var modules = orphanRoot["moduleVersions"] as! [[String: Any]]
        var orphan = modules[0]
        orphan["moduleVersionID"] = "orphan-module--en-us--v1"
        orphan["moduleID"] = "orphan-module"
        try CurriculumTestSupport.refreshContentDigest(&orphan)
        modules.append(orphan)
        orphanRoot["moduleVersions"] = modules
        try assertValidationIssue(.orphanDocument, root: orphanRoot)
        try assertValidationIssue(.foundationsCatalogInvalid) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["catalogState"] = "comingSoon"
            programs[0]["moduleVersionIDs"] = []
            programs[0]["firstLessonVersionID"] = NSNull()
            root["programVersions"] = programs
        }
    }

    func testPrerequisiteDAGReachabilityAndFirstLessonMatrixFailsClosed() throws {
        try assertValidationIssue(.prerequisiteViolation) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            lessons[0]["prerequisiteLessonIDs"] = ["synthetic-lesson"]
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.firstLessonInvalid) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["firstLessonVersionID"] = "missing-lesson--en-us--v1"
            root["programVersions"] = programs
        }

        let validChainRoot = try CurriculumTestSupport.twoLessonPublishedClientObject()
        let validChain = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: validChainRoot)
        )
        XCTAssertNoThrow(try CurriculumValidator.validate(validChain))

        var forwardReferenceRoot = validChainRoot
        var forwardLessons = forwardReferenceRoot["lessonVersions"]
            as! [[String: Any]]
        forwardLessons[0]["prerequisiteLessonIDs"] = ["synthetic-lesson-two"]
        try CurriculumTestSupport.refreshContentDigest(&forwardLessons[0])
        forwardReferenceRoot["lessonVersions"] = forwardLessons
        try assertValidationIssue(
            .prerequisiteViolation,
            root: forwardReferenceRoot
        )

        var cycleRoot = forwardReferenceRoot
        var cycleLessons = cycleRoot["lessonVersions"] as! [[String: Any]]
        cycleLessons[1]["prerequisiteLessonIDs"] = ["synthetic-lesson"]
        try CurriculumTestSupport.refreshContentDigest(&cycleLessons[1])
        cycleRoot["lessonVersions"] = cycleLessons
        try assertValidationIssue(.prerequisiteViolation, root: cycleRoot)

        var missingReferenceRoot = validChainRoot
        var missingReferenceLessons = missingReferenceRoot["lessonVersions"]
            as! [[String: Any]]
        missingReferenceLessons[1]["prerequisiteLessonIDs"] = ["missing-lesson"]
        try CurriculumTestSupport.refreshContentDigest(&missingReferenceLessons[1])
        missingReferenceRoot["lessonVersions"] = missingReferenceLessons
        let missingReferenceSnapshot = try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: missingReferenceRoot)
        )
        XCTAssertThrowsError(
            try CurriculumValidator.validate(missingReferenceSnapshot)
        ) { error in
            guard let validationError = error as? CurriculumValidationError else {
                return XCTFail("Expected CurriculumValidationError, received \(error)")
            }
            XCTAssertTrue(
                validationError.issues.contains(
                    CurriculumValidationIssue(
                        code: .brokenReference,
                        identifier: "missing-lesson"
                    )
                )
            )
        }
    }

    func testAssetRubricAndPublicScoringReferenceMatrixFailsClosed() throws {
        try assertValidationIssue(.brokenReference) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            lessons[0]["rubricVersionID"] = "missing-rubric--en-us--v1"
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.assetReferenceInvalid) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            lessons[0]["assetVersionIDs"] = []
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.scoringContractInvalid) { root in
            var rubrics = root["rubricVersions"] as! [[String: Any]]
            var scoring = rubrics[0]["clientScoringContract"] as! [String: Any]
            scoring["correctOptionID"] = "missing-option"
            rubrics[0]["clientScoringContract"] = scoring
            root["rubricVersions"] = rubrics
        }
        try assertValidationIssue(.rightsInvalid) { root in
            var assets = root["assetVersions"] as! [[String: Any]]
            var rights = assets[0]["rights"] as! [String: Any]
            rights["origin"] = "licensed"
            assets[0]["rights"] = rights
            root["assetVersions"] = assets
        }
        for invalidURL in [
            "https://example.com/%",
            "https://example.com/|",
            "https://example.com/[",
            "https://example.com/é",
        ] {
            try assertValidationIssue(.rightsInvalid) { root in
                var assets = root["assetVersions"] as! [[String: Any]]
                var rights = assets[0]["rights"] as! [String: Any]
                rights["origin"] = "licensed"
                rights["sourceURL"] = invalidURL
                rights["license"] = "Synthetic license"
                assets[0]["rights"] = rights
                root["assetVersions"] = assets
            }
        }

        var reusableAssetRoot = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var reusableLessons = reusableAssetRoot["lessonVersions"]
            as! [[String: Any]]
        var reusableBlocks = reusableLessons[0]["blocks"]
            as! [[String: Any]]
        var secondDiagram = reusableBlocks[1]
        secondDiagram["blockID"] = "synthetic-diagram-block-two"
        secondDiagram["order"] = 2
        reusableBlocks[2]["order"] = 3
        reusableBlocks.insert(secondDiagram, at: 2)
        reusableLessons[0]["blocks"] = reusableBlocks
        try CurriculumTestSupport.refreshContentDigest(&reusableLessons[0])
        reusableAssetRoot["lessonVersions"] = reusableLessons
        XCTAssertNoThrow(
            try CurriculumValidator.validate(
                CurriculumJSONCodec.decodeSnapshot(
                    from: CurriculumTestSupport.data(from: reusableAssetRoot)
                )
            )
        )

        var emptyAuthorityRoot = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var emptyAuthorityAssets = emptyAuthorityRoot["assetVersions"]
            as! [[String: Any]]
        var emptyAuthorityRights = emptyAuthorityAssets[0]["rights"]
            as! [String: Any]
        emptyAuthorityRights["origin"] = "licensed"
        emptyAuthorityRights["sourceURL"] = "https://?q"
        emptyAuthorityRights["license"] = "Synthetic license"
        emptyAuthorityAssets[0]["rights"] = emptyAuthorityRights
        try CurriculumTestSupport.refreshContentDigest(&emptyAuthorityAssets[0])
        emptyAuthorityRoot["assetVersions"] = emptyAuthorityAssets
        XCTAssertNoThrow(
            try CurriculumValidator.validate(
                CurriculumJSONCodec.decodeSnapshot(
                    from: CurriculumTestSupport.data(from: emptyAuthorityRoot)
                )
            )
        )
    }

    func testMalformedBlockCompletionAndBoundMatrixFailsClosed() throws {
        try assertValidationIssue(.malformedBlock) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var blocks = lessons[0]["blocks"] as! [[String: Any]]
            blocks.removeFirst()
            lessons[0]["blocks"] = blocks
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.completionRuleInvalid) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var completion = lessons[0]["completionRule"] as! [String: Any]
            completion["requiredBlockIDs"] = ["synthetic-concept"]
            lessons[0]["completionRule"] = completion
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.invalidBound) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            lessons[0]["expectedDurationMinutes"] = 181
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.invalidBound) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var blocks = lessons[0]["blocks"] as! [[String: Any]]
            blocks[2]["prompt"] = String(repeating: "p", count: 1_001)
            lessons[0]["blocks"] = blocks
            root["lessonVersions"] = lessons
        }
    }

    func testDocumentPayloadAndOrderingDigestMismatchMatrixFailsClosed() throws {
        try assertValidationIssue(.digestMismatch) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["title"] = "Changed synthetic title"
            root["programVersions"] = programs
        }
        try assertValidationIssue(.payloadDigestMismatch) { root in
            var assets = root["assetVersions"] as! [[String: Any]]
            var payload = assets[0]["payload"] as! [String: Any]
            var nodes = payload["nodes"] as! [[String: Any]]
            nodes[0]["label"] = "Changed synthetic node"
            payload["nodes"] = nodes
            assets[0]["payload"] = payload
            root["assetVersions"] = assets
        }

        var oversizedPayloadRoot = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var oversizedAssets = oversizedPayloadRoot["assetVersions"]
            as! [[String: Any]]
        var oversizedPayload = oversizedAssets[0]["payload"]
            as! [String: Any]
        var oversizedNodes = oversizedPayload["nodes"] as! [[String: Any]]
        oversizedNodes[0]["label"] = String(repeating: "a", count: 132_000)
        oversizedPayload["nodes"] = oversizedNodes
        let oversizedPayloadValue = try JSONDecoder().decode(
            CanonicalJSONValue.self,
            from: CurriculumTestSupport.data(from: oversizedPayload)
        )
        let oversizedCanonicalPayload = try CurriculumCanonicalJSON.canonicalBytes(
            oversizedPayloadValue
        )
        oversizedAssets[0]["payload"] = oversizedPayload
        oversizedAssets[0]["byteCount"] = oversizedCanonicalPayload.count
        oversizedAssets[0]["payloadDigest"] = CurriculumCanonicalJSON.sha256Hex(
            oversizedCanonicalPayload
        )
        try CurriculumTestSupport.refreshContentDigest(&oversizedAssets[0])
        oversizedPayloadRoot["assetVersions"] = oversizedAssets
        try assertValidationIssue(
            .documentSizeExceeded,
            root: oversizedPayloadRoot
        )

        try assertValidationIssue(.digestMismatch) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            var blocks = lessons[0]["blocks"] as! [[String: Any]]
            var options = blocks[2]["options"] as! [[String: Any]]
            options.reverse()
            blocks[2]["options"] = options
            lessons[0]["blocks"] = blocks
            root["lessonVersions"] = lessons
        }
        try assertValidationIssue(.documentSizeExceeded) { root in
            var assets = root["assetVersions"] as! [[String: Any]]
            assets[0]["accessibilityDescription"] = String(
                repeating: "a",
                count: 270_000
            )
            root["assetVersions"] = assets
        }
    }

    func testLocaleStateSchemaCompatibilityCanonicalStringAndUnknownFieldMatrixFailsClosed() throws {
        try assertValidationIssue(.localeMismatch) { root in
            root["locale"] = "fr-FR"
        }
        try assertValidationIssue(.publicationStateInvalid) { root in
            var catalog = root["catalogVersion"] as! [String: Any]
            catalog["publicationState"] = "draft"
            root["catalogVersion"] = catalog
        }
        try assertValidationIssue(.unsupportedSchema) { root in
            var catalog = root["catalogVersion"] as! [String: Any]
            catalog["schemaVersion"] = 2
            root["catalogVersion"] = catalog
        }
        try assertValidationIssue(.minimumClientUnsupported) { root in
            var catalog = root["catalogVersion"] as! [String: Any]
            catalog["minimumClientSchemaVersion"] = 2
            root["catalogVersion"] = catalog
        }

        let documentCollections = [
            "programVersions",
            "moduleVersions",
            "lessonVersions",
            "rubricVersions",
            "assetVersions",
        ]
        for collection in documentCollections {
            try assertValidationIssue(.unsupportedSchema) { root in
                var documents = root[collection] as! [[String: Any]]
                documents[0]["schemaVersion"] = 2
                root[collection] = documents
            }
            try assertValidationIssue(.minimumClientUnsupported) { root in
                var documents = root[collection] as! [[String: Any]]
                documents[0]["minimumClientSchemaVersion"] = 2
                root[collection] = documents
            }
            try assertValidationIssue(.localeMismatch) { root in
                var documents = root[collection] as! [[String: Any]]
                documents[0]["locale"] = "fr-FR"
                root[collection] = documents
            }
            try assertValidationIssue(.publicationStateInvalid) { root in
                var documents = root[collection] as! [[String: Any]]
                documents[0]["publicationState"] = "draft"
                root[collection] = documents
            }
        }

        for seconds in [-62_135_596_800, 253_402_300_799] {
            var root = try CurriculumTestSupport.object(
                from: CurriculumTestSupport.publishedClientData()
            )
            var catalog = root["catalogVersion"] as! [String: Any]
            var timestamp = catalog["publishedAt"] as! [String: Any]
            timestamp["seconds"] = seconds
            catalog["publishedAt"] = timestamp
            root["catalogVersion"] = catalog
            let snapshot = try CurriculumJSONCodec.decodeSnapshot(
                from: CurriculumTestSupport.data(from: root)
            )
            XCTAssertNoThrow(try CurriculumValidator.validate(snapshot))
        }
        for seconds in [-62_135_596_801, 253_402_300_800] {
            try assertValidationIssue(.invalidBound) { root in
                var catalog = root["catalogVersion"] as! [String: Any]
                var timestamp = catalog["publishedAt"] as! [String: Any]
                timestamp["seconds"] = seconds
                catalog["publishedAt"] = timestamp
                root["catalogVersion"] = catalog
            }
        }
        for nanoseconds in [-1, 1_000_000_000] {
            try assertValidationIssue(.invalidBound) { root in
                var catalog = root["catalogVersion"] as! [String: Any]
                var timestamp = catalog["publishedAt"] as! [String: Any]
                timestamp["nanoseconds"] = nanoseconds
                catalog["publishedAt"] = timestamp
                root["catalogVersion"] = catalog
            }
        }
        try assertValidationIssue(.invalidText) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs[0]["title"] = "Cafe\u{301}"
            root["programVersions"] = programs
        }

        let unknownField = try CurriculumTestSupport.mutatedPublishedClientData {
            var catalog = $0["catalogVersion"] as! [String: Any]
            catalog["unknown"] = true
            $0["catalogVersion"] = catalog
        }
        XCTAssertThrowsError(try CurriculumJSONCodec.decodeSnapshot(from: unknownField))

        let floatingInteger = Data(
            String(
                data: try CurriculumTestSupport.publishedClientData(),
                encoding: .utf8
            )!
            .replacingOccurrences(
                of: "\"expectedDurationMinutes\": 1",
                with: "\"expectedDurationMinutes\": 1.0"
            )
            .utf8
        )
        XCTAssertThrowsError(try CurriculumJSONCodec.decodeSnapshot(from: floatingInteger))
    }

    private func assertValidationIssue(
        _ expected: CurriculumValidationIssue.Code,
        mutation: (inout [String: Any]) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        mutation(&root)
        try assertValidationIssue(expected, root: root, file: file, line: line)
    }

    private func assertValidationIssue(
        _ expected: CurriculumValidationIssue.Code,
        root: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let data = try CurriculumTestSupport.data(from: root)
        let snapshot = try CurriculumJSONCodec.decodeSnapshot(from: data)
        do {
            try CurriculumValidator.validate(snapshot)
            XCTFail("Expected validation issue \(expected)", file: file, line: line)
        } catch let error as CurriculumValidationError {
            XCTAssertTrue(
                error.issues.contains { $0.code == expected },
                "Expected \(expected), received \(error.issues)",
                file: file,
                line: line
            )
        }
    }
}

private struct DigestVectorFile: Decodable {
    let schemaVersion: Int
    let vectors: [DigestVector]
}

private struct DigestVector: Decodable {
    let name: String
    let value: CanonicalJSONValue
    let canonical: String
    let sha256: String
}
