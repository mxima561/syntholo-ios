import Foundation
import XCTest
@testable import Syntholo

final class CurriculumPresentationTests: XCTestCase {
    func testCatalogPresentationUsesManifestOrderWhenProgramBackingArrayIsReordered() throws {
        let snapshot = try catalogSnapshotWithComingSoonFirst()
        let presentation = try XCTUnwrap(
            CurriculumCatalogPresentation(snapshot: snapshot)
        )

        XCTAssertEqual(
            presentation.programs.map(\.id),
            snapshot.catalogVersion.programEntries.map(\.programVersionID)
        )
        XCTAssertNotEqual(
            presentation.programs.map(\.id),
            snapshot.programVersions.map(\.programVersionID)
        )
        XCTAssertEqual(presentation.programs.first?.availability, .comingSoon)

        let availableProgram = try XCTUnwrap(
            snapshot.programVersions.first(where: {
                $0.catalogState == .available
            })
        )
        XCTAssertEqual(
            presentation.programs.last?.availability,
            .available(
                ProgramVersionReference(
                    locale: snapshot.locale,
                    catalogVersionID: snapshot.catalogVersion.catalogVersionID,
                    programVersionID: availableProgram.programVersionID
                )
            )
        )
    }

    func testProgramAndModulePresentationsUseOrderedReferencesNotBackingArrays() throws {
        let moduleSnapshot = try twoModuleSnapshotWithSecondReferenceFirst()
        let program = try XCTUnwrap(moduleSnapshot.programVersions.first)
        let programReference = ProgramVersionReference(
            locale: moduleSnapshot.locale,
            catalogVersionID: moduleSnapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID
        )
        let programPresentation = try XCTUnwrap(
            ProgramDetailPresentation(
                snapshot: moduleSnapshot,
                reference: programReference
            )
        )

        XCTAssertEqual(
            programPresentation.modules.map(\.id),
            program.moduleVersionIDs
        )
        XCTAssertNotEqual(
            programPresentation.modules.map(\.id),
            moduleSnapshot.moduleVersions.map(\.moduleVersionID)
        )
        XCTAssertEqual(
            programPresentation.modules.map(\.route),
            program.moduleVersionIDs.map {
                ModuleVersionReference(
                    locale: moduleSnapshot.locale,
                    catalogVersionID: moduleSnapshot.catalogVersion.catalogVersionID,
                    programVersionID: program.programVersionID,
                    moduleVersionID: $0
                )
            }
        )

        let lessonSnapshot = try twoLessonSnapshotWithSecondReferenceFirst()
        let lessonProgram = try XCTUnwrap(lessonSnapshot.programVersions.first)
        let module = try XCTUnwrap(lessonSnapshot.moduleVersions.first)
        let moduleReference = ModuleVersionReference(
            locale: lessonSnapshot.locale,
            catalogVersionID: lessonSnapshot.catalogVersion.catalogVersionID,
            programVersionID: lessonProgram.programVersionID,
            moduleVersionID: module.moduleVersionID
        )
        let modulePresentation = try XCTUnwrap(
            ModuleDetailPresentation(
                snapshot: lessonSnapshot,
                reference: moduleReference
            )
        )

        XCTAssertEqual(
            modulePresentation.lessons.map(\.id),
            module.lessonVersionIDs
        )
        XCTAssertNotEqual(
            modulePresentation.lessons.map(\.id),
            lessonSnapshot.lessonVersions.map(\.lessonVersionID)
        )
        let expectedLessonRoutes = try module.lessonVersionIDs.map {
            lessonVersionID in
            let lesson = try XCTUnwrap(
                lessonSnapshot.lessonVersions.first(where: {
                    $0.lessonVersionID == lessonVersionID
                })
            )
            return LessonVersionReference(
                locale: lessonSnapshot.locale,
                catalogVersionID: lessonSnapshot.catalogVersion.catalogVersionID,
                programVersionID: lessonProgram.programVersionID,
                moduleVersionID: module.moduleVersionID,
                lessonVersionID: lessonVersionID,
                rubricVersionID: lesson.rubricVersionID
            )
        }
        XCTAssertEqual(
            modulePresentation.lessons.map(\.route),
            expectedLessonRoutes
        )
    }

