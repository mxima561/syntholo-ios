enum CurriculumCacheEnvironment: String, Codable, Equatable, Hashable, Sendable {
    case development
    case staging
    case production
}

struct CurriculumCacheScope: Equatable, Hashable, Sendable {
    let environment: CurriculumCacheEnvironment
    let projectID: String
    let projectNumber: String
    let locale: CurriculumLocale

    init(
        environment: CurriculumCacheEnvironment,
        projectID: String,
        projectNumber: String,
        locale: CurriculumLocale
    ) throws {
        guard Self.isValidProjectID(projectID),
              Self.isValidProjectNumber(projectNumber) else {
            throw CurriculumCacheError.invalidScope
        }

        self.environment = environment
        self.projectID = projectID
        self.projectNumber = projectNumber
        self.locale = locale
    }

    private static func isValidProjectID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...120).contains(bytes.count),
              let first = bytes.first,
              let last = bytes.last,
              isLowercaseASCIIAlphaNumeric(first),
              isLowercaseASCIIAlphaNumeric(last) else {
            return false
        }

        return bytes.allSatisfy {
            isLowercaseASCIIAlphaNumeric($0) || $0 == 45
        }
    }

    private static func isValidProjectNumber(_ value: String) -> Bool {
        if value == "emulator" {
            return true
        }

        let bytes = Array(value.utf8)
        return (6...20).contains(bytes.count)
            && bytes.allSatisfy { (48...57).contains($0) }
    }

    private static func isLowercaseASCIIAlphaNumeric(_ value: UInt8) -> Bool {
        (48...57).contains(value) || (97...122).contains(value)
    }
}

enum CurriculumCacheError: Error, Equatable, Sendable {
    case invalidScope
    case corrupt
    case unsupportedEnvelopeVersion(found: Int, supported: Int)
    case wrongSource
    case invalidSnapshot(issues: [CurriculumValidationIssue])
    case digestManifestMismatch(identifier: String?)
    case readFailed
    case writeFailed
}

protocol CurriculumCache: Sendable {
    func load(for scope: CurriculumCacheScope) async throws -> CurriculumSnapshot?

    func replace(
        with snapshot: CurriculumSnapshot,
        for scope: CurriculumCacheScope
    ) async throws
}
