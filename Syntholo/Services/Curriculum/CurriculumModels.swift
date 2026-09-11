import Foundation

enum CurriculumPublicationState: String, Codable, Hashable, Sendable {
    case draft
    case published
}

enum CurriculumCatalogState: String, Codable, Hashable, Sendable {
    case available
    case comingSoon
}

enum CurriculumCompletionRuleKind: String, Codable, Hashable, Sendable {
    case requiredBlocksCorrect
}

enum CurriculumContentBlockType: String, Codable, Hashable, Sendable {
    case conceptText
    case stillDiagram
    case singleAnswerQuestion
}

enum CurriculumRubricKind: String, Codable, Hashable, Sendable {
    case deterministic
}

enum CurriculumClientScoringKind: String, Codable, Hashable, Sendable {
    case singleAnswer
}

enum CurriculumDiagramEmphasis: String, Codable, Hashable, Sendable {
    case normal
    case accent
}

enum CurriculumRightsOrigin: String, Codable, Hashable, Sendable {
    case original
    case licensed
}

enum CurriculumAssetKind: String, Codable, Hashable, Sendable {
    case diagramData
}

enum CurriculumAssetMIMEType: String, Codable, Hashable, Sendable {
    case diagramData = "application/vnd.syntholo.diagram+json"
}

struct CurriculumTimestamp: Codable, Equatable, Hashable, Sendable {
    let seconds: Int64
    let nanoseconds: Int32

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case seconds
        case nanoseconds
    }
}

struct CurriculumSnapshot: Codable, Equatable, Hashable, Sendable {
    let locale: CurriculumLocale
    let catalogPointerID: CurriculumLocaleToken
    let catalogVersion: CurriculumCatalogVersion
    let programVersions: [CurriculumProgramVersion]
    let moduleVersions: [CurriculumModuleVersion]
    let lessonVersions: [CurriculumLessonVersion]
    let rubricVersions: [CurriculumRubricVersion]
    let assetVersions: [CurriculumAssetVersion]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case locale
        case catalogPointerID
        case catalogVersion
        case programVersions
        case moduleVersions
        case lessonVersions
        case rubricVersions
        case assetVersions
    }
}

struct CatalogProgramEntryV1: Codable, Equatable, Hashable, Sendable {
    let programPointerID: CurriculumProgramPointerID
    let programVersionID: CurriculumVersionID

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case programPointerID
        case programVersionID
    }
}

struct CurriculumCatalogVersion: Codable, Equatable, Hashable, Sendable {
    let catalogVersionID: CurriculumCatalogVersionID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let programEntries: [CatalogProgramEntryV1]
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case catalogVersionID
        case version
        case locale
        case publicationState
        case schemaVersion
        case minimumClientSchemaVersion
        case programEntries
        case contentDigest
        case publishedAt
    }
}

struct CurriculumProgramVersion: Codable, Equatable, Hashable, Sendable {
    let programVersionID: CurriculumVersionID
    let programID: CurriculumStableID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let title: String
    let promise: String
    let catalogState: CurriculumCatalogState
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let moduleVersionIDs: [CurriculumVersionID]
    let firstLessonVersionID: CurriculumVersionID?
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case programVersionID
        case programID
        case version
        case locale
        case publicationState
        case title
        case promise
        case catalogState
        case schemaVersion
        case minimumClientSchemaVersion
        case moduleVersionIDs
        case firstLessonVersionID
        case contentDigest
        case publishedAt
    }
}

struct CurriculumModuleVersion: Codable, Equatable, Hashable, Sendable {
    let moduleVersionID: CurriculumVersionID
    let moduleID: CurriculumStableID
    let programID: CurriculumStableID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let title: String
    let summary: String
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let lessonVersionIDs: [CurriculumVersionID]
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case moduleVersionID
        case moduleID
        case programID
        case version
        case locale
        case publicationState
        case title
        case summary
        case schemaVersion
        case minimumClientSchemaVersion
        case lessonVersionIDs
        case contentDigest
        case publishedAt
    }
}

