import Foundation

struct CurriculumValidationIssue: Equatable, Hashable, Sendable {
    enum Code: String, Codable, Equatable, Hashable, Sendable {
        case duplicateIdentity
        case duplicateReference
        case identityMismatch
        case orderMismatch
        case ownershipMismatch
        case prerequisiteViolation
        case firstLessonInvalid
        case brokenReference
        case orphanDocument
        case foundationsCatalogInvalid
        case assetReferenceInvalid
        case scoringContractInvalid
        case malformedBlock
        case completionRuleInvalid
        case rightsInvalid
        case invalidBound
        case documentSizeExceeded
        case digestMismatch
        case payloadDigestMismatch
        case localeMismatch
        case publicationStateInvalid
        case unsupportedSchema
        case minimumClientUnsupported
        case invalidText
    }

    let code: Code
    let identifier: String?
}

struct CurriculumValidationError: Error, Equatable, Sendable {
    let issues: [CurriculumValidationIssue]
}

enum CurriculumValidator {
    static func validate(_ snapshot: CurriculumSnapshot) throws {
        var validation = SnapshotValidation(snapshot: snapshot)
        validation.run()
        guard validation.issues.isEmpty else {
            throw CurriculumValidationError(issues: validation.issues)
        }
    }
}

private struct SnapshotValidation {
    private static let supportedSchemaVersion = CurriculumSchema.currentVersion
    private static let launchLocale = "en-US"
    private static let foundationsProgramID = "ai-foundations"

    let snapshot: CurriculumSnapshot
    private(set) var issues: [CurriculumValidationIssue] = []
    private var issueSet = Set<CurriculumValidationIssue>()

    init(snapshot: CurriculumSnapshot) {
        self.snapshot = snapshot
    }

    mutating func run() {
        validateSnapshotHeader()
        guard validateSnapshotBounds() else { return }
        validateIdentityUniqueness()
        validateDocuments()
        validateGraph()
        validateDigestsAndSizes()
    }

    private mutating func add(
        _ code: CurriculumValidationIssue.Code,
        _ identifier: String? = nil
    ) {
        let issue = CurriculumValidationIssue(code: code, identifier: identifier)
        if issueSet.insert(issue).inserted {
            issues.append(issue)
        }
    }

    private mutating func validateSnapshotHeader() {
        if snapshot.locale.rawValue != Self.launchLocale ||
            snapshot.catalogPointerID.rawValue != snapshot.locale.token.rawValue ||
            snapshot.catalogVersion.locale != snapshot.locale {
            add(.localeMismatch, snapshot.catalogVersion.catalogVersionID.rawValue)
        }

        if snapshot.catalogVersion.catalogVersionID.rawValue !=
            CurriculumCatalogVersionID(
                locale: snapshot.catalogVersion.locale,
                version: snapshot.catalogVersion.version
            ).rawValue {
            add(.identityMismatch, snapshot.catalogVersion.catalogVersionID.rawValue)
        }

        validateCommon(
            locale: snapshot.catalogVersion.locale,
            publicationState: snapshot.catalogVersion.publicationState,
            schemaVersion: snapshot.catalogVersion.schemaVersion,
            minimumClientSchemaVersion: snapshot.catalogVersion.minimumClientSchemaVersion,
            timestamp: snapshot.catalogVersion.publishedAt,
            identifier: snapshot.catalogVersion.catalogVersionID.rawValue
        )

        if !(1...5).contains(snapshot.catalogVersion.programEntries.count) {
            add(.invalidBound, snapshot.catalogVersion.catalogVersionID.rawValue)
        }
        if snapshot.catalogVersion.programEntries.map(\.programPointerID).hasDuplicates ||
            snapshot.catalogVersion.programEntries.map(\.programVersionID).hasDuplicates {
            add(.duplicateReference, snapshot.catalogVersion.catalogVersionID.rawValue)
        }
    }

