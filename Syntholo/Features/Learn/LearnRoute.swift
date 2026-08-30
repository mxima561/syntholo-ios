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

enum FirstLessonPreviewResolver {
    private static let foundationsProgramID = "ai-foundations"

    static func reference(
        in snapshot: CurriculumSnapshot
    ) -> LessonVersionReference? {
        guard snapshot.catalogVersion.locale == snapshot.locale,
              let catalogEntry = onlyElement(
                  in: snapshot.catalogVersion.programEntries,
                  matching: {
                      $0.programPointerID.stableIDToken == foundationsProgramID
                  }
              ),
              let program = onlyElement(
                  in: snapshot.programVersions,
                  matching: {
                      $0.programVersionID == catalogEntry.programVersionID
                          && $0.programID.rawValue == foundationsProgramID
                  }
              ),
              program.catalogState == .available,
              program.locale == snapshot.locale,
              let firstLessonVersionID = program.firstLessonVersionID,
              let module = onlyElement(
                  in: snapshot.moduleVersions,
                  matching: {
                      program.moduleVersionIDs.contains($0.moduleVersionID)
                          && $0.lessonVersionIDs.contains(firstLessonVersionID)
                  }
              ),
              module.programID == program.programID,
              module.locale == snapshot.locale,
              let lesson = onlyElement(
                  in: snapshot.lessonVersions,
                  matching: {
                      $0.lessonVersionID == firstLessonVersionID
                  }
              ),
              lesson.programID == program.programID,
              lesson.moduleID == module.moduleID,
              lesson.locale == snapshot.locale,
              let rubric = onlyElement(
                  in: snapshot.rubricVersions,
                  matching: {
                      $0.rubricVersionID == lesson.rubricVersionID
                  }
              ),
              rubric.locale == snapshot.locale else {
            return nil
        }

        let reference = LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: rubric.rubricVersionID
        )
        guard LessonPreviewPresentation(
            snapshot: snapshot,
            reference: reference
        ) != nil else {
            return nil
        }
        return reference
    }

    private static func onlyElement<Element>(
        in elements: [Element],
        matching predicate: (Element) -> Bool
    ) -> Element? {
        var match: Element?
        for element in elements where predicate(element) {
            guard match == nil else {
                return nil
            }
            match = element
        }
        return match
    }
}