struct CompletionRuleV1: Codable, Equatable, Hashable, Sendable {
    let kind: CurriculumCompletionRuleKind
    let requiredBlockIDs: [CurriculumStableID]
    let minimumCorrectCount: Int
    let allowsRevision: Bool

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case requiredBlockIDs
        case minimumCorrectCount
        case allowsRevision
    }
}

enum ContentBlockV1: Codable, Equatable, Hashable, Sendable {
    case conceptText(ConceptTextBlockV1)
    case stillDiagram(StillDiagramBlockV1)
    case singleAnswerQuestion(SingleAnswerQuestionBlockV1)

    var type: CurriculumContentBlockType {
        switch self {
        case .conceptText:
            .conceptText
        case .stillDiagram:
            .stillDiagram
        case .singleAnswerQuestion:
            .singleAnswerQuestion
        }
    }

    var blockID: CurriculumStableID {
        switch self {
        case let .conceptText(block):
            block.blockID
        case let .stillDiagram(block):
            block.blockID
        case let .singleAnswerQuestion(block):
            block.blockID
        }
    }

    var order: Int {
        switch self {
        case let .conceptText(block):
            block.order
        case let .stillDiagram(block):
            block.order
        case let .singleAnswerQuestion(block):
            block.order
        }
    }

    private enum DiscriminatorCodingKeys: String, CodingKey {
        case type
    }
}

struct ConceptTextBlockV1: Codable, Equatable, Hashable, Sendable {
    let blockID: CurriculumStableID
    let type: CurriculumContentBlockType
    let order: Int
    let heading: String?
    let body: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case blockID
        case type
        case order
        case heading
        case body
    }
}

struct StillDiagramBlockV1: Codable, Equatable, Hashable, Sendable {
    let blockID: CurriculumStableID
    let type: CurriculumContentBlockType
    let order: Int
    let title: String
    let assetVersionID: CurriculumVersionID

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case blockID
        case type
        case order
        case title
        case assetVersionID
    }
}

struct SingleAnswerQuestionBlockV1: Codable, Equatable, Hashable, Sendable {
    let blockID: CurriculumStableID
    let type: CurriculumContentBlockType
    let order: Int
    let prompt: String
    let options: [QuestionOptionV1]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case blockID
        case type
        case order
        case prompt
        case options
    }
}

struct QuestionOptionV1: Codable, Equatable, Hashable, Sendable {
    let optionID: CurriculumStableID
    let text: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case optionID
        case text
    }
}

struct CurriculumLessonVersion: Codable, Equatable, Hashable, Sendable {
    let lessonVersionID: CurriculumVersionID
    let lessonID: CurriculumStableID
    let programID: CurriculumStableID
    let moduleID: CurriculumStableID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let title: String
    let objective: String
    let expectedDurationMinutes: Int
    let prerequisiteLessonIDs: [CurriculumStableID]
    let completionRule: CompletionRuleV1
    let blocks: [ContentBlockV1]
    let rubricVersionID: CurriculumVersionID
    let assetVersionIDs: [CurriculumVersionID]
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case lessonVersionID
        case lessonID
        case programID
        case moduleID
        case version
        case locale
        case publicationState
        case title
        case objective
        case expectedDurationMinutes
        case prerequisiteLessonIDs
        case completionRule
        case blocks
        case rubricVersionID
        case assetVersionIDs
        case schemaVersion
        case minimumClientSchemaVersion
        case contentDigest
        case publishedAt
    }
}

struct CriterionV1: Codable, Equatable, Hashable, Sendable {
    let criterionID: CurriculumStableID
    let title: String
    let description: String
    let maxScore: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case criterionID
        case title
        case description
        case maxScore
    }
}

struct ClientScoringContractV1: Codable, Equatable, Hashable, Sendable {
    let kind: CurriculumClientScoringKind
    let questionBlockID: CurriculumStableID
    let correctOptionID: CurriculumStableID
    let correctFeedback: String
    let incorrectFeedback: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case questionBlockID
        case correctOptionID
        case correctFeedback
        case incorrectFeedback
    }
}