    private mutating func validateSnapshotBounds() -> Bool {
        let immutableDocumentCount = 1
            + snapshot.programVersions.count
            + snapshot.moduleVersions.count
            + snapshot.lessonVersions.count
            + snapshot.rubricVersions.count
            + snapshot.assetVersions.count
        var valid = (1...5).contains(snapshot.catalogVersion.programEntries.count) &&
            (1...5).contains(snapshot.programVersions.count) &&
            snapshot.moduleVersions.count <= 48 &&
            snapshot.lessonVersions.count <= 128 &&
            snapshot.rubricVersions.count <= 128 &&
            snapshot.assetVersions.count <= 128 &&
            immutableDocumentCount <= 180

        for program in snapshot.programVersions {
            let countIsValid = program.catalogState == .available
                ? (1...24).contains(program.moduleVersionIDs.count)
                : program.moduleVersionIDs.isEmpty
            valid = valid && countIsValid
        }
        for module in snapshot.moduleVersions {
            valid = valid && (1...64).contains(module.lessonVersionIDs.count)
        }
        for lesson in snapshot.lessonVersions {
            valid = valid &&
                lesson.prerequisiteLessonIDs.count <= 16 &&
                (1...40).contains(lesson.blocks.count) &&
                lesson.assetVersionIDs.count <= 128 &&
                (1...20).contains(lesson.completionRule.requiredBlockIDs.count)
            for block in lesson.blocks {
                if case let .singleAnswerQuestion(question) = block {
                    valid = valid && (2...8).contains(question.options.count)
                }
            }
        }
        for rubric in snapshot.rubricVersions {
            valid = valid && (1...12).contains(rubric.criteria.count)
        }
        for asset in snapshot.assetVersions {
            valid = valid &&
                (1...12).contains(asset.payload.nodes.count) &&
                asset.payload.connectors.count <= 24
        }

        if !valid {
            add(.invalidBound, "snapshot")
        }
        return valid
    }

    private mutating func validateIdentityUniqueness() {
        validateIdentityArray(
            snapshot.programVersions,
            exact: { $0.programVersionID },
            stable: { $0.programID },
            identifier: "programVersions"
        )
        validateIdentityArray(
            snapshot.moduleVersions,
            exact: { $0.moduleVersionID },
            stable: { $0.moduleID },
            identifier: "moduleVersions"
        )
        validateIdentityArray(
            snapshot.lessonVersions,
            exact: { $0.lessonVersionID },
            stable: { $0.lessonID },
            identifier: "lessonVersions"
        )
        validateIdentityArray(
            snapshot.rubricVersions,
            exact: { $0.rubricVersionID },
            stable: { $0.rubricID },
            identifier: "rubricVersions"
        )
        validateIdentityArray(
            snapshot.assetVersions,
            exact: { $0.assetVersionID },
            stable: { $0.assetID },
            identifier: "assetVersions"
        )
    }

    private mutating func validateIdentityArray<Value, Exact: Hashable, Stable: Hashable>(
        _ values: [Value],
        exact: (Value) -> Exact,
        stable: (Value) -> Stable,
        identifier: String
    ) {
        if values.map(exact).hasDuplicates || values.map(stable).hasDuplicates {
            add(.duplicateIdentity, identifier)
        }
    }

