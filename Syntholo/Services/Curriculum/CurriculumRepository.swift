enum CurriculumRepositoryError: Error, Equatable, Hashable, Sendable {
    case notPublished
    case contentUnavailable
    case authenticationRequired
    case networkUnavailable
    case malformedDocument(path: String)
    case brokenReference(id: String)
    case digestMismatch(id: String)
    case unsupportedSchema(found: Int, supported: Int)
    case minimumClientUnsupported(required: Int, supported: Int)
    case cacheCorrupt
    case wrongEnvironment
    case operationCancelled
    case backendFailure
}

enum CurriculumLoadEvent: Equatable, Sendable {
    case saved(CurriculumSnapshot)
    case fresh(CurriculumSnapshot)
    case empty
    case updateRequired(requiredSchema: Int, saved: CurriculumSnapshot?)
    case unavailable(
        error: CurriculumRepositoryError,
        saved: CurriculumSnapshot?
    )
}

protocol CurriculumRepository: Sendable {
    func load(locale: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent>
}