struct CurriculumRubricVersion: Codable, Equatable, Hashable, Sendable {
    let rubricVersionID: CurriculumVersionID
    let rubricID: CurriculumStableID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let kind: CurriculumRubricKind
    let criteria: [CriterionV1]
    let clientScoringContract: ClientScoringContractV1
    let evaluationContractVersionID: CurriculumVersionID
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case rubricVersionID
        case rubricID
        case version
        case locale
        case publicationState
        case kind
        case criteria
        case clientScoringContract
        case evaluationContractVersionID
        case schemaVersion
        case minimumClientSchemaVersion
        case contentDigest
        case publishedAt
    }
}

struct DiagramNodeV1: Codable, Equatable, Hashable, Sendable {
    let nodeID: CurriculumStableID
    let label: String
    let emphasis: CurriculumDiagramEmphasis

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case nodeID
        case label
        case emphasis
    }
}

struct DiagramConnectorV1: Codable, Equatable, Hashable, Sendable {
    let connectorID: CurriculumStableID
    let fromNodeID: CurriculumStableID
    let toNodeID: CurriculumStableID
    let label: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case connectorID
        case fromNodeID
        case toNodeID
        case label
    }
}

struct DiagramAssetPayloadV1: Codable, Equatable, Hashable, Sendable {
    let nodes: [DiagramNodeV1]
    let connectors: [DiagramConnectorV1]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case nodes
        case connectors
    }
}

struct RightsMetadataV1: Codable, Equatable, Hashable, Sendable {
    let origin: CurriculumRightsOrigin
    let creator: String
    let sourceURL: String?
    let license: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case origin
        case creator
        case sourceURL
        case license
    }
}

struct CurriculumAssetVersion: Codable, Equatable, Hashable, Sendable {
    let assetVersionID: CurriculumVersionID
    let assetID: CurriculumStableID
    let version: CurriculumVersion
    let locale: CurriculumLocale
    let publicationState: CurriculumPublicationState
    let kind: CurriculumAssetKind
    let mimeType: CurriculumAssetMIMEType
    let payload: DiagramAssetPayloadV1
    let accessibilityDescription: String
    let rights: RightsMetadataV1
    let schemaVersion: Int
    let minimumClientSchemaVersion: Int
    let byteCount: Int
    let payloadDigest: CurriculumDigest
    let contentDigest: CurriculumDigest
    let publishedAt: CurriculumTimestamp

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case assetVersionID
        case assetID
        case version
        case locale
        case publicationState
        case kind
        case mimeType
        case payload
        case accessibilityDescription
        case rights
        case schemaVersion
        case minimumClientSchemaVersion
        case byteCount
        case payloadDigest
        case contentDigest
        case publishedAt
    }
}

enum CurriculumJSONCodecError: Error, Equatable, Sendable {
    case inputTooLarge(maximumBytes: Int)
    case invalidSyntax(offset: Int)
    case nonIntegerNumber(offset: Int)
    case duplicateObjectKey
    case excessiveNesting
    case excessiveContainerItems(maximum: Int)
}

enum CurriculumJSONCodec {
    private static let maximumSnapshotBytes = 9 * 1_024 * 1_024

    static func decodeSnapshot(from data: Data) throws -> CurriculumSnapshot {
        guard data.count <= maximumSnapshotBytes else {
            throw CurriculumJSONCodecError.inputTooLarge(
                maximumBytes: maximumSnapshotBytes
            )
        }
        var preflight = StrictCurriculumJSONPreflight(data: data)
        try preflight.validate()

        let decoder = JSONDecoder()
        return try decoder.decode(CurriculumSnapshot.self, from: data)
    }

    static func encodeSnapshot(_ snapshot: CurriculumSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(snapshot)
    }
}

extension CurriculumTimestamp {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        seconds = try container.decode(Int64.self, forKey: .seconds)
        nanoseconds = try container.decode(Int32.self, forKey: .nanoseconds)
    }
}