    private mutating func validateDocuments() {
        for program in snapshot.programVersions {
            validateCommon(
                locale: program.locale,
                publicationState: program.publicationState,
                schemaVersion: program.schemaVersion,
                minimumClientSchemaVersion: program.minimumClientSchemaVersion,
                timestamp: program.publishedAt,
                identifier: program.programVersionID.rawValue
            )
            validateDerivedID(
                program.programVersionID,
                stableID: program.programID,
                locale: program.locale,
                version: program.version
            )
            validateText(program.title, range: 1...120, identifier: program.programVersionID.rawValue)
            validateText(program.promise, range: 1...500, identifier: program.programVersionID.rawValue)
            if program.moduleVersionIDs.hasDuplicates {
                add(.duplicateReference, program.programVersionID.rawValue)
            }
            let validModuleCount = program.catalogState == .available
                ? (1...24).contains(program.moduleVersionIDs.count)
                : program.moduleVersionIDs.isEmpty
            if !validModuleCount {
                add(.invalidBound, program.programVersionID.rawValue)
            }
            if program.catalogState == .comingSoon,
               program.firstLessonVersionID != nil {
                add(.firstLessonInvalid, program.programVersionID.rawValue)
            }
        }

        for module in snapshot.moduleVersions {
            validateCommon(
                locale: module.locale,
                publicationState: module.publicationState,
                schemaVersion: module.schemaVersion,
                minimumClientSchemaVersion: module.minimumClientSchemaVersion,
                timestamp: module.publishedAt,
                identifier: module.moduleVersionID.rawValue
            )
            validateDerivedID(
                module.moduleVersionID,
                stableID: module.moduleID,
                locale: module.locale,
                version: module.version
            )
            validateText(module.title, range: 1...120, identifier: module.moduleVersionID.rawValue)
            validateText(module.summary, range: 1...500, identifier: module.moduleVersionID.rawValue)
            if !(1...64).contains(module.lessonVersionIDs.count) {
                add(.invalidBound, module.moduleVersionID.rawValue)
            }
            if module.lessonVersionIDs.hasDuplicates {
                add(.duplicateReference, module.moduleVersionID.rawValue)
            }
        }

        for lesson in snapshot.lessonVersions {
            validateCommon(
                locale: lesson.locale,
                publicationState: lesson.publicationState,
                schemaVersion: lesson.schemaVersion,
                minimumClientSchemaVersion: lesson.minimumClientSchemaVersion,
                timestamp: lesson.publishedAt,
                identifier: lesson.lessonVersionID.rawValue
            )
            validateDerivedID(
                lesson.lessonVersionID,
                stableID: lesson.lessonID,
                locale: lesson.locale,
                version: lesson.version
            )
            validateText(lesson.title, range: 1...120, identifier: lesson.lessonVersionID.rawValue)
            validateText(lesson.objective, range: 1...500, identifier: lesson.lessonVersionID.rawValue)
            if !(1...180).contains(lesson.expectedDurationMinutes) ||
                lesson.prerequisiteLessonIDs.count > 16 ||
                !(1...40).contains(lesson.blocks.count) ||
                lesson.assetVersionIDs.count > 128 {
                add(.invalidBound, lesson.lessonVersionID.rawValue)
            }
            if lesson.prerequisiteLessonIDs.hasDuplicates ||
                lesson.assetVersionIDs.hasDuplicates {
                add(.duplicateReference, lesson.lessonVersionID.rawValue)
            }
            validateLessonBlocks(lesson)
        }

        for rubric in snapshot.rubricVersions {
            validateCommon(
                locale: rubric.locale,
                publicationState: rubric.publicationState,
                schemaVersion: rubric.schemaVersion,
                minimumClientSchemaVersion: rubric.minimumClientSchemaVersion,
                timestamp: rubric.publishedAt,
                identifier: rubric.rubricVersionID.rawValue
            )
            validateDerivedID(
                rubric.rubricVersionID,
                stableID: rubric.rubricID,
                locale: rubric.locale,
                version: rubric.version
            )
            if rubric.kind != .deterministic ||
                rubric.clientScoringContract.kind != .singleAnswer ||
                rubric.evaluationContractVersionID.locale != rubric.locale {
                add(.scoringContractInvalid, rubric.rubricVersionID.rawValue)
            }
            if !(1...12).contains(rubric.criteria.count) {
                add(.invalidBound, rubric.rubricVersionID.rawValue)
            }
            if rubric.criteria.map(\.criterionID).hasDuplicates {
                add(.duplicateReference, rubric.rubricVersionID.rawValue)
            }
            for criterion in rubric.criteria {
                validateText(criterion.title, range: 1...120, identifier: rubric.rubricVersionID.rawValue)
                validateText(criterion.description, range: 1...1_000, identifier: rubric.rubricVersionID.rawValue)
                if !(1...100).contains(criterion.maxScore) {
                    add(.invalidBound, rubric.rubricVersionID.rawValue)
                }
            }
            validateText(
                rubric.clientScoringContract.correctFeedback,
                range: 1...1_000,
                identifier: rubric.rubricVersionID.rawValue
            )
            validateText(
                rubric.clientScoringContract.incorrectFeedback,
                range: 1...1_000,
                identifier: rubric.rubricVersionID.rawValue
            )
        }

        for asset in snapshot.assetVersions {
            validateCommon(
                locale: asset.locale,
                publicationState: asset.publicationState,
                schemaVersion: asset.schemaVersion,
                minimumClientSchemaVersion: asset.minimumClientSchemaVersion,
                timestamp: asset.publishedAt,
                identifier: asset.assetVersionID.rawValue
            )
            validateDerivedID(
                asset.assetVersionID,
                stableID: asset.assetID,
                locale: asset.locale,
                version: asset.version
            )
            if asset.kind != .diagramData || asset.mimeType != .diagramData {
                add(.assetReferenceInvalid, asset.assetVersionID.rawValue)
            }
            validateText(
                asset.accessibilityDescription,
                range: 1...1_000,
                identifier: asset.assetVersionID.rawValue
            )
            validateText(asset.rights.creator, range: 1...120, identifier: asset.assetVersionID.rawValue)
            if asset.payload.nodes.isEmpty || asset.payload.nodes.count > 12 ||
                asset.payload.connectors.count > 24 ||
                !(1...131_072).contains(asset.byteCount) {
                add(.invalidBound, asset.assetVersionID.rawValue)
            }
            if asset.payload.nodes.map(\.nodeID).hasDuplicates ||
                asset.payload.connectors.map(\.connectorID).hasDuplicates {
                add(.duplicateReference, asset.assetVersionID.rawValue)
            }
            validateDiagram(asset)
            validateRights(asset)
        }
    }

