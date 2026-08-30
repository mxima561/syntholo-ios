struct ProgramVersionReference: Equatable, Hashable, Sendable {
    let locale: CurriculumLocale
    let catalogVersionID: CurriculumCatalogVersionID
    let programVersionID: CurriculumVersionID
}

struct ModuleVersionReference: Equatable, Hashable, Sendable {
    let locale: CurriculumLocale
    let catalogVersionID: CurriculumCatalogVersionID
    let programVersionID: CurriculumVersionID
    let moduleVersionID: CurriculumVersionID
}

struct LessonVersionReference: Equatable, Hashable, Sendable {
    let locale: CurriculumLocale
    let catalogVersionID: CurriculumCatalogVersionID
    let programVersionID: CurriculumVersionID
    let moduleVersionID: CurriculumVersionID
    let lessonVersionID: CurriculumVersionID
    let rubricVersionID: CurriculumVersionID
}

enum LearnRoute: Equatable, Hashable, Sendable {
    case program(ProgramVersionReference)
    case module(ModuleVersionReference)
    case lesson(LessonVersionReference)

    var locale: CurriculumLocale {
        switch self {
        case let .program(reference):
            reference.locale
        case let .module(reference):
            reference.locale
        case let .lesson(reference):
            reference.locale
        }
    }

    var catalogVersionID: CurriculumCatalogVersionID {
        switch self {
        case let .program(reference):
            reference.catalogVersionID
        case let .module(reference):
            reference.catalogVersionID
        case let .lesson(reference):
            reference.catalogVersionID
        }
    }
}