extension CurriculumSnapshot {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        catalogPointerID = try container.decode(
            CurriculumLocaleToken.self,
            forKey: .catalogPointerID
        )
        catalogVersion = try container.decode(
            CurriculumCatalogVersion.self,
            forKey: .catalogVersion
        )
        programVersions = try container.decode(
            [CurriculumProgramVersion].self,
            forKey: .programVersions
        )
        moduleVersions = try container.decode(
            [CurriculumModuleVersion].self,
            forKey: .moduleVersions
        )
        lessonVersions = try container.decode(
            [CurriculumLessonVersion].self,
            forKey: .lessonVersions
        )
        rubricVersions = try container.decode(
            [CurriculumRubricVersion].self,
            forKey: .rubricVersions
        )
        assetVersions = try container.decode(
            [CurriculumAssetVersion].self,
            forKey: .assetVersions
        )
    }
}

extension CatalogProgramEntryV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        programPointerID = try container.decode(
            CurriculumProgramPointerID.self,
            forKey: .programPointerID
        )
        programVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .programVersionID
        )
    }
}

extension CurriculumCatalogVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        catalogVersionID = try container.decode(
            CurriculumCatalogVersionID.self,
            forKey: .catalogVersionID
        )
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        programEntries = try container.decode(
            [CatalogProgramEntryV1].self,
            forKey: .programEntries
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }
}

extension CurriculumProgramVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        programVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .programVersionID
        )
        programID = try container.decode(
            CurriculumStableID.self,
            forKey: .programID
        )
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        title = try container.decode(String.self, forKey: .title)
        promise = try container.decode(String.self, forKey: .promise)
        catalogState = try container.decode(
            CurriculumCatalogState.self,
            forKey: .catalogState
        )
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        moduleVersionIDs = try container.decode(
            [CurriculumVersionID].self,
            forKey: .moduleVersionIDs
        )
        firstLessonVersionID = try container.decodeRequiredNullable(
            CurriculumVersionID.self,
            forKey: .firstLessonVersionID
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(programVersionID, forKey: .programVersionID)
        try container.encode(programID, forKey: .programID)
        try container.encode(version, forKey: .version)
        try container.encode(locale, forKey: .locale)
        try container.encode(publicationState, forKey: .publicationState)
        try container.encode(title, forKey: .title)
        try container.encode(promise, forKey: .promise)
        try container.encode(catalogState, forKey: .catalogState)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(
            minimumClientSchemaVersion,
            forKey: .minimumClientSchemaVersion
        )
        try container.encode(moduleVersionIDs, forKey: .moduleVersionIDs)
        if let firstLessonVersionID {
            try container.encode(
                firstLessonVersionID,
                forKey: .firstLessonVersionID
            )
        } else {
            try container.encodeNil(forKey: .firstLessonVersionID)
        }
        try container.encode(contentDigest, forKey: .contentDigest)
        try container.encode(publishedAt, forKey: .publishedAt)
    }
}

extension CurriculumModuleVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        moduleVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .moduleVersionID
        )
        moduleID = try container.decode(CurriculumStableID.self, forKey: .moduleID)
        programID = try container.decode(CurriculumStableID.self, forKey: .programID)
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        lessonVersionIDs = try container.decode(
            [CurriculumVersionID].self,
            forKey: .lessonVersionIDs
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }
}

extension CompletionRuleV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        kind = try container.decode(
            CurriculumCompletionRuleKind.self,
            forKey: .kind
        )
        requiredBlockIDs = try container.decode(
            [CurriculumStableID].self,
            forKey: .requiredBlockIDs
        )
        minimumCorrectCount = try container.decode(
            Int.self,
            forKey: .minimumCorrectCount
        )
        allowsRevision = try container.decode(Bool.self, forKey: .allowsRevision)
    }
}

extension ContentBlockV1 {
    init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(
            keyedBy: DiscriminatorCodingKeys.self
        )
        switch try discriminator.decode(
            CurriculumContentBlockType.self,
            forKey: .type
        ) {
        case .conceptText:
            self = .conceptText(try ConceptTextBlockV1(from: decoder))
        case .stillDiagram:
            self = .stillDiagram(try StillDiagramBlockV1(from: decoder))
        case .singleAnswerQuestion:
            self = .singleAnswerQuestion(
                try SingleAnswerQuestionBlockV1(from: decoder)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .conceptText(block):
            try block.encode(to: encoder)
        case let .stillDiagram(block):
            try block.encode(to: encoder)
        case let .singleAnswerQuestion(block):
            try block.encode(to: encoder)
        }
    }
}