    private mutating func validateCommon(
        locale: CurriculumLocale,
        publicationState: CurriculumPublicationState,
        schemaVersion: Int,
        minimumClientSchemaVersion: Int,
        timestamp: CurriculumTimestamp,
        identifier: String
    ) {
        if locale != snapshot.locale || locale.rawValue != Self.launchLocale {
            add(.localeMismatch, identifier)
        }
        if publicationState != .published {
            add(.publicationStateInvalid, identifier)
        }
        if schemaVersion != Self.supportedSchemaVersion {
            add(.unsupportedSchema, identifier)
        }
        if minimumClientSchemaVersion > Self.supportedSchemaVersion {
            add(.minimumClientUnsupported, identifier)
        } else if minimumClientSchemaVersion < 1 {
            add(.invalidBound, identifier)
        }
        if !(-62_135_596_800...253_402_300_799).contains(timestamp.seconds) ||
            !(0...999_999_999).contains(Int(timestamp.nanoseconds)) {
            add(.invalidBound, identifier)
        }
    }

    private mutating func validateDerivedID(
        _ identifier: CurriculumVersionID,
        stableID: CurriculumStableID,
        locale: CurriculumLocale,
        version: CurriculumVersion
    ) {
        let derived = CurriculumVersionID(
            stableID: stableID,
            locale: locale,
            version: version
        )
        if identifier.rawValue != derived.rawValue {
            add(.identityMismatch, identifier.rawValue)
        }
    }