    func testComingSoonProgramIsHonestAndHasNoDescendantRowsOrRoutes() throws {
        let snapshot = try catalogSnapshotWithComingSoonFirst()
        let program = try XCTUnwrap(
            snapshot.programVersions.first(where: {
                $0.catalogState == .comingSoon
            })
        )
        let catalogPresentation = try XCTUnwrap(
            CurriculumCatalogPresentation(snapshot: snapshot)
        )
        let row = try XCTUnwrap(
            catalogPresentation.programs.first(where: {
                $0.id == program.programVersionID
            })
        )
        let detail = try XCTUnwrap(
            ProgramDetailPresentation(
                snapshot: snapshot,
                reference: ProgramVersionReference(
                    locale: snapshot.locale,
                    catalogVersionID: snapshot.catalogVersion.catalogVersionID,
                    programVersionID: program.programVersionID
                )
            )
        )

        XCTAssertEqual(row.availability, .comingSoon)
        XCTAssertTrue(program.moduleVersionIDs.isEmpty)
        XCTAssertNil(program.firstLessonVersionID)
        XCTAssertTrue(detail.isComingSoon)
        XCTAssertTrue(detail.modules.isEmpty)
    }

    func testLessonProjectionPreservesStableBlockOptionAndExactAssetIdentity() throws {
        let snapshot = try snapshotWithDecoyAssetBeforeReferencedAsset()
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let presentation = try XCTUnwrap(
            LessonPreviewPresentation(
                snapshot: snapshot,
                reference: lessonReference(in: snapshot)
            )
        )

        XCTAssertEqual(
            presentation.blocks.map(\.id),
            lesson.blocks.map(\.blockID)
        )

        guard case let .stillDiagram(sourceDiagram) = lesson.blocks[1],
              case let .diagram(diagram) = presentation.blocks[1] else {
            return XCTFail("Expected the fixture's diagram at its referenced order.")
        }
        let sourceAsset = try XCTUnwrap(
            snapshot.assetVersions.first(where: {
                $0.assetVersionID == sourceDiagram.assetVersionID
            })
        )
        XCTAssertEqual(diagram.id, sourceDiagram.blockID)
        XCTAssertEqual(diagram.assetVersionID, sourceDiagram.assetVersionID)
        XCTAssertEqual(diagram.assetVersionID, sourceAsset.assetVersionID)
        XCTAssertNotEqual(
            diagram.assetVersionID,
            snapshot.assetVersions.first?.assetVersionID
        )
        XCTAssertEqual(
            diagram.textAlternative,
            sourceAsset.accessibilityDescription
        )
        XCTAssertEqual(
            diagram.nodes.map(\.id),
            sourceAsset.payload.nodes.map(\.nodeID)
        )
        XCTAssertEqual(
            diagram.connectors.map(\.id),
            sourceAsset.payload.connectors.map(\.connectorID)
        )

        guard case let .singleAnswerQuestion(sourceQuestion) = lesson.blocks[2],
              case let .question(question) = presentation.blocks[2] else {
            return XCTFail("Expected the fixture's question at its referenced order.")
        }
        XCTAssertEqual(question.id, sourceQuestion.blockID)
        XCTAssertEqual(
            question.options.map(\.id),
            sourceQuestion.options.map(\.optionID)
        )
    }

    func testRoutesRejectCatalogProgramModuleLessonAndRubricHierarchyMismatches() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let program = try XCTUnwrap(snapshot.programVersions.first)
        XCTAssertNil(
            ProgramDetailPresentation(
                snapshot: snapshot,
                reference: ProgramVersionReference(
                    locale: snapshot.locale,
                    catalogVersionID: CurriculumCatalogVersionID(
                        locale: snapshot.locale,
                        version: try CurriculumVersion(2)
                    ),
                    programVersionID: program.programVersionID
                )
            )
        )

