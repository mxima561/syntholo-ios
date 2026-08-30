import Foundation

protocol CurriculumCacheFileSystem: Sendable {
    func fileExists(at url: URL) -> Bool
    func readData(at url: URL, maximumBytes: Int) throws -> Data
    func createDirectory(at url: URL) throws
    func atomicallyReplace(with data: Data, at url: URL) throws
    func quarantineItem(at sourceURL: URL, to destinationURL: URL) throws
}

enum CurriculumCacheFileSystemError: Error {
    case inputTooLarge
}

struct FoundationCurriculumCacheFileSystem: CurriculumCacheFileSystem {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func readData(at url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize, fileSize > maximumBytes {
            throw CurriculumCacheFileSystemError.inputTooLarge
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumBytes else {
            throw CurriculumCacheFileSystemError.inputTooLarge
        }
        return data
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func atomicallyReplace(with data: Data, at url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func quarantineItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}

actor FileCurriculumCache: CurriculumCache {
    private static let envelopeVersion = 1
    private static let maximumEnvelopeBytes = 10 * 1_024 * 1_024
    private static let minimumTimestampMilliseconds: Int64 = -62_135_596_800_000
    private static let maximumTimestampMilliseconds: Int64 = 253_402_300_799_999

    private let rootURL: URL
    private let now: @Sendable () -> Date
    private let fileSystem: any CurriculumCacheFileSystem

    init(
        rootURL: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init,
        fileSystem: any CurriculumCacheFileSystem = FoundationCurriculumCacheFileSystem()
    ) {
        self.rootURL = rootURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
        self.now = now
        self.fileSystem = fileSystem
    }

    func load(for scope: CurriculumCacheScope) async throws -> CurriculumSnapshot? {
        let url = Self.cacheFileURL(rootURL: rootURL, scope: scope)
        guard fileSystem.fileExists(at: url) else {
            return nil
        }

        let data: Data
        do {
            data = try fileSystem.readData(
                at: url,
                maximumBytes: Self.maximumEnvelopeBytes
            )
        } catch CurriculumCacheFileSystemError.inputTooLarge {
            throw reject(.corrupt, cacheURL: url)
        } catch {
            throw CurriculumCacheError.readFailed
        }

        let envelope: CurriculumCacheEnvelopeV1
        do {
            guard data.count <= Self.maximumEnvelopeBytes else {
                throw CurriculumCacheError.corrupt
            }
            var preflight = StrictCurriculumJSONPreflight(data: data)
            try preflight.validate()
            envelope = try JSONDecoder().decode(
                CurriculumCacheEnvelopeV1.self,
                from: data
            )
        } catch let error as CurriculumCacheError {
            throw reject(error, cacheURL: url)
        } catch {
            throw reject(.corrupt, cacheURL: url)
        }

        do {
            try validate(envelope, for: scope)
            return envelope.snapshot
        } catch let error as CurriculumCacheError {
            throw reject(error, cacheURL: url)
        } catch {
            throw reject(.corrupt, cacheURL: url)
        }
    }

    func replace(
        with snapshot: CurriculumSnapshot,
        for scope: CurriculumCacheScope
    ) async throws {
        let commitGate = CurriculumCacheCommitGate()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try validate(snapshot, for: scope)

            let savedAtUTCMilliseconds = try cacheMilliseconds(now())
            let envelope = CurriculumCacheEnvelopeV1(
                envelopeVersion: Self.envelopeVersion,
                savedAtUTCMilliseconds: savedAtUTCMilliseconds,
                source: CurriculumCacheSourceV1(
                    environment: scope.environment,
                    projectID: scope.projectID,
                    projectNumber: scope.projectNumber
                ),
                locale: scope.locale,
                catalogPointerID: snapshot.catalogPointerID,
                catalogVersionID: snapshot.catalogVersion.catalogVersionID,
                programEntries: snapshot.catalogVersion.programEntries,
                documentDigests: CurriculumCacheDocumentDigestV1.manifest(
                    for: snapshot
                ),
                snapshot: snapshot
            )

            let data: Data
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                data = try encoder.encode(envelope)
                guard data.count <= Self.maximumEnvelopeBytes else {
                    throw CurriculumCacheError.writeFailed
                }
            } catch let error as CurriculumCacheError {
                throw error
            } catch {
                throw CurriculumCacheError.writeFailed
            }

            let url = Self.cacheFileURL(rootURL: rootURL, scope: scope)
            try Task.checkCancellation()
            do {
                try commitGate.commit {
                    try fileSystem.createDirectory(
                        at: url.deletingLastPathComponent()
                    )
                    try fileSystem.atomicallyReplace(with: data, at: url)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw CurriculumCacheError.writeFailed
            }
        } onCancel: {
            commitGate.cancel()
        }
    }

    static func cacheFileURL(
        rootURL: URL,
        scope: CurriculumCacheScope
    ) -> URL {
        rootURL
            .appendingPathComponent("Curriculum", isDirectory: true)
            .appendingPathComponent(scope.environment.rawValue, isDirectory: true)
            .appendingPathComponent(scope.projectID, isDirectory: true)
            .appendingPathComponent(scope.locale.rawValue, isDirectory: true)
            .appendingPathComponent(
                "catalog-snapshot-v\(envelopeVersion).json",
                isDirectory: false
            )
    }

    private func validate(
        _ snapshot: CurriculumSnapshot,
        for scope: CurriculumCacheScope
    ) throws {
        guard snapshot.locale == scope.locale,
              snapshot.catalogPointerID == scope.locale.token,
              snapshot.catalogVersion.locale == scope.locale else {
            throw CurriculumCacheError.wrongSource
        }

        do {
            try CurriculumValidator.validate(snapshot)
        } catch let error as CurriculumValidationError {
            throw CurriculumCacheError.invalidSnapshot(issues: error.issues)
        } catch {
            throw CurriculumCacheError.corrupt
        }
    }

    private func validate(
        _ envelope: CurriculumCacheEnvelopeV1,
        for scope: CurriculumCacheScope
    ) throws {
        guard envelope.envelopeVersion == Self.envelopeVersion else {
            throw CurriculumCacheError.unsupportedEnvelopeVersion(
                found: envelope.envelopeVersion,
                supported: Self.envelopeVersion
            )
        }
        guard (Self.minimumTimestampMilliseconds...Self.maximumTimestampMilliseconds)
            .contains(envelope.savedAtUTCMilliseconds) else {
            throw CurriculumCacheError.corrupt
        }
        guard envelope.source.environment == scope.environment,
              envelope.source.projectID == scope.projectID,
              envelope.source.projectNumber == scope.projectNumber,
              envelope.locale == scope.locale,
              envelope.snapshot.locale == scope.locale else {
            throw CurriculumCacheError.wrongSource
        }
        guard envelope.catalogPointerID == envelope.snapshot.catalogPointerID,
              envelope.catalogVersionID
                == envelope.snapshot.catalogVersion.catalogVersionID,
              envelope.programEntries
                == envelope.snapshot.catalogVersion.programEntries else {
            throw CurriculumCacheError.corrupt
        }

        let expectedManifest = CurriculumCacheDocumentDigestV1.manifest(
            for: envelope.snapshot
        )
        guard envelope.documentDigests == expectedManifest else {
            throw CurriculumCacheError.digestManifestMismatch(
                identifier: firstManifestMismatch(
                    envelope.documentDigests,
                    expectedManifest
                )
            )
        }

        try validate(envelope.snapshot, for: scope)
    }

    private func firstManifestMismatch(
        _ actual: [CurriculumCacheDocumentDigestV1],
        _ expected: [CurriculumCacheDocumentDigestV1]
    ) -> String? {
        for (actualEntry, expectedEntry) in zip(actual, expected)
            where actualEntry != expectedEntry {
            return expectedEntry.versionID
        }
        if actual.count > expected.count {
            return actual[expected.count].versionID
        }
        if expected.count > actual.count {
            return expected[actual.count].versionID
        }
        return nil
    }

    private func reject(
        _ error: CurriculumCacheError,
        cacheURL: URL
    ) -> CurriculumCacheError {
        let quarantineURL = cacheURL
            .deletingPathExtension()
            .appendingPathExtension(
                "invalid-\(quarantineMilliseconds(now())).json"
            )
        try? fileSystem.quarantineItem(
            at: cacheURL,
            to: quarantineURL
        )
        return error
    }

    private func cacheMilliseconds(_ date: Date) throws -> Int64 {
        let value = floor(date.timeIntervalSince1970 * 1_000)
        guard value.isFinite,
              value >= Double(Self.minimumTimestampMilliseconds),
              value <= Double(Self.maximumTimestampMilliseconds) else {
            throw CurriculumCacheError.writeFailed
        }
        return Int64(value)
    }

    private func quarantineMilliseconds(_ date: Date) -> Int64 {
        (try? cacheMilliseconds(date)) ?? 0
    }
}

private final class CurriculumCacheCommitGate: @unchecked Sendable {
    private enum State: Equatable {
        case ready
        case cancelled
        case committing
    }

    private let lock = NSLock()
    private var state = State.ready

    func cancel() {
        lock.withLock {
            if state == .ready {
                state = .cancelled
            }
        }
    }

    func commit(_ operation: () throws -> Void) throws {
        try lock.withLock {
            switch state {
            case .ready:
                state = .committing
            case .cancelled:
                throw CancellationError()
            case .committing:
                preconditionFailure("A cache commit gate may be entered only once")
            }
        }
        try operation()
    }
}

private struct CurriculumCacheEnvelopeV1: Codable {
    let envelopeVersion: Int
    let savedAtUTCMilliseconds: Int64
    let source: CurriculumCacheSourceV1
    let locale: CurriculumLocale
    let catalogPointerID: CurriculumLocaleToken
    let catalogVersionID: CurriculumCatalogVersionID
    let programEntries: [CatalogProgramEntryV1]
    let documentDigests: [CurriculumCacheDocumentDigestV1]
    let snapshot: CurriculumSnapshot

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case envelopeVersion
        case savedAtUTCMilliseconds
        case source
        case locale
        case catalogPointerID
        case catalogVersionID
        case programEntries
        case documentDigests
        case snapshot
    }

    init(
        envelopeVersion: Int,
        savedAtUTCMilliseconds: Int64,
        source: CurriculumCacheSourceV1,
        locale: CurriculumLocale,
        catalogPointerID: CurriculumLocaleToken,
        catalogVersionID: CurriculumCatalogVersionID,
        programEntries: [CatalogProgramEntryV1],
        documentDigests: [CurriculumCacheDocumentDigestV1],
        snapshot: CurriculumSnapshot
    ) {
        self.envelopeVersion = envelopeVersion
        self.savedAtUTCMilliseconds = savedAtUTCMilliseconds
        self.source = source
        self.locale = locale
        self.catalogPointerID = catalogPointerID
        self.catalogVersionID = catalogVersionID
        self.programEntries = programEntries
        self.documentDigests = documentDigests
        self.snapshot = snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try exactCacheContainer(CodingKeys.self, from: decoder)
        envelopeVersion = try container.decode(Int.self, forKey: .envelopeVersion)
        savedAtUTCMilliseconds = try container.decode(
            Int64.self,
            forKey: .savedAtUTCMilliseconds
        )
        source = try container.decode(CurriculumCacheSourceV1.self, forKey: .source)
        locale = try container.decode(CurriculumLocale.self, forKey: .locale)
        catalogPointerID = try container.decode(
            CurriculumLocaleToken.self,
            forKey: .catalogPointerID
        )
        catalogVersionID = try container.decode(
            CurriculumCatalogVersionID.self,
            forKey: .catalogVersionID
        )
        programEntries = try container.decode(
            [CatalogProgramEntryV1].self,
            forKey: .programEntries
        )
        documentDigests = try container.decode(
            [CurriculumCacheDocumentDigestV1].self,
            forKey: .documentDigests
        )
        snapshot = try container.decode(CurriculumSnapshot.self, forKey: .snapshot)
    }
}

private struct CurriculumCacheSourceV1: Codable, Equatable {
    let environment: CurriculumCacheEnvironment
    let projectID: String
    let projectNumber: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case environment
        case projectID
        case projectNumber
    }

