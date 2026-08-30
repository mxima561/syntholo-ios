import CoreFoundation
import Foundation
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore

enum CurriculumDocumentStoreError: Error, Equatable, Sendable {
    case authenticationRequired
    case networkUnavailable
    case operationCancelled
    case malformedDocument(path: String)
    case backendFailure
}

indirect enum CurriculumDocumentValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case integer(Int)
    case array([CurriculumDocumentValue])
    case map([String: CurriculumDocumentValue])
    case timestamp(CurriculumTimestamp)
    case null

    static func normalizingFirestoreValue(
        _ value: Any
    ) throws -> CurriculumDocumentValue {
        if value is NSNull {
            return .null
        }
        if let value = value as? String {
            return .string(value)
        }
        if let value = value as? Timestamp {
            return .timestamp(
                CurriculumTimestamp(
                    seconds: value.seconds,
                    nanoseconds: value.nanoseconds
                )
            )
        }
        if let value = value as? NSNumber {
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }

            let number = value.doubleValue
            guard !CFNumberIsFloatType(value),
                  number.isFinite,
                  number.rounded(.towardZero) == number,
                  value.compare(NSNumber(value: Int.min)) != .orderedAscending,
                  value.compare(NSNumber(value: Int.max)) != .orderedDescending else {
                throw CurriculumDocumentNormalizationError.unsupportedValue
            }
            return .integer(value.intValue)
        }
        if let value = value as? [Any] {
            return .array(
                try value.map(Self.normalizingFirestoreValue)
            )
        }
        if let value = value as? [String: Any] {
            return .map(
                try value.mapValues(Self.normalizingFirestoreValue)
            )
        }
        throw CurriculumDocumentNormalizationError.unsupportedValue
    }

    fileprivate var jsonObject: Any {
        switch self {
        case let .string(value):
            value
        case let .bool(value):
            value
        case let .integer(value):
            value
        case let .array(values):
            values.map(\.jsonObject)
        case let .map(values):
            values.mapValues(\.jsonObject)
        case let .timestamp(value):
            [
                "seconds": value.seconds,
                "nanoseconds": value.nanoseconds,
            ]
        case .null:
            NSNull()
        }
    }
}

typealias CurriculumDocument = [String: CurriculumDocumentValue]

protocol CurriculumDocumentStore: Sendable {
    func get(path: String) async throws -> CurriculumDocument?
}

enum CurriculumFirestoreDocumentNormalizer {
    static func normalize(
        _ data: [String: Any],
        path: String
    ) throws -> CurriculumDocument {
        do {
            return try data.mapValues(
                CurriculumDocumentValue.normalizingFirestoreValue
            )
        } catch {
            throw CurriculumDocumentStoreError.malformedDocument(path: path)
        }
    }
}

enum CurriculumFirestoreErrorClassifier {
    static func classify(_ error: Error) -> CurriculumDocumentStoreError {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else {
            return .backendFailure
        }
        switch nsError.code {
        case FirestoreErrorCode.unauthenticated.rawValue:
            return .authenticationRequired
        case FirestoreErrorCode.unavailable.rawValue,
             FirestoreErrorCode.deadlineExceeded.rawValue:
            return .networkUnavailable
        case FirestoreErrorCode.cancelled.rawValue:
            return .operationCancelled
        default:
            return .backendFailure
        }
    }
}

struct CurriculumRepositorySourceIdentity: Equatable, Sendable {
    let environment: CurriculumCacheEnvironment
    let projectID: String
    let projectNumber: String

    init(
        environment: CurriculumCacheEnvironment,
        projectID: String,
        projectNumber: String
    ) {
        self.environment = environment
        self.projectID = projectID
        self.projectNumber = projectNumber
    }

    init(
        configuration: FirebaseRuntimeConfiguration,
        firestoreProjectID: String?,
        firestoreProjectNumber: String?
    ) throws {
        guard configuration.isConfigured,
              let configuredProjectID = configuration.projectID,
              let configuredProjectNumber = configuration.projectNumber,
              configuredProjectID == firestoreProjectID else {
            throw CurriculumRepositoryError.wrongEnvironment
        }

        switch configuration.environment {
        case .development:
            environment = .development
        case .staging:
            environment = .staging
        case .production:
            environment = .production
        }

        if configuration.useEmulators {
            guard configuration.environment == .development,
                  configuredProjectNumber == "emulator" else {
                throw CurriculumRepositoryError.wrongEnvironment
            }
        } else {
            guard configuredProjectNumber == firestoreProjectNumber else {
                throw CurriculumRepositoryError.wrongEnvironment
            }
        }

        projectID = configuredProjectID
        projectNumber = configuredProjectNumber
    }
}