extension ConceptTextBlockV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        blockID = try container.decode(CurriculumStableID.self, forKey: .blockID)
        type = try container.decode(CurriculumContentBlockType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        heading = try container.decodeOptionalNonNull(
            String.self,
            forKey: .heading
        )
        body = try container.decode(String.self, forKey: .body)
    }
}

extension StillDiagramBlockV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        blockID = try container.decode(CurriculumStableID.self, forKey: .blockID)
        type = try container.decode(CurriculumContentBlockType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        title = try container.decode(String.self, forKey: .title)
        assetVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .assetVersionID
        )
    }
}

extension SingleAnswerQuestionBlockV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        blockID = try container.decode(CurriculumStableID.self, forKey: .blockID)
        type = try container.decode(CurriculumContentBlockType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        prompt = try container.decode(String.self, forKey: .prompt)
        options = try container.decode([QuestionOptionV1].self, forKey: .options)
    }
}

extension QuestionOptionV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        optionID = try container.decode(CurriculumStableID.self, forKey: .optionID)
        text = try container.decode(String.self, forKey: .text)
    }
}

extension CurriculumLessonVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        lessonVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .lessonVersionID
        )
        lessonID = try container.decode(CurriculumStableID.self, forKey: .lessonID)
        programID = try container.decode(CurriculumStableID.self, forKey: .programID)
        moduleID = try container.decode(CurriculumStableID.self, forKey: .moduleID)
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        title = try container.decode(String.self, forKey: .title)
        objective = try container.decode(String.self, forKey: .objective)
        expectedDurationMinutes = try container.decode(
            Int.self,
            forKey: .expectedDurationMinutes
        )
        prerequisiteLessonIDs = try container.decode(
            [CurriculumStableID].self,
            forKey: .prerequisiteLessonIDs
        )
        completionRule = try container.decode(
            CompletionRuleV1.self,
            forKey: .completionRule
        )
        blocks = try container.decode([ContentBlockV1].self, forKey: .blocks)
        rubricVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .rubricVersionID
        )
        assetVersionIDs = try container.decode(
            [CurriculumVersionID].self,
            forKey: .assetVersionIDs
        )
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }
}

extension CriterionV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        criterionID = try container.decode(
            CurriculumStableID.self,
            forKey: .criterionID
        )
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        maxScore = try container.decode(Int.self, forKey: .maxScore)
    }
}

extension ClientScoringContractV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        kind = try container.decode(CurriculumClientScoringKind.self, forKey: .kind)
        questionBlockID = try container.decode(
            CurriculumStableID.self,
            forKey: .questionBlockID
        )
        correctOptionID = try container.decode(
            CurriculumStableID.self,
            forKey: .correctOptionID
        )
        correctFeedback = try container.decode(
            String.self,
            forKey: .correctFeedback
        )
        incorrectFeedback = try container.decode(
            String.self,
            forKey: .incorrectFeedback
        )
    }
}

extension CurriculumRubricVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        rubricVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .rubricVersionID
        )
        rubricID = try container.decode(CurriculumStableID.self, forKey: .rubricID)
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        kind = try container.decode(CurriculumRubricKind.self, forKey: .kind)
        criteria = try container.decode([CriterionV1].self, forKey: .criteria)
        clientScoringContract = try container.decode(
            ClientScoringContractV1.self,
            forKey: .clientScoringContract
        )
        evaluationContractVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .evaluationContractVersionID
        )
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }
}

extension DiagramNodeV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        nodeID = try container.decode(CurriculumStableID.self, forKey: .nodeID)
        label = try container.decode(String.self, forKey: .label)
        emphasis = try container.decode(
            CurriculumDiagramEmphasis.self,
            forKey: .emphasis
        )
    }
}