    init(
        environment: CurriculumCacheEnvironment,
        projectID: String,
        projectNumber: String
    ) {
        self.environment = environment
        self.projectID = projectID
        self.projectNumber = projectNumber
    }

    init(from decoder: Decoder) throws {
        let container = try exactCacheContainer(CodingKeys.self, from: decoder)
        environment = try container.decode(
            CurriculumCacheEnvironment.self,
            forKey: .environment
        )
        projectID = try container.decode(String.self, forKey: .projectID)
        projectNumber = try container.decode(String.self, forKey: .projectNumber)
    }
}

private enum CurriculumCacheDocumentKind: String, Codable {
    case catalogVersion
    case programVersion
    case moduleVersion
    case lessonVersion
    case rubricVersion
    case assetVersion
}

private struct CurriculumCacheDocumentDigestV1: Codable, Equatable {
    let kind: CurriculumCacheDocumentKind
    let versionID: String
    let contentDigest: CurriculumDigest

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case versionID
        case contentDigest
    }

    init(
        kind: CurriculumCacheDocumentKind,
        versionID: String,
        contentDigest: CurriculumDigest
    ) {
        self.kind = kind
        self.versionID = versionID
        self.contentDigest = contentDigest
    }

    init(from decoder: Decoder) throws {
        let container = try exactCacheContainer(CodingKeys.self, from: decoder)
        kind = try container.decode(CurriculumCacheDocumentKind.self, forKey: .kind)
        versionID = try container.decode(String.self, forKey: .versionID)
        contentDigest = try container.decode(
            CurriculumDigest.self,
            forKey: .contentDigest
        )
    }

    static func manifest(
        for snapshot: CurriculumSnapshot
    ) -> [CurriculumCacheDocumentDigestV1] {
        var values = [
            CurriculumCacheDocumentDigestV1(
                kind: .catalogVersion,
                versionID: snapshot.catalogVersion.catalogVersionID.rawValue,
                contentDigest: snapshot.catalogVersion.contentDigest
            )
        ]
        values.append(contentsOf: snapshot.programVersions.map {
            CurriculumCacheDocumentDigestV1(
                kind: .programVersion,
                versionID: $0.programVersionID.rawValue,
                contentDigest: $0.contentDigest
            )
        })
        values.append(contentsOf: snapshot.moduleVersions.map {
            CurriculumCacheDocumentDigestV1(
                kind: .moduleVersion,
                versionID: $0.moduleVersionID.rawValue,
                contentDigest: $0.contentDigest
            )
        })
        values.append(contentsOf: snapshot.lessonVersions.map {
            CurriculumCacheDocumentDigestV1(
                kind: .lessonVersion,
                versionID: $0.lessonVersionID.rawValue,
                contentDigest: $0.contentDigest
            )
        })
        values.append(contentsOf: snapshot.rubricVersions.map {
            CurriculumCacheDocumentDigestV1(
                kind: .rubricVersion,
                versionID: $0.rubricVersionID.rawValue,
                contentDigest: $0.contentDigest
            )
        })
        values.append(contentsOf: snapshot.assetVersions.map {
            CurriculumCacheDocumentDigestV1(
                kind: .assetVersion,
                versionID: $0.assetVersionID.rawValue,
                contentDigest: $0.contentDigest
            )
        })
        return values
    }
}

private struct CurriculumCacheDynamicCodingKey: CodingKey, Hashable {
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

private func exactCacheContainer<Key: CodingKey & CaseIterable>(
    _ keyType: Key.Type,
    from decoder: Decoder
) throws -> KeyedDecodingContainer<Key> {
    let dynamic = try decoder.container(
        keyedBy: CurriculumCacheDynamicCodingKey.self
    )
    let allowed = Set(keyType.allCases.map(\.stringValue))
    if let unknown = dynamic.allKeys.first(where: {
        !allowed.contains($0.stringValue)
    }) {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath + [unknown],
                debugDescription: "Unknown curriculum cache field."
            )
        )
    }
    return try decoder.container(keyedBy: keyType)
}
