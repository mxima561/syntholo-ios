import Foundation

struct OnboardingDraftRepository: Sendable {
    struct State: Codable, Equatable, Sendable {
        let step: OnboardingStep
        let draft: OnboardingDraft
    }

    static let defaultKey = "com.syntholo.onboarding.draft"

    private static let envelopeVersion = 1

    private let readData: @Sendable () -> Data?
    private let writeData: @Sendable (Data?) -> Void

    private init(
        readData: @escaping @Sendable () -> Data?,
        writeData: @escaping @Sendable (Data?) -> Void
    ) {
        self.readData = readData
        self.writeData = writeData
    }

    func save(step: OnboardingStep, draft: OnboardingDraft) throws {
        let envelope = Envelope(
            version: Self.envelopeVersion,
            step: step,
            draft: draft
        )
        writeData(try JSONEncoder().encode(envelope))
    }

    func save(_ state: State) throws {
        try save(step: state.step, draft: state.draft)
    }

    func save(_ draft: OnboardingDraft) throws {
        try save(step: Self.resumeStep(for: draft), draft: draft)
    }

    func load() throws -> State? {
        guard let data = readData() else {
            return nil
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == Self.envelopeVersion else {
            writeData(nil)
            return nil
        }

        return State(step: envelope.step, draft: envelope.draft)
    }

    func clear() throws {
        writeData(nil)
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

private extension OnboardingDraftRepository {
    struct Envelope: Codable {
        let version: Int
        let step: OnboardingStep
        let draft: OnboardingDraft
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
