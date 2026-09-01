import Foundation

struct OnboardingDraftRepository: Sendable {
    struct State: Codable, Equatable, Sendable {
        let step: OnboardingStep
        let draft: OnboardingDraft
    }

    static let defaultKey = "com.syntholo.onboarding.draft"

    private static let envelopeVersion = 1

    private let operationLock: OperationLock
    private let readData: @Sendable () throws -> Data?
    private let writeData: @Sendable (Data?) throws -> Void

    init(
        readData: @escaping @Sendable () throws -> Data?,
        writeData: @escaping @Sendable (Data?) throws -> Void
    ) {
        operationLock = OperationLock()
        self.readData = readData
        self.writeData = writeData
    }

    func save(step: OnboardingStep, draft: OnboardingDraft) throws {
        try operationLock.withLock {
            let envelope = Envelope(
                version: Self.envelopeVersion,
                step: step,
                draft: draft
            )
            try writeData(try JSONEncoder().encode(envelope))
        }
    }

    func save(_ state: State) throws {
        try save(step: state.step, draft: state.draft)
    }

    func save(_ draft: OnboardingDraft) throws {
        var resumableDraft = draft
        if resumableDraft.path == nil,
           let goal = resumableDraft.goal,
           let experience = resumableDraft.experience {
            resumableDraft.path = PathRecommender.recommend(
                goal: goal,
                experience: experience
            )
        }
        try save(
            step: Self.resumeStep(for: resumableDraft),
            draft: resumableDraft
        )
    }

    func load() throws -> State? {
        try operationLock.withLock {
            guard let data = try readData() else {
                return nil
            }

            guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
                  envelope.version == Self.envelopeVersion else {
                try writeData(nil)
                return nil
            }

            return State(step: envelope.step, draft: envelope.draft)
        }
    }

    func clear() throws {
        try operationLock.withLock {
            try writeData(nil)
        }
    }

    static func memory() -> OnboardingDraftRepository {
        let storage = MemoryStorage()
        return OnboardingDraftRepository(
            readData: { storage.load() },
            writeData: { storage.save($0) }
        )
    }

    static func userDefaults(
        _ userDefaults: UserDefaults = .standard,
        key: String = defaultKey
    ) -> OnboardingDraftRepository {
        let storage = UserDefaultsStorage(userDefaults: userDefaults, key: key)
        return OnboardingDraftRepository(
            readData: { storage.load() },
            writeData: { storage.save($0) }
        )
    }

    #if DEBUG
    func failingFirstLoad() -> OnboardingDraftRepository {
        let failureGate = OneShotPersistenceFailureGate()
        return OnboardingDraftRepository(
            readData: {
                if failureGate.consumeFailure() {
                    throw DebugPersistenceError.scriptedLoadFailure
                }
                return try readData()
            },
            writeData: writeData
        )
    }

    func failingFirstSave() -> OnboardingDraftRepository {
        let failureGate = OneShotPersistenceFailureGate()
        return OnboardingDraftRepository(
            readData: readData,
            writeData: { data in
                if data != nil, failureGate.consumeFailure() {
                    throw DebugPersistenceError.scriptedSaveFailure
                }
                try writeData(data)
            }
        )
    }
    #endif

    private static func resumeStep(for draft: OnboardingDraft) -> OnboardingStep {
        guard draft.ageBand != nil else {
            return .age
        }
        guard draft.goal != nil else {
            return .goal
        }
        guard draft.experience != nil else {
            return .experience
        }
        return .pathRecommendation
    }
}

#if DEBUG
private enum DebugPersistenceError: Error {
    case scriptedLoadFailure
    case scriptedSaveFailure
}

private final class OneShotPersistenceFailureGate: @unchecked Sendable {
    private let lock = NSLock()
    private var shouldFail = true

    func consumeFailure() -> Bool {
        lock.withLock {
            defer { shouldFail = false }
            return shouldFail
        }
    }
}
#endif

private extension OnboardingDraftRepository {
    struct Envelope: Codable {
        let version: Int
        let step: OnboardingStep
        let draft: OnboardingDraft
    }

    final class OperationLock: @unchecked Sendable {
        private let lock = NSLock()

        func withLock<Result>(
            _ operation: () throws -> Result
        ) rethrows -> Result {
            lock.lock()
            defer { lock.unlock() }
            return try operation()
        }
    }

    final class MemoryStorage: @unchecked Sendable {
        private let lock = NSLock()
        private var data: Data?

        func load() -> Data? {
            lock.withLock { data }
        }

        func save(_ data: Data?) {
            lock.withLock {
                self.data = data
            }
        }
    }

    final class UserDefaultsStorage: @unchecked Sendable {
        private let userDefaults: UserDefaults
        private let key: String

        init(userDefaults: UserDefaults, key: String) {
            self.userDefaults = userDefaults
            self.key = key
        }

        func load() -> Data? {
            guard let object = userDefaults.object(forKey: key) else {
                return nil
            }
            guard let data = object as? Data else {
                userDefaults.removeObject(forKey: key)
                return nil
            }
            return data
        }

        func save(_ data: Data?) {
            if let data {
                userDefaults.set(data, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}