struct FirestoreCurriculumRepository: CurriculumRepository {
    private static let configurationPath = "featureConfiguration/curriculum"
    private static let supportedSchemaVersion = CurriculumSchema.currentVersion

    private let store: any CurriculumDocumentStore
    private let cache: any CurriculumCache
    private let sourceIdentity: CurriculumRepositorySourceIdentity

    init(
        store: any CurriculumDocumentStore,
        cache: any CurriculumCache,
        scope: CurriculumCacheScope
    ) {
        self.store = store
        self.cache = cache
        sourceIdentity = CurriculumRepositorySourceIdentity(
            environment: scope.environment,
            projectID: scope.projectID,
            projectNumber: scope.projectNumber
        )
    }

    init(
        firestore: Firestore = .firestore(),
        cache: any CurriculumCache = FileCurriculumCache(),
        configuration: FirebaseRuntimeConfiguration
    ) throws {
        let identity = try CurriculumRepositorySourceIdentity(
            configuration: configuration,
            firestoreProjectID: firestore.app.options.projectID,
            firestoreProjectNumber: firestore.app.options.gcmSenderID
        )
        store = FirestoreCurriculumDocumentStore(firestore: firestore)
        self.cache = cache
        sourceIdentity = identity
    }

    func load(locale: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            let task = Task {
                await runLoad(locale: locale, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func runLoad(
        locale: CurriculumLocale,
        continuation: AsyncStream<CurriculumLoadEvent>.Continuation
    ) async {
        defer { continuation.finish() }

        let scope: CurriculumCacheScope
        do {
            scope = try CurriculumCacheScope(
                environment: sourceIdentity.environment,
                projectID: sourceIdentity.projectID,
                projectNumber: sourceIdentity.projectNumber,
                locale: locale
            )
        } catch {
            continuation.yield(
                .unavailable(error: .wrongEnvironment, saved: nil)
            )
            return
        }

        var savedSnapshot: CurriculumSnapshot?
        do {
            savedSnapshot = try await cache.load(for: scope)
            try Task.checkCancellation()
            if let savedSnapshot {
                continuation.yield(.saved(savedSnapshot))
            }
        } catch is CancellationError {
            return
        } catch {
            savedSnapshot = nil
        }

        do {
            let resolution = try await resolveRemote(locale: locale)
            try Task.checkCancellation()

            switch resolution {
            case .notPublished:
                if let savedSnapshot {
                    continuation.yield(
                        .unavailable(
                            error: .notPublished,
                            saved: savedSnapshot
                        )
                    )
                } else {
                    continuation.yield(.empty)
                }
            case let .updateRequired(requiredSchema):
                continuation.yield(
                    .updateRequired(
                        requiredSchema: requiredSchema,
                        saved: savedSnapshot
                    )
                )
            case let .snapshot(snapshot):
                try Task.checkCancellation()
                do {
                    try await cache.replace(with: snapshot, for: scope)
                } catch is CancellationError {
                    return
                } catch {
                    throw CurriculumRepositoryError.backendFailure
                }
                try Task.checkCancellation()
                continuation.yield(.fresh(snapshot))
            }
        } catch is CancellationError {
            return
        } catch let error as CurriculumRepositoryError {
            guard !Task.isCancelled else { return }
            continuation.yield(
                .unavailable(error: error, saved: savedSnapshot)
            )
        } catch let error as CurriculumDocumentStoreError {
            guard !Task.isCancelled else { return }
            continuation.yield(
                .unavailable(
                    error: Self.repositoryError(for: error),
                    saved: savedSnapshot
                )
            )
        } catch {
            guard !Task.isCancelled else { return }
            continuation.yield(
                .unavailable(error: .backendFailure, saved: savedSnapshot)
            )
        }
    }

    private func resolveRemote(
        locale: CurriculumLocale
    ) async throws -> RemoteResolution {
        try Task.checkCancellation()
        guard let configurationDocument = try await store.get(
            path: Self.configurationPath
        ) else {
            return .notPublished
        }

        let configurationMinimum = try compatibilityMinimum(
            in: configurationDocument,
            path: Self.configurationPath
        )
        if configurationMinimum > Self.supportedSchemaVersion {
            return .updateRequired(configurationMinimum)
        }

        let configuration = try decodeConfiguration(configurationDocument)
        guard configuration.supportedLocales.contains(locale),
              configuration.catalogPointerIDs.contains(locale.token) else {
            return .notPublished
        }

        try Task.checkCancellation()
        let pointerPath = "catalogs/\(locale.token.rawValue)"
        guard let pointerDocument = try await store.get(path: pointerPath) else {
            throw CurriculumRepositoryError.brokenReference(
                id: locale.token.rawValue
            )
        }

        let pointerMinimum = try compatibilityMinimum(
            in: pointerDocument,
            path: pointerPath
        )
        if pointerMinimum > Self.supportedSchemaVersion {
            return .updateRequired(pointerMinimum)
        }

        let catalogVersionID = try decodeCatalogPointer(
            pointerDocument,
            locale: locale,
            path: pointerPath
        )
        let catalogPath = "catalogVersions/\(catalogVersionID.rawValue)"
        let catalog: CurriculumCatalogVersion = try await requiredImmutable(
            at: catalogPath,
            identifier: catalogVersionID.rawValue,
            as: CurriculumCatalogVersion.self
        )
        guard catalog.catalogVersionID == catalogVersionID else {
            throw CurriculumRepositoryError.brokenReference(
                id: catalogVersionID.rawValue
            )
        }

        var programs: [CurriculumProgramVersion] = []
        var seenProgramIDs = Set<CurriculumVersionID>()
        for entry in catalog.programEntries
            where seenProgramIDs.insert(entry.programVersionID).inserted {
            let identifier = entry.programVersionID.rawValue
            let program: CurriculumProgramVersion = try await requiredImmutable(
                at: "programVersions/\(identifier)",
                identifier: identifier,
                as: CurriculumProgramVersion.self
            )
            guard program.programVersionID == entry.programVersionID else {
                throw CurriculumRepositoryError.brokenReference(id: identifier)
            }
            programs.append(program)
        }

        var modules: [CurriculumModuleVersion] = []
        var seenModuleIDs = Set<CurriculumVersionID>()
        for program in programs {
            for moduleID in program.moduleVersionIDs
                where seenModuleIDs.insert(moduleID).inserted {
                let identifier = moduleID.rawValue
                let module: CurriculumModuleVersion = try await requiredImmutable(
                    at: "modules/\(identifier)",
                    identifier: identifier,
                    as: CurriculumModuleVersion.self
                )
                guard module.moduleVersionID == moduleID else {
                    throw CurriculumRepositoryError.brokenReference(id: identifier)
                }
                modules.append(module)
            }
        }

        var lessons: [CurriculumLessonVersion] = []
        var seenLessonIDs = Set<CurriculumVersionID>()
        for module in modules {
            for lessonID in module.lessonVersionIDs
                where seenLessonIDs.insert(lessonID).inserted {
                let identifier = lessonID.rawValue
                let lesson: CurriculumLessonVersion = try await requiredImmutable(
                    at: "lessonVersions/\(identifier)",
                    identifier: identifier,
                    as: CurriculumLessonVersion.self
                )
                guard lesson.lessonVersionID == lessonID else {
                    throw CurriculumRepositoryError.brokenReference(id: identifier)
                }
                lessons.append(lesson)
            }
        }

        var rubrics: [CurriculumRubricVersion] = []
        var assets: [CurriculumAssetVersion] = []
        var seenRubricIDs = Set<CurriculumVersionID>()
        var seenAssetIDs = Set<CurriculumVersionID>()
        for lesson in lessons {
            let rubricID = lesson.rubricVersionID
            if seenRubricIDs.insert(rubricID).inserted {
                let identifier = rubricID.rawValue
                let rubric: CurriculumRubricVersion = try await requiredImmutable(
                    at: "rubricVersions/\(identifier)",
                    identifier: identifier,
                    as: CurriculumRubricVersion.self
                )
                guard rubric.rubricVersionID == rubricID else {
                    throw CurriculumRepositoryError.brokenReference(id: identifier)
                }
                rubrics.append(rubric)
            }

            for assetID in lesson.assetVersionIDs
                where seenAssetIDs.insert(assetID).inserted {
                let identifier = assetID.rawValue
                let asset: CurriculumAssetVersion = try await requiredImmutable(
                    at: "assetVersions/\(identifier)",
                    identifier: identifier,
                    as: CurriculumAssetVersion.self
                )
                guard asset.assetVersionID == assetID else {
                    throw CurriculumRepositoryError.brokenReference(id: identifier)
                }
                assets.append(asset)
            }
        }

        let snapshot = CurriculumSnapshot(
            locale: locale,
            catalogPointerID: locale.token,
            catalogVersion: catalog,
            programVersions: programs,
            moduleVersions: modules,
            lessonVersions: lessons,
            rubricVersions: rubrics,
            assetVersions: assets
        )

        do {
            try CurriculumValidator.validate(snapshot)
        } catch let error as CurriculumValidationError {
            throw Self.repositoryError(for: error)
        }
        return .snapshot(snapshot)
    }

    private func compatibilityMinimum(
        in document: CurriculumDocument,
        path: String
    ) throws -> Int {
        guard case let .integer(value)? = document["minimumClientSchemaVersion"],
              value > 0 else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        return value
    }

    private func decodeConfiguration(
        _ document: CurriculumDocument
    ) throws -> CurriculumFeatureConfiguration {
        let path = Self.configurationPath
        try requireExactKeys(
            in: document,
            expected: [
                "schemaVersion",
                "minimumClientSchemaVersion",
                "defaultLocale",
                "supportedLocales",
                "catalogPointerIDs",
                "updatedAt",
            ],
            path: path
        )
        try validateHeaderCompatibility(in: document, path: path)
        _ = try requiredTimestamp(in: document, key: "updatedAt", path: path)

        guard case let .string(defaultLocaleValue)? = document["defaultLocale"],
              case let .array(localeValues)? = document["supportedLocales"],
              case let .array(pointerValues)? = document["catalogPointerIDs"],
              (1...10).contains(localeValues.count),
              localeValues.count == pointerValues.count else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }

        do {
            let defaultLocale = try CurriculumLocale(defaultLocaleValue)
            let supportedLocales = try localeValues.map { value in
                guard case let .string(rawValue) = value else {
                    throw CurriculumDocumentNormalizationError.unsupportedValue
                }
                return try CurriculumLocale(rawValue)
            }
            let pointerIDs = try pointerValues.map { value in
                guard case let .string(rawValue) = value else {
                    throw CurriculumDocumentNormalizationError.unsupportedValue
                }
                return try CurriculumLocaleToken(rawValue)
            }
            guard defaultLocale.rawValue == "en-US",
                  supportedLocales == [defaultLocale],
                  pointerIDs == [defaultLocale.token] else {
                throw CurriculumDocumentNormalizationError.unsupportedValue
            }
            return CurriculumFeatureConfiguration(
                supportedLocales: supportedLocales,
                catalogPointerIDs: pointerIDs
            )
        } catch let error as CurriculumRepositoryError {
            throw error
        } catch {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
    }

    private func decodeCatalogPointer(
        _ document: CurriculumDocument,
        locale: CurriculumLocale,
        path: String
    ) throws -> CurriculumCatalogVersionID {
        try requireExactKeys(
            in: document,
            expected: [
                "locale",
                "publishedCatalogVersionID",
                "schemaVersion",
                "minimumClientSchemaVersion",
                "updatedAt",
            ],
            path: path
        )
        try validateHeaderCompatibility(in: document, path: path)
        _ = try requiredTimestamp(in: document, key: "updatedAt", path: path)

        guard case let .string(localeValue)? = document["locale"],
              case let .string(identifierValue)? = document["publishedCatalogVersionID"] else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        do {
            let storedLocale = try CurriculumLocale(localeValue)
            let identifier = try CurriculumCatalogVersionID(identifierValue)
            guard storedLocale == locale,
                  identifier.locale == locale else {
                throw CurriculumDocumentNormalizationError.unsupportedValue
            }
            return identifier
        } catch {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
    }

    private func validateHeaderCompatibility(
        in document: CurriculumDocument,
        path: String
    ) throws {
        guard case let .integer(schemaVersion)? = document["schemaVersion"],
              case let .integer(minimumVersion)? = document[
                "minimumClientSchemaVersion"
              ],
              minimumVersion > 0 else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw CurriculumRepositoryError.unsupportedSchema(
                found: schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }
        guard minimumVersion <= Self.supportedSchemaVersion else {
            throw CurriculumRepositoryError.minimumClientUnsupported(
                required: minimumVersion,
                supported: Self.supportedSchemaVersion
            )
        }
    }

    private func requiredImmutable<Value: Decodable>(
        at path: String,
        identifier: String,
        as type: Value.Type
    ) async throws -> Value {
        try Task.checkCancellation()
        guard let document = try await store.get(path: path) else {
            throw CurriculumRepositoryError.brokenReference(id: identifier)
        }
        try Task.checkCancellation()
        try validateImmutableCompatibility(in: document, path: path)
        return try decode(document, path: path, as: type)
    }

    private func validateImmutableCompatibility(
        in document: CurriculumDocument,
        path: String
    ) throws {
        guard case let .integer(schemaVersion)? = document["schemaVersion"],
              case let .integer(minimumVersion)? = document[
                "minimumClientSchemaVersion"
              ],
              minimumVersion > 0 else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw CurriculumRepositoryError.unsupportedSchema(
                found: schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }
        guard minimumVersion <= Self.supportedSchemaVersion else {
            throw CurriculumRepositoryError.minimumClientUnsupported(
                required: minimumVersion,
                supported: Self.supportedSchemaVersion
            )
        }
        _ = try requiredTimestamp(in: document, key: "publishedAt", path: path)
    }

    private func decode<Value: Decodable>(
        _ document: CurriculumDocument,
        path: String,
        as type: Value.Type
    ) throws -> Value {
        let object = document.mapValues(\.jsonObject)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )
            return try JSONDecoder().decode(type, from: data)
        } catch let error as CurriculumRepositoryError {
            throw error
        } catch {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
    }

    private func requireExactKeys(
        in document: CurriculumDocument,
        expected: Set<String>,
        path: String
    ) throws {
        guard Set(document.keys) == expected else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
    }

    private func requiredTimestamp(
        in document: CurriculumDocument,
        key: String,
        path: String
    ) throws -> CurriculumTimestamp {
        guard case let .timestamp(timestamp)? = document[key],
              (0..<1_000_000_000).contains(timestamp.nanoseconds) else {
            throw CurriculumRepositoryError.malformedDocument(path: path)
        }
        return timestamp
    }

    private static func repositoryError(
        for error: CurriculumDocumentStoreError
    ) -> CurriculumRepositoryError {
        switch error {
        case .authenticationRequired:
            .authenticationRequired
        case .networkUnavailable:
            .networkUnavailable
        case .operationCancelled:
            .operationCancelled
        case let .malformedDocument(path):
            .malformedDocument(path: path)
        case .backendFailure:
            .backendFailure
        }
    }

    private static func repositoryError(
        for error: CurriculumValidationError
    ) -> CurriculumRepositoryError {
        if let issue = error.issues.first(where: {
            $0.code == .digestMismatch || $0.code == .payloadDigestMismatch
        }) {
            return .digestMismatch(id: issue.identifier ?? "unknown")
        }
        if let issue = error.issues.first(where: { $0.code == .brokenReference }) {
            return .brokenReference(id: issue.identifier ?? "unknown")
        }
        return .contentUnavailable
    }
}

private struct CurriculumFeatureConfiguration: Sendable {
    let supportedLocales: [CurriculumLocale]
    let catalogPointerIDs: [CurriculumLocaleToken]
}

private enum RemoteResolution: Sendable {
    case notPublished
    case updateRequired(Int)
    case snapshot(CurriculumSnapshot)
}

private enum CurriculumDocumentNormalizationError: Error {
    case unsupportedValue
}

private final class FirestoreCurriculumDocumentStore: CurriculumDocumentStore,
    @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func get(path: String) async throws -> CurriculumDocument? {
        let gate = FirestoreDocumentReadGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.install(continuation) else { return }
                firestore.document(path).getDocument(source: .server) {
                    snapshot,
                    error in
                    if let error {
                        gate.finish(
                            .failure(
                                CurriculumFirestoreErrorClassifier.classify(error)
                            )
                        )
                        return
                    }
                    guard let snapshot else {
                        gate.finish(.failure(CurriculumDocumentStoreError.backendFailure))
                        return
                    }
                    guard snapshot.exists else {
                        gate.finish(.success(nil))
                        return
                    }
                    guard let data = snapshot.data() else {
                        gate.finish(.failure(CurriculumDocumentStoreError.backendFailure))
                        return
                    }
                    do {
                        gate.finish(
                            .success(
                                try CurriculumFirestoreDocumentNormalizer.normalize(
                                    data,
                                    path: path
                                )
                            )
                        )
                    } catch {
                        gate.finish(.failure(error))
                    }
                }
            }
        } onCancel: {
            gate.finish(.failure(CancellationError()))
        }
    }
}

private final class FirestoreDocumentReadGate: @unchecked Sendable {
    typealias Output = CurriculumDocument?

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Output, Error>?
    private var pendingResult: Result<Output, Error>?
    private var isFinished = false

    @discardableResult
    func install(_ continuation: CheckedContinuation<Output, Error>) -> Bool {
        lock.lock()
        if let pendingResult {
            self.pendingResult = nil
            lock.unlock()
            continuation.resume(with: pendingResult)
            return false
        }
        guard !isFinished else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func finish(_ result: Result<Output, Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = continuation
        self.continuation = nil
        if continuation == nil {
            pendingResult = result
        }
        lock.unlock()
        continuation?.resume(with: result)
    }
}