    private mutating func validateLessonBlocks(_ lesson: CurriculumLessonVersion) {
        let identifier = lesson.lessonVersionID.rawValue
        if lesson.blocks.map(\.blockID).hasDuplicates {
            add(.duplicateReference, identifier)
        }
        if lesson.blocks.enumerated().contains(where: { $0.element.order != $0.offset }) {
            add(.orderMismatch, identifier)
        }

        var conceptCount = 0
        var diagramBlocks: [StillDiagramBlockV1] = []
        var questions: [SingleAnswerQuestionBlockV1] = []
        for block in lesson.blocks {
            switch block {
            case let .conceptText(concept):
                conceptCount += 1
                if concept.type != .conceptText {
                    add(.malformedBlock, identifier)
                }
                if let heading = concept.heading {
                    validateText(heading, range: 1...120, identifier: identifier)
                }
                validateText(concept.body, range: 1...4_000, identifier: identifier)
            case let .stillDiagram(diagram):
                diagramBlocks.append(diagram)
                if diagram.type != .stillDiagram {
                    add(.malformedBlock, identifier)
                }
                validateText(diagram.title, range: 1...120, identifier: identifier)
            case let .singleAnswerQuestion(question):
                questions.append(question)
                if question.type != .singleAnswerQuestion {
                    add(.malformedBlock, identifier)
                }
                validateText(question.prompt, range: 1...1_000, identifier: identifier)
                if !(2...8).contains(question.options.count) {
                    add(.invalidBound, identifier)
                }
                if question.options.map(\.optionID).hasDuplicates {
                    add(.duplicateReference, identifier)
                }
                for option in question.options {
                    validateText(option.text, range: 1...300, identifier: identifier)
                }
            }
        }

        if conceptCount < 1 || diagramBlocks.isEmpty || questions.count != 1 {
            add(.malformedBlock, identifier)
        }

        let questionID = questions.first?.blockID
        let completion = lesson.completionRule
        if completion.requiredBlockIDs.isEmpty || completion.requiredBlockIDs.count > 20 {
            add(.invalidBound, identifier)
        }
        if completion.kind != .requiredBlocksCorrect ||
            completion.requiredBlockIDs.hasDuplicates ||
            completion.minimumCorrectCount != 1 ||
            completion.requiredBlockIDs.count != 1 ||
            completion.requiredBlockIDs.first != questionID {
            add(.completionRuleInvalid, identifier)
        }

        let diagramAssetIDs = Set(diagramBlocks.map(\.assetVersionID))
        if diagramAssetIDs != Set(lesson.assetVersionIDs) {
            add(.assetReferenceInvalid, identifier)
        }
    }