extension DiagramConnectorV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        connectorID = try container.decode(
            CurriculumStableID.self,
            forKey: .connectorID
        )
        fromNodeID = try container.decode(
            CurriculumStableID.self,
            forKey: .fromNodeID
        )
        toNodeID = try container.decode(
            CurriculumStableID.self,
            forKey: .toNodeID
        )
        label = try container.decodeRequiredNullable(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(connectorID, forKey: .connectorID)
        try container.encode(fromNodeID, forKey: .fromNodeID)
        try container.encode(toNodeID, forKey: .toNodeID)
        if let label {
            try container.encode(label, forKey: .label)
        } else {
            try container.encodeNil(forKey: .label)
        }
    }
}

extension DiagramAssetPayloadV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        nodes = try container.decode([DiagramNodeV1].self, forKey: .nodes)
        connectors = try container.decode(
            [DiagramConnectorV1].self,
            forKey: .connectors
        )
    }
}

extension RightsMetadataV1 {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        origin = try container.decode(CurriculumRightsOrigin.self, forKey: .origin)
        creator = try container.decode(String.self, forKey: .creator)
        sourceURL = try container.decodeRequiredNullable(
            String.self,
            forKey: .sourceURL
        )
        license = try container.decodeRequiredNullable(
            String.self,
            forKey: .license
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin, forKey: .origin)
        try container.encode(creator, forKey: .creator)
        if let sourceURL {
            try container.encode(sourceURL, forKey: .sourceURL)
        } else {
            try container.encodeNil(forKey: .sourceURL)
        }
        if let license {
            try container.encode(license, forKey: .license)
        } else {
            try container.encodeNil(forKey: .license)
        }
    }
}

extension CurriculumAssetVersion {
    init(from decoder: Decoder) throws {
        let container = try exactContainer(CodingKeys.self, from: decoder)
        assetVersionID = try container.decode(
            CurriculumVersionID.self,
            forKey: .assetVersionID
        )
        assetID = try container.decode(CurriculumStableID.self, forKey: .assetID)
        version = try container.decode(CurriculumVersion.self, forKey: .version)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        publicationState = try container.decode(
            CurriculumPublicationState.self,
            forKey: .publicationState
        )
        kind = try container.decode(CurriculumAssetKind.self, forKey: .kind)
        mimeType = try container.decode(
            CurriculumAssetMIMEType.self,
            forKey: .mimeType
        )
        payload = try container.decode(DiagramAssetPayloadV1.self, forKey: .payload)
        accessibilityDescription = try container.decode(
            String.self,
            forKey: .accessibilityDescription
        )
        rights = try container.decode(RightsMetadataV1.self, forKey: .rights)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        minimumClientSchemaVersion = try container.decode(
            Int.self,
            forKey: .minimumClientSchemaVersion
        )
        byteCount = try container.decode(Int.self, forKey: .byteCount)
        payloadDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .payloadDigest
        )
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
        publishedAt = try container.decode(
            CurriculumTimestamp.self,
            forKey: .publishedAt
        )
    }
}

private struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private func exactContainer<Key: CodingKey & CaseIterable>(
    _ keyType: Key.Type,
    from decoder: Decoder
) throws -> KeyedDecodingContainer<Key> {
    let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
    let allowed = Set(keyType.allCases.map(\.stringValue))

    if let unknown = dynamic.allKeys.first(where: {
        !allowed.contains($0.stringValue)
    }) {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath + [unknown],
                debugDescription: "Unknown curriculum field."
            )
        )
    }

    return try decoder.container(keyedBy: keyType)
}

private extension KeyedDecodingContainer {
    func decodeRequiredNullable<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> Value? {
        guard contains(key) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Required nullable field is missing."
                )
            )
        }

        if try decodeNil(forKey: key) {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decodeOptionalNonNull<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> Value? {
        guard contains(key) else {
            return nil
        }
        guard try !decodeNil(forKey: key) else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: codingPath + [key],
                    debugDescription: "Optional curriculum field cannot be null."
                )
            )
        }
        return try decode(type, forKey: key)
    }
}