        let twoProgramSnapshot = try catalogSnapshotWithComingSoonFirst()
        let availableProgram = try XCTUnwrap(
            twoProgramSnapshot.programVersions.first(where: {
                $0.catalogState == .available
            })
        )
        let comingSoonProgram = try XCTUnwrap(
            twoProgramSnapshot.programVersions.first(where: {
                $0.catalogState == .comingSoon
            })
        )
        let availableModule = try XCTUnwrap(
            twoProgramSnapshot.moduleVersions.first
        )
        XCTAssertTrue(
            availableProgram.moduleVersionIDs.contains(
                availableModule.moduleVersionID
            )
        )
        XCTAssertNil(
            ModuleDetailPresentation(
                snapshot: twoProgramSnapshot,
                reference: ModuleVersionReference(
                    locale: twoProgramSnapshot.locale,
                    catalogVersionID: twoProgramSnapshot.catalogVersion.catalogVersionID,
                    programVersionID: comingSoonProgram.programVersionID,
                    moduleVersionID: availableModule.moduleVersionID
                )
            )
        )

        let twoModuleSnapshot = try twoModuleSnapshotWithSecondReferenceFirst()
        let routeProgram = try XCTUnwrap(twoModuleSnapshot.programVersions.first)
        let wrongParentModule = twoModuleSnapshot.moduleVersions[1]
        let lesson = try XCTUnwrap(twoModuleSnapshot.lessonVersions.first)
        XCTAssertTrue(
            wrongParentModule.lessonVersionIDs.contains(lesson.lessonVersionID)
        )
        XCTAssertNotEqual(wrongParentModule.moduleID, lesson.moduleID)
        XCTAssertNil(
            LessonPreviewPresentation(
                snapshot: twoModuleSnapshot,
                reference: LessonVersionReference(
                    locale: twoModuleSnapshot.locale,
                    catalogVersionID: twoModuleSnapshot.catalogVersion.catalogVersionID,
                    programVersionID: routeProgram.programVersionID,
                    moduleVersionID: wrongParentModule.moduleVersionID,
                    lessonVersionID: lesson.lessonVersionID,
                    rubricVersionID: lesson.rubricVersionID
                )
            )
        )