    private mutating func validateGraph() {
        let programsByID = map(snapshot.programVersions, key: \.programVersionID)
        let modulesByID = map(snapshot.moduleVersions, key: \.moduleVersionID)
        let lessonsByID = map(snapshot.lessonVersions, key: \.lessonVersionID)
        let rubricsByID = map(snapshot.rubricVersions, key: \.rubricVersionID)
        let assetsByID = map(snapshot.assetVersions, key: \.assetVersionID)

        var orderedPrograms: [CurriculumProgramVersion] = []
        for entry in snapshot.catalogVersion.programEntries {
            guard let program = programsByID[entry.programVersionID] else {
                add(.brokenReference, entry.programVersionID.rawValue)
                continue
            }
            orderedPrograms.append(program)
            let pointer = CurriculumProgramPointerID(
                stableID: program.programID,
                locale: program.locale
            )
            if entry.programPointerID.rawValue != pointer.rawValue {
                add(.identityMismatch, entry.programPointerID.rawValue)
            }
        }
        if orderedPrograms.map(\.programVersionID) != snapshot.programVersions.map(\.programVersionID) {
            add(.orderMismatch, "programVersions")
        }

        let availablePrograms = orderedPrograms.filter { $0.catalogState == .available }
        if availablePrograms.count != 1 ||
            availablePrograms.first?.programID.rawValue != Self.foundationsProgramID {
            add(.foundationsCatalogInvalid, snapshot.catalogVersion.catalogVersionID.rawValue)
        }

        var orderedModules: [CurriculumModuleVersion] = []
        var orderedLessons: [CurriculumLessonVersion] = []
        for program in orderedPrograms {
            if program.catalogState == .comingSoon {
                if !program.moduleVersionIDs.isEmpty || program.firstLessonVersionID != nil {
                    add(.firstLessonInvalid, program.programVersionID.rawValue)
                }
                continue
            }

            var programLessons: [CurriculumLessonVersion] = []
            for moduleID in program.moduleVersionIDs {
                guard let module = modulesByID[moduleID] else {
                    add(.brokenReference, moduleID.rawValue)
                    continue
                }
                orderedModules.append(module)
                if module.programID != program.programID {
                    add(.ownershipMismatch, module.moduleVersionID.rawValue)
                }
                for lessonID in module.lessonVersionIDs {
                    guard let lesson = lessonsByID[lessonID] else {
                        add(.brokenReference, lessonID.rawValue)
                        continue
                    }
                    orderedLessons.append(lesson)
                    programLessons.append(lesson)
                    if lesson.programID != program.programID ||
                        lesson.moduleID != module.moduleID {
                        add(.ownershipMismatch, lesson.lessonVersionID.rawValue)
                    }
                }
            }
            validateFirstLessonAndPrerequisites(program, lessons: programLessons)
        }

        if orderedModules.map(\.moduleVersionID) != snapshot.moduleVersions.map(\.moduleVersionID) {
            add(.orphanDocument, "moduleVersions")
        }
        if orderedLessons.map(\.lessonVersionID) != snapshot.lessonVersions.map(\.lessonVersionID) {
            add(.orphanDocument, "lessonVersions")
        }

        var orderedRubrics: [CurriculumVersionID] = []
        var orderedAssets: [CurriculumVersionID] = []
        for lesson in orderedLessons {
            guard let rubric = rubricsByID[lesson.rubricVersionID] else {
                add(.brokenReference, lesson.rubricVersionID.rawValue)
                continue
            }
            appendUnique(rubric.rubricVersionID, to: &orderedRubrics)
            validateScoring(rubric, lesson: lesson)

            for assetID in lesson.assetVersionIDs {
                guard let asset = assetsByID[assetID] else {
                    add(.assetReferenceInvalid, assetID.rawValue)
                    continue
                }
                appendUnique(asset.assetVersionID, to: &orderedAssets)
            }
        }

        if orderedRubrics != snapshot.rubricVersions.map(\.rubricVersionID) {
            add(.orphanDocument, "rubricVersions")
        }
        if orderedAssets != snapshot.assetVersions.map(\.assetVersionID) {
            add(.orphanDocument, "assetVersions")
        }
    }

    private mutating func validateFirstLessonAndPrerequisites(
        _ program: CurriculumProgramVersion,
        lessons: [CurriculumLessonVersion]
    ) {
        guard let first = lessons.first else {
            add(.firstLessonInvalid, program.programVersionID.rawValue)
            return
        }
        if program.firstLessonVersionID != first.lessonVersionID ||
            !first.prerequisiteLessonIDs.isEmpty {
            add(.firstLessonInvalid, program.programVersionID.rawValue)
        }

        var stableOrder: [CurriculumStableID: Int] = [:]
        for (index, lesson) in lessons.enumerated()
        where stableOrder[lesson.lessonID] == nil {
            stableOrder[lesson.lessonID] = index
        }
        var graph: [CurriculumStableID: [CurriculumStableID]] = [:]
        for (index, lesson) in lessons.enumerated() {
            graph[lesson.lessonID] = lesson.prerequisiteLessonIDs
            for prerequisite in lesson.prerequisiteLessonIDs {
                guard let prerequisiteIndex = stableOrder[prerequisite] else {
                    add(.brokenReference, prerequisite.rawValue)
                    add(.prerequisiteViolation, lesson.lessonVersionID.rawValue)
                    continue
                }
                guard prerequisiteIndex < index else {
                    add(.prerequisiteViolation, lesson.lessonVersionID.rawValue)
                    continue
                }
            }
        }

        var visiting = Set<CurriculumStableID>()
        var visited = Set<CurriculumStableID>()
        func hasCycle(_ lessonID: CurriculumStableID) -> Bool {
            if visiting.contains(lessonID) { return true }
            if visited.contains(lessonID) { return false }
            visiting.insert(lessonID)
            for prerequisite in graph[lessonID, default: []]
            where graph[prerequisite] != nil {
                if hasCycle(prerequisite) { return true }
            }
            visiting.remove(lessonID)
            visited.insert(lessonID)
            return false
        }
        if graph.keys.contains(where: hasCycle) {
            add(.prerequisiteViolation, program.programVersionID.rawValue)
        }
    }