struct StrictCurriculumJSONPreflight {
    private static let maximumObjectMembers = 32
    private static let maximumArrayItems = 180

    private let bytes: [UInt8]
    private var offset = 0

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func validate() throws {
        skipWhitespace()
        try parseValue(depth: 0)
        skipWhitespace()
        guard offset == bytes.count else {
            throw invalidSyntax()
        }
    }

    private mutating func parseValue(depth: Int) throws {
        guard depth <= 128 else {
            throw CurriculumJSONCodecError.excessiveNesting
        }
        guard let byte = currentByte else {
            throw invalidSyntax()
        }

        switch byte {
        case CharacterByte.leftBrace:
            try parseObject(depth: depth + 1)
        case CharacterByte.leftBracket:
            try parseArray(depth: depth + 1)
        case CharacterByte.quote:
            _ = try parseString(decoding: false)
        case CharacterByte.minus, CharacterByte.zero ... CharacterByte.nine:
            try parseInteger()
        case CharacterByte.t:
            try consumeLiteral("true")
        case CharacterByte.f:
            try consumeLiteral("false")
        case CharacterByte.n:
            try consumeLiteral("null")
        default:
            throw invalidSyntax()
        }
    }

    private mutating func parseObject(depth: Int) throws {
        try consume(CharacterByte.leftBrace)
        skipWhitespace()
        if consumeIfPresent(CharacterByte.rightBrace) {
            return
        }

        var keys = Set<String>()
        var memberCount = 0
        while true {
            guard memberCount < Self.maximumObjectMembers else {
                throw CurriculumJSONCodecError.excessiveContainerItems(
                    maximum: Self.maximumObjectMembers
                )
            }
            memberCount += 1
            guard currentByte == CharacterByte.quote else {
                throw invalidSyntax()
            }
            let key = try parseString()
            guard keys.insert(key).inserted else {
                throw CurriculumJSONCodecError.duplicateObjectKey
            }

            skipWhitespace()
            try consume(CharacterByte.colon)
            skipWhitespace()
            try parseValue(depth: depth)
            skipWhitespace()

            if consumeIfPresent(CharacterByte.rightBrace) {
                return
            }
            try consume(CharacterByte.comma)
            skipWhitespace()
        }
    }

    private mutating func parseArray(depth: Int) throws {
        try consume(CharacterByte.leftBracket)
        skipWhitespace()
        if consumeIfPresent(CharacterByte.rightBracket) {
            return
        }

        var itemCount = 0
        while true {
            guard itemCount < Self.maximumArrayItems else {
                throw CurriculumJSONCodecError.excessiveContainerItems(
                    maximum: Self.maximumArrayItems
                )
            }
            itemCount += 1
            try parseValue(depth: depth)
            skipWhitespace()
            if consumeIfPresent(CharacterByte.rightBracket) {
                return
            }
            try consume(CharacterByte.comma)
            skipWhitespace()
        }
    }

    private mutating func parseString(decoding: Bool = true) throws -> String {
        let start = offset
        try consume(CharacterByte.quote)

        var escaped = false
        while let byte = currentByte {
            if escaped {
                switch byte {
                case CharacterByte.quote,
                     CharacterByte.backslash,
                     CharacterByte.slash,
                     CharacterByte.b,
                     CharacterByte.f,
                     CharacterByte.n,
                     CharacterByte.r,
                     CharacterByte.t:
                    offset += 1
                case CharacterByte.u:
                    offset += 1
                    guard offset + 4 <= bytes.count,
                          bytes[offset ..< offset + 4].allSatisfy(isHexDigit) else {
                        throw invalidSyntax()
                    }
                    offset += 4
                default:
                    throw invalidSyntax()
                }
                escaped = false
                continue
            }

            if byte == CharacterByte.backslash {
                offset += 1
                escaped = true
                continue
            }
            if byte == CharacterByte.quote {
                offset += 1
                guard decoding else { return "" }
                let token = Data(bytes[start ..< offset])
                do {
                    return try JSONDecoder().decode(String.self, from: token)
                } catch {
                    throw invalidSyntax(at: start)
                }
            }
            guard byte >= CharacterByte.space else {
                throw invalidSyntax()
            }
            offset += 1
        }

        throw invalidSyntax(at: start)
    }