        let twoRubricSnapshot = try snapshotWithUnreferencedRubric()
        let unreferencedRubric = twoRubricSnapshot.rubricVersions[1]
        XCTAssertNil(
            LessonPreviewPresentation(
                snapshot: twoRubricSnapshot,
                reference: LessonVersionReference(
                    locale: twoRubricSnapshot.locale,
                    catalogVersionID: twoRubricSnapshot.catalogVersion.catalogVersionID,
                    programVersionID: twoRubricSnapshot.programVersions[0].programVersionID,
                    moduleVersionID: twoRubricSnapshot.moduleVersions[0].moduleVersionID,
                    lessonVersionID: twoRubricSnapshot.lessonVersions[0].lessonVersionID,
                    rubricVersionID: unreferencedRubric.rubricVersionID
                )
            )
        )
    }

    func testMissingReferencedDataFailsClosedInsteadOfHidingRows() throws {
        let catalogBase = try catalogSnapshotWithComingSoonFirst()
        let missingCatalogProgram = try snapshot(from: catalogBase) { root in
            var programs = root["programVersions"] as! [[String: Any]]
            programs.removeLast()
            root["programVersions"] = programs
        }
        XCTAssertNil(
            CurriculumCatalogPresentation(snapshot: missingCatalogProgram),
            "A missing manifest program must invalidate the catalog, not hide one row."
        )

        let programBase = try twoModuleSnapshotWithSecondReferenceFirst()
        let missingProgramModule = try snapshot(from: programBase) { root in
            var modules = root["moduleVersions"] as! [[String: Any]]
            modules.removeLast()
            root["moduleVersions"] = modules
        }
        let missingProgramModuleReference = try programReference(
            in: missingProgramModule
        )
        XCTAssertNil(
            ProgramDetailPresentation(
                snapshot: missingProgramModule,
                reference: missingProgramModuleReference
            ),
            "A missing referenced module must invalidate the program, not hide one row."
        )

        let moduleBase = try twoLessonSnapshotWithSecondReferenceFirst()
        let missingModuleLesson = try snapshot(from: moduleBase) { root in
            var lessons = root["lessonVersions"] as! [[String: Any]]
            lessons.removeLast()
            root["lessonVersions"] = lessons
        }
        let missingModuleLessonReference = try moduleReference(
            in: missingModuleLesson
        )
        XCTAssertNil(
            ModuleDetailPresentation(
                snapshot: missingModuleLesson,
                reference: missingModuleLessonReference
            ),
            "A missing referenced lesson must invalidate the module, not hide one row."
        )

        let base = try CurriculumTestSupport.snapshot()
        let missingRubric = try snapshot(from: base) {
            $0["rubricVersions"] = []
        }
        let missingRubricReference = try lessonReference(in: missingRubric)
        XCTAssertNil(
            LessonPreviewPresentation(
                snapshot: missingRubric,
                reference: missingRubricReference
            ),
            "A missing exact rubric must invalidate the lesson preview."
        )

        let missingAsset = try snapshot(from: base) {
            $0["assetVersions"] = []
        }
        let missingAssetReference = try lessonReference(in: missingAsset)
        XCTAssertNil(
            LessonPreviewPresentation(
                snapshot: missingAsset,
                reference: missingAssetReference
            ),
            "A missing referenced diagram asset must invalidate the lesson preview."
        )
    }

    func testSanitizedLessonPresentationExposesCriteriaWithoutScoringOrPrivatePayload() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let rubric = try XCTUnwrap(snapshot.rubricVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let presentation = try XCTUnwrap(
            LessonPreviewPresentation(
                snapshot: snapshot,
                reference: lessonReference(in: snapshot)
            )
        )

        XCTAssertEqual(presentation.title, lesson.title)
        XCTAssertEqual(presentation.objective, lesson.objective)
        XCTAssertEqual(
            presentation.criteria.map(\.id),
            rubric.criteria.map(\.criterionID)
        )
        XCTAssertEqual(
            presentation.criteria.map(\.title),
            rubric.criteria.map(\.title)
        )
        XCTAssertEqual(
            presentation.criteria.map(\.description),
            rubric.criteria.map(\.description)
        )

        XCTAssertEqual(
            storedPropertyNames(of: presentation),
            [
                "title",
                "objective",
                "expectedDurationMinutes",
                "lessonVersion",
                "rubricVersion",
                "blocks",
                "criteria",
            ]
        )
        let criterion = try XCTUnwrap(presentation.criteria.first)
        XCTAssertEqual(
            storedPropertyNames(of: criterion),
            ["id", "title", "description"]
        )

        guard case let .question(question) = presentation.blocks[2],
              let option = question.options.first,
              case let .diagram(diagram) = presentation.blocks[1] else {
            return XCTFail("Expected sanitized diagram and question projections.")
        }
        XCTAssertEqual(
            storedPropertyNames(of: question),
            ["id", "prompt", "options"]
        )
        XCTAssertEqual(storedPropertyNames(of: option), ["id", "text"])
        XCTAssertEqual(
            storedPropertyNames(of: diagram),
            [
                "id",
                "assetVersionID",
                "title",
                "textAlternative",
                "nodes",
                "connectors",
            ]
        )

        let reflectedPresentation = String(reflecting: presentation)
        XCTAssertFalse(
            reflectedPresentation.contains(
                rubric.clientScoringContract.correctFeedback
            )
        )
        XCTAssertFalse(
            reflectedPresentation.contains(
                rubric.clientScoringContract.incorrectFeedback
            )
        )
        XCTAssertFalse(
            reflectedPresentation.contains(
                rubric.evaluationContractVersionID.rawValue
            )
        )
        let asset = try XCTUnwrap(snapshot.assetVersions.first)
        XCTAssertFalse(reflectedPresentation.contains(asset.rights.creator))
        XCTAssertFalse(
            reflectedPresentation.contains(asset.contentDigest.rawValue)
        )
    }
}