    private mutating func validateScoring(
        _ rubric: CurriculumRubricVersion,
        lesson: CurriculumLessonVersion
    ) {
        let questions = lesson.blocks.compactMap { block -> SingleAnswerQuestionBlockV1? in
            guard case let .singleAnswerQuestion(question) = block else { return nil }
            return question
        }
        guard questions.count == 1, let question = questions.first else {
            add(.scoringContractInvalid, rubric.rubricVersionID.rawValue)
            return
        }
        let scoring = rubric.clientScoringContract
        if scoring.questionBlockID != question.blockID ||
            !question.options.map(\.optionID).contains(scoring.correctOptionID) {
            add(.scoringContractInvalid, rubric.rubricVersionID.rawValue)
        }
    }

    private mutating func validateDiagram(_ asset: CurriculumAssetVersion) {
        let identifier = asset.assetVersionID.rawValue
        let nodeIDs = Set(asset.payload.nodes.map(\.nodeID))
        for node in asset.payload.nodes {
            validateText(node.label, range: 1...120, identifier: identifier)
        }
        for connector in asset.payload.connectors {
            if !nodeIDs.contains(connector.fromNodeID) ||
                !nodeIDs.contains(connector.toNodeID) ||
                connector.fromNodeID == connector.toNodeID {
                add(.assetReferenceInvalid, identifier)
            }
            if let label = connector.label {
                validateText(label, range: 1...120, identifier: identifier)
            }
        }
        if asset.accessibilityDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            add(.assetReferenceInvalid, identifier)
        }
    }

    private mutating func validateRights(_ asset: CurriculumAssetVersion) {
        let rights = asset.rights
        if rights.origin == .licensed {
            guard let sourceURL = rights.sourceURL,
                  let license = rights.license,
                  isValidHTTPSURL(sourceURL),
                  isValidText(license, range: 1...120) else {
                add(.rightsInvalid, asset.assetVersionID.rawValue)
                return
            }
        }
        if let sourceURL = rights.sourceURL,
           !isValidHTTPSURL(sourceURL) {
            add(.rightsInvalid, asset.assetVersionID.rawValue)
        }
        if let sourceURL = rights.sourceURL,
           !hasValidCanonicalText(sourceURL) {
            add(.invalidText, asset.assetVersionID.rawValue)
        }
        if let license = rights.license {
            validateText(license, range: 1...120, identifier: asset.assetVersionID.rawValue)
        }
    }

    private mutating func validateDigestsAndSizes() {
        var totalDocumentBytes = validateDigest(
            snapshot.catalogVersion,
            expected: snapshot.catalogVersion.contentDigest,
            identifier: snapshot.catalogVersion.catalogVersionID.rawValue
        )
        for program in snapshot.programVersions {
            totalDocumentBytes += validateDigest(program, expected: program.contentDigest, identifier: program.programVersionID.rawValue)
        }
        for module in snapshot.moduleVersions {
            totalDocumentBytes += validateDigest(module, expected: module.contentDigest, identifier: module.moduleVersionID.rawValue)
        }
        for lesson in snapshot.lessonVersions {
            totalDocumentBytes += validateDigest(lesson, expected: lesson.contentDigest, identifier: lesson.lessonVersionID.rawValue)
        }
        for rubric in snapshot.rubricVersions {
            totalDocumentBytes += validateDigest(rubric, expected: rubric.contentDigest, identifier: rubric.rubricVersionID.rawValue)
        }
        for asset in snapshot.assetVersions {
            do {
                let payloadBytes = try CurriculumCanonicalJSON.canonicalBytes(asset.payload)
                let computedPayloadDigest = try CurriculumCanonicalJSON.payloadDigest(
                    asset.payload
                )
                if payloadBytes.count > 131_072 {
                    add(.documentSizeExceeded, asset.assetVersionID.rawValue)
                }
                if payloadBytes.count != asset.byteCount ||
                    computedPayloadDigest != asset.payloadDigest {
                    add(.payloadDigestMismatch, asset.assetVersionID.rawValue)
                }
            } catch {
                add(.payloadDigestMismatch, asset.assetVersionID.rawValue)
            }
            totalDocumentBytes += validateDigest(asset, expected: asset.contentDigest, identifier: asset.assetVersionID.rawValue)
        }
        if totalDocumentBytes > 8 * 1_024 * 1_024 {
            add(.documentSizeExceeded, "snapshot")
        }
    }

    private mutating func validateDigest<Value: Encodable>(
        _ value: Value,
        expected: CurriculumDigest,
        identifier: String
    ) -> Int {
        do {
            if try CurriculumCanonicalJSON.contentDigest(value) != expected {
                add(.digestMismatch, identifier)
            }
            let documentBytes = try CurriculumCanonicalJSON.contentDocumentBytes(value)
            if documentBytes.count > 262_144 {
                add(.documentSizeExceeded, identifier)
            }
            return documentBytes.count
        } catch {
            add(.digestMismatch, identifier)
            return 0
        }
    }

    private mutating func validateText(
        _ value: String,
        range: ClosedRange<Int>,
        identifier: String
    ) {
        if !hasValidCanonicalText(value) {
            add(.invalidText, identifier)
        }
        if !range.contains(value.unicodeScalars.count) {
            add(.invalidBound, identifier)
        }
    }

    private func isValidText(
        _ value: String,
        range: ClosedRange<Int>
    ) -> Bool {
        hasValidCanonicalText(value) && range.contains(value.unicodeScalars.count)
    }

    private func hasValidCanonicalText(_ value: String) -> Bool {
        let normalized = value.precomposedStringWithCanonicalMapping
        guard value.utf8.elementsEqual(normalized.utf8) else { return false }
        return !value.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F, 0x7F:
                true
            default:
                false
            }
        }
    }

    private func isValidHTTPSURL(_ value: String) -> Bool {
        guard (1...2_048).contains(value.unicodeScalars.count),
              !value.contains(where: { $0.isWhitespace }),
              value.hasPrefix("https://"),
              value.utf8.dropFirst("https://".utf8.count).isEmpty == false,
              value.unicodeScalars.allSatisfy(\.isASCII),
              URL(string: value, encodingInvalidCharacters: false) != nil else {
            return false
        }
        return true
    }

    private func map<Value, Key: Hashable>(
        _ values: [Value],
        key: KeyPath<Value, Key>
    ) -> [Key: Value] {
        var result: [Key: Value] = [:]
        for value in values where result[value[keyPath: key]] == nil {
            result[value[keyPath: key]] = value
        }
        return result
    }

    private func appendUnique<Value: Equatable>(_ value: Value, to values: inout [Value]) {
        if !values.contains(value) {
            values.append(value)
        }
    }
}

private extension Array where Element: Hashable {
    var hasDuplicates: Bool {
        var seen = Set<Element>()
        return contains { !seen.insert($0).inserted }
    }
}