    private mutating func parseInteger() throws {
        let start = offset
        _ = consumeIfPresent(CharacterByte.minus)

        guard let firstDigit = currentByte else {
            throw invalidSyntax(at: start)
        }
        if firstDigit == CharacterByte.zero {
            offset += 1
            if let byte = currentByte,
               CharacterByte.zero ... CharacterByte.nine ~= byte {
                throw invalidSyntax(at: start)
            }
        } else if CharacterByte.one ... CharacterByte.nine ~= firstDigit {
            repeat {
                offset += 1
            } while currentByte.map {
                CharacterByte.zero ... CharacterByte.nine ~= $0
            } == true
        } else {
            throw invalidSyntax(at: start)
        }

        if let byte = currentByte,
           byte == CharacterByte.period
            || byte == CharacterByte.lowercaseE
            || byte == CharacterByte.uppercaseE {
            throw CurriculumJSONCodecError.nonIntegerNumber(offset: start)
        }
    }

    private mutating func consumeLiteral(_ literal: StaticString) throws {
        let expected = Array(String(describing: literal).utf8)
        guard offset + expected.count <= bytes.count,
              Array(bytes[offset ..< offset + expected.count]) == expected else {
            throw invalidSyntax()
        }
        offset += expected.count
    }

    private mutating func consume(_ expected: UInt8) throws {
        guard consumeIfPresent(expected) else {
            throw invalidSyntax()
        }
    }

    private mutating func consumeIfPresent(_ expected: UInt8) -> Bool {
        guard currentByte == expected else {
            return false
        }
        offset += 1
        return true
    }

    private mutating func skipWhitespace() {
        while let byte = currentByte,
              byte == CharacterByte.space
                || byte == CharacterByte.tab
                || byte == CharacterByte.lineFeed
                || byte == CharacterByte.carriageReturn {
            offset += 1
        }
    }

    private var currentByte: UInt8? {
        offset < bytes.count ? bytes[offset] : nil
    }

    private func invalidSyntax(at offset: Int? = nil) -> CurriculumJSONCodecError {
        .invalidSyntax(offset: offset ?? self.offset)
    }

    private func isHexDigit(_ byte: UInt8) -> Bool {
        CharacterByte.zero ... CharacterByte.nine ~= byte
            || CharacterByte.lowercaseA ... CharacterByte.lowercaseF ~= byte
            || CharacterByte.uppercaseA ... CharacterByte.uppercaseF ~= byte
    }
}

private enum CharacterByte {
    static let tab: UInt8 = 0x09
    static let lineFeed: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let space: UInt8 = 0x20
    static let quote: UInt8 = 0x22
    static let comma: UInt8 = 0x2C
    static let minus: UInt8 = 0x2D
    static let period: UInt8 = 0x2E
    static let slash: UInt8 = 0x2F
    static let zero: UInt8 = 0x30
    static let one: UInt8 = 0x31
    static let nine: UInt8 = 0x39
    static let colon: UInt8 = 0x3A
    static let uppercaseA: UInt8 = 0x41
    static let uppercaseE: UInt8 = 0x45
    static let uppercaseF: UInt8 = 0x46
    static let leftBracket: UInt8 = 0x5B
    static let backslash: UInt8 = 0x5C
    static let rightBracket: UInt8 = 0x5D
    static let lowercaseA: UInt8 = 0x61
    static let b: UInt8 = 0x62
    static let lowercaseE: UInt8 = 0x65
    static let f: UInt8 = 0x66
    static let lowercaseF: UInt8 = 0x66
    static let n: UInt8 = 0x6E
    static let r: UInt8 = 0x72
    static let t: UInt8 = 0x74
    static let u: UInt8 = 0x75
    static let leftBrace: UInt8 = 0x7B
    static let rightBrace: UInt8 = 0x7D
}