private extension CurriculumPresentationTests {
    func catalogSnapshotWithComingSoonFirst() throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var catalog = root["catalogVersion"] as! [String: Any]
        let originalEntry = (catalog["programEntries"] as! [[String: Any]])[0]
        let comingSoonObject = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.comingSoonProgramData()
        )
        let comingSoonProgram = try JSONDecoder().decode(
            CurriculumProgramVersion.self,
            from: CurriculumTestSupport.data(from: comingSoonObject)
        )
        let comingSoonPointer = CurriculumProgramPointerID(
            stableID: comingSoonProgram.programID,
            locale: comingSoonProgram.locale
        )

        var programs = root["programVersions"] as! [[String: Any]]
        programs.append(comingSoonObject)
        root["programVersions"] = programs
        catalog["programEntries"] = [
            [
                "programPointerID": comingSoonPointer.rawValue,
                "programVersionID": comingSoonProgram.programVersionID.rawValue,
            ],
            originalEntry,
        ]
        root["catalogVersion"] = catalog
        return try decodeSnapshot(from: root)
    }

    func twoModuleSnapshotWithSecondReferenceFirst() throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var modules = root["moduleVersions"] as! [[String: Any]]
        let firstModuleVersionID = modules[0]["moduleVersionID"] as! String
        var secondModule = modules[0]
        let secondModuleVersionID = "synthetic-module-two--en-us--v1"
        secondModule["moduleVersionID"] = secondModuleVersionID
        secondModule["moduleID"] = "synthetic-module-two"
        modules.append(secondModule)
        root["moduleVersions"] = modules

        var programs = root["programVersions"] as! [[String: Any]]
        programs[0]["moduleVersionIDs"] = [
            secondModuleVersionID,
            firstModuleVersionID,
        ]
        root["programVersions"] = programs
        return try decodeSnapshot(from: root)
    }

    func twoLessonSnapshotWithSecondReferenceFirst() throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.twoLessonPublishedClientObject()
        var modules = root["moduleVersions"] as! [[String: Any]]
        let lessonVersionIDs = modules[0]["lessonVersionIDs"] as! [String]
        modules[0]["lessonVersionIDs"] = Array(lessonVersionIDs.reversed())
        root["moduleVersions"] = modules
        return try decodeSnapshot(from: root)
    }

    func snapshotWithDecoyAssetBeforeReferencedAsset() throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var assets = root["assetVersions"] as! [[String: Any]]
        var decoy = assets[0]
        decoy["assetVersionID"] = "synthetic-diagram-decoy--en-us--v1"
        decoy["assetID"] = "synthetic-diagram-decoy"
        assets.insert(decoy, at: 0)
        root["assetVersions"] = assets
        return try decodeSnapshot(from: root)
    }

    func snapshotWithUnreferencedRubric() throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumTestSupport.publishedClientData()
        )
        var rubrics = root["rubricVersions"] as! [[String: Any]]
        var unreferencedRubric = rubrics[0]
        unreferencedRubric["rubricVersionID"] =
            "synthetic-unreferenced-rubric--en-us--v1"
        unreferencedRubric["rubricID"] = "synthetic-unreferenced-rubric"
        rubrics.append(unreferencedRubric)
        root["rubricVersions"] = rubrics
        return try decodeSnapshot(from: root)
    }

    func snapshot(
        from snapshot: CurriculumSnapshot,
        mutating mutation: (inout [String: Any]) -> Void
    ) throws -> CurriculumSnapshot {
        var root = try CurriculumTestSupport.object(
            from: CurriculumJSONCodec.encodeSnapshot(snapshot)
        )
        mutation(&root)
        return try decodeSnapshot(from: root)
    }

    func decodeSnapshot(from object: [String: Any]) throws -> CurriculumSnapshot {
        try CurriculumJSONCodec.decodeSnapshot(
            from: CurriculumTestSupport.data(from: object)
        )
    }

    func programReference(
        in snapshot: CurriculumSnapshot
    ) throws -> ProgramVersionReference {
        let program = try XCTUnwrap(snapshot.programVersions.first)
        return ProgramVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID
        )
    }

    func moduleReference(
        in snapshot: CurriculumSnapshot
    ) throws -> ModuleVersionReference {
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let moduleVersionID = try XCTUnwrap(
            program.moduleVersionIDs.first
        )
        return ModuleVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: moduleVersionID
        )
    }

    func lessonReference(
        in snapshot: CurriculumSnapshot
    ) throws -> LessonVersionReference {
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first(where: {
            program.moduleVersionIDs.contains($0.moduleVersionID)
        }))
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first(where: {
            module.lessonVersionIDs.contains($0.lessonVersionID)
        }))
        return LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: lesson.rubricVersionID
        )
    }

    func storedPropertyNames<T>(of value: T) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }
}
