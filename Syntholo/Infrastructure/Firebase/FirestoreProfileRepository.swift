import Foundation
@preconcurrency import FirebaseFirestore

enum ProfileRepositoryError: Error, Equatable, Sendable {
    case ageBandIsImmutable
    case malformedStoredAgeBand
    case handleAlreadyClaimed
    case handleIsImmutable
    case incompleteProfileDocuments
    case malformedProfileDocuments
    case unsupportedSchemaVersion
    case backendFailure
}

enum ProfileDocumentValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case integer(Int)
    case stringList([String])
    case timestamp(Date)
    case null
    case serverTimestamp
}

typealias ProfileDocument = [String: ProfileDocumentValue]

struct ProfileDocumentWrite: Equatable, Sendable {
    let path: String
    let data: ProfileDocument
    let merge: Bool
}

protocol ProfileDocumentStore: Sendable {
    func read(path: String) async throws -> ProfileDocument?
    func commit(_ writes: [ProfileDocumentWrite]) async throws
}

struct FirestoreProfileRepository: ProfileRepository {
    private let store: any ProfileDocumentStore

    init(firestore: Firestore = .firestore()) {
        store = FirestoreProfileDocumentStore(firestore: firestore)
    }

    init(store: any ProfileDocumentStore) {
        self.store = store
    }

    func save(_ profile: LearnerProfile) async throws {
        do {
            try await saveChecked(profile)
        } catch let error as ProfileRepositoryError {
            throw error
        } catch {
            throw ProfileRepositoryError.backendFailure
        }
    }

    func load(userID: String) async throws -> LearnerProfile? {
        do {
            return try await loadChecked(userID: userID)
        } catch let error as ProfileRepositoryError {
            throw error
        } catch {
            throw ProfileRepositoryError.backendFailure
        }
    }

    private func saveChecked(_ profile: LearnerProfile) async throws {
        let userPath = Self.userPath(profile.userID)
        let existingUser = try await store.read(path: userPath)
        let isInitialCreation = existingUser == nil

        if let existingUser {
            guard case let .string(ageValue)? = existingUser["ageBand"],
                  let storedAgeBand = AgeBand(rawValue: ageValue) else {
                throw ProfileRepositoryError.malformedStoredAgeBand
            }
            guard storedAgeBand == profile.ageBand else {
                throw ProfileRepositoryError.ageBandIsImmutable
            }

            let existingPreferences = try await store.read(
                path: Self.preferencesPath(profile.userID)
            )
            let existingPublicProfile = try await store.read(
                path: Self.publicProfilePath(profile.userID)
            )
            guard let existingPreferences,
                  let existingPublicProfile else {
                throw ProfileRepositoryError.incompleteProfileDocuments
            }
            guard case let .string(storedHandle)? = existingPublicProfile["handle"] else {
                throw ProfileRepositoryError.malformedProfileDocuments
            }
            guard storedHandle == profile.handle else {
                throw ProfileRepositoryError.handleIsImmutable
            }
            let existingClaim = try await store.read(
                path: Self.claimPath(storedHandle)
            )
            let existingDirectory = try await store.read(
                path: Self.directoryPath(storedHandle)
            )
            guard let existingClaim,
                  let existingDirectory else {
                throw ProfileRepositoryError.incompleteProfileDocuments
            }
            _ = try Self.decode(
                userID: profile.userID,
                user: existingUser,
                preferences: existingPreferences,
                publicProfile: existingPublicProfile,
                claim: existingClaim,
                directory: existingDirectory
            )
        } else if try await store.read(
            path: Self.directoryPath(profile.handle)
        ) != nil {
            throw ProfileRepositoryError.handleAlreadyClaimed
        }

        try await store.commit(
            Self.writes(for: profile, isInitialCreation: isInitialCreation)
        )
    }

    private func loadChecked(userID: String) async throws -> LearnerProfile? {
        guard let user = try await store.read(path: Self.userPath(userID)) else {
            return nil
        }
        guard let preferences = try await store.read(
            path: Self.preferencesPath(userID)
        ), let publicProfile = try await store.read(
            path: Self.publicProfilePath(userID)
        ) else {
            throw ProfileRepositoryError.incompleteProfileDocuments
        }
        guard case let .string(handle)? = publicProfile["handle"] else {
            throw ProfileRepositoryError.malformedProfileDocuments
        }
        guard let claim = try await store.read(path: Self.claimPath(handle)),
              let directory = try await store.read(path: Self.directoryPath(handle)) else {
            throw ProfileRepositoryError.incompleteProfileDocuments
        }
        return try Self.decode(
            userID: userID,
            user: user,
            preferences: preferences,
            publicProfile: publicProfile,
            claim: claim,
            directory: directory
        )
    }

    private static func writes(
        for profile: LearnerProfile,
        isInitialCreation: Bool
    ) -> [ProfileDocumentWrite] {
        var user: ProfileDocument = [
            "userID": .string(profile.userID),
            "email": profile.email.map(ProfileDocumentValue.string) ?? .null,
            "displayName": profile.displayName.map(ProfileDocumentValue.string) ?? .null,
            "schemaVersion": .integer(LearnerProfile.currentSchemaVersion),
            "updatedAt": .serverTimestamp,
        ]
        var preferences: ProfileDocument = [
            "userID": .string(profile.userID),
            "goal": .string(profile.goal.rawValue),
            "experience": .string(profile.experience.rawValue),
            "selectedPath": .string(profile.selectedPath.rawValue),
            "coachMode": .string(profile.coachMode.rawValue),
            "enrolledProgramIDs": .stringList(profile.enrolledProgramIDs),
            "schemaVersion": .integer(LearnerProfile.currentSchemaVersion),
            "updatedAt": .serverTimestamp,
        ]
        if isInitialCreation {
            user["ageBand"] = .string(profile.ageBand.rawValue)
            user["createdAt"] = .serverTimestamp
            preferences["createdAt"] = .serverTimestamp
        }
        let isDiscoverable = isInitialCreation ? false : profile.isDiscoverable
        let publicData: ProfileDocument = [
            "handle": .string(profile.handle),
            "isDiscoverable": .bool(isDiscoverable),
        ]

        return [
            ProfileDocumentWrite(
                path: userPath(profile.userID),
                data: user,
                merge: true
            ),
            ProfileDocumentWrite(
                path: preferencesPath(profile.userID),
                data: preferences,
                merge: true
            ),
            ProfileDocumentWrite(
                path: publicProfilePath(profile.userID),
                data: publicData,
                merge: true
            ),
            ProfileDocumentWrite(
                path: claimPath(profile.handle),
                data: [
                    "handle": .string(profile.handle),
                    "ownerUID": .string(profile.userID),
                ],
                merge: true
            ),
            ProfileDocumentWrite(
                path: directoryPath(profile.handle),
                data: publicData,
                merge: true
            ),
        ]
    }

    private static func decode(
        userID: String,
        user: ProfileDocument,
        preferences: ProfileDocument,
        publicProfile: ProfileDocument,
        claim: ProfileDocument,
        directory: ProfileDocument
    ) throws -> LearnerProfile {
        guard case let .string(storedUserID)? = user["userID"],
              case let .string(preferencesUserID)? = preferences["userID"],
              storedUserID == userID,
              preferencesUserID == userID else {
            throw ProfileRepositoryError.malformedProfileDocuments
        }
        guard case let .integer(userSchema)? = user["schemaVersion"],
              case let .integer(preferencesSchema)? = preferences["schemaVersion"] else {
            throw ProfileRepositoryError.malformedProfileDocuments
        }
        guard userSchema == LearnerProfile.currentSchemaVersion,
              preferencesSchema == LearnerProfile.currentSchemaVersion else {
            throw ProfileRepositoryError.unsupportedSchemaVersion
        }
        guard case let .string(ageValue)? = user["ageBand"],
              let ageBand = AgeBand(rawValue: ageValue) else {
            throw ProfileRepositoryError.malformedStoredAgeBand
        }
        guard case let .string(goalValue)? = preferences["goal"],
              let goal = LearnerGoal(rawValue: goalValue),
              case let .string(experienceValue)? = preferences["experience"],
              let experience = ExperienceLevel(rawValue: experienceValue),
              case let .string(pathValue)? = preferences["selectedPath"],
              let selectedPath = LearningPath(rawValue: pathValue),
              case let .string(coachValue)? = preferences["coachMode"],
              let coachMode = CoachMode(rawValue: coachValue),
              case let .stringList(programIDs)? = preferences["enrolledProgramIDs"],
              programIDs == [
                LearnerProfile.foundationsProgramID,
                LearnerProfile.specializationProgramID(for: selectedPath),
              ],
              case let .timestamp(createdAt)? = user["createdAt"],
              case let .timestamp(updatedAt)? = user["updatedAt"],
              case .timestamp? = preferences["createdAt"],
              case .timestamp? = preferences["updatedAt"],
              case let .string(handle)? = publicProfile["handle"],
              case let .bool(isDiscoverable)? = publicProfile["isDiscoverable"],
              case let .string(claimHandle)? = claim["handle"],
              case let .string(claimOwnerUID)? = claim["ownerUID"],
              case let .string(directoryHandle)? = directory["handle"],
              case let .bool(directoryDiscoverable)? = directory["isDiscoverable"],
              handle == claimHandle,
              handle == directoryHandle,
              claimOwnerUID == userID,
              directoryDiscoverable == isDiscoverable else {
            throw ProfileRepositoryError.malformedProfileDocuments
        }

        return LearnerProfile(
            userID: userID,
            email: optionalString(user["email"]),
            displayName: optionalString(user["displayName"]),
            ageBand: ageBand,
            goal: goal,
            experience: experience,
            selectedPath: selectedPath,
            coachMode: coachMode,
            enrolledProgramIDs: programIDs,
            handle: handle,
            isDiscoverable: isDiscoverable,
            schemaVersion: userSchema,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func optionalString(_ value: ProfileDocumentValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

    private static func userPath(_ userID: String) -> String {
        "users/\(userID)"
    }

    private static func preferencesPath(_ userID: String) -> String {
        "preferences/\(userID)"
    }

    private static func publicProfilePath(_ userID: String) -> String {
        "publicProfiles/\(userID)"
    }

    private static func claimPath(_ handle: String) -> String {
        "profileHandleClaims/\(handle)"
    }

    private static func directoryPath(_ handle: String) -> String {
        "publicProfileDirectory/\(handle)"
    }
}

private enum FirestoreProfileDocumentStoreError: Error {
    case unsupportedValue
}

private final class FirestoreProfileDocumentStore: ProfileDocumentStore,
    @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func read(path: String) async throws -> ProfileDocument? {
        let snapshot = try await firestore.document(path).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        return try data.mapValues(Self.decode)
    }

    func commit(_ writes: [ProfileDocumentWrite]) async throws {
        let batch = firestore.batch()
        for write in writes {
            let data = write.data.mapValues(Self.encode)
            batch.setData(
                data,
                forDocument: firestore.document(write.path),
                merge: write.merge
            )
        }
        try await batch.commit()
    }

    private static func decode(_ value: Any) throws -> ProfileDocumentValue {
        if value is NSNull {
            return .null
        }
        if let value = value as? Bool {
            return .bool(value)
        }
        if let value = value as? String {
            return .string(value)
        }
        if let value = value as? [String] {
            return .stringList(value)
        }
        if let value = value as? Timestamp {
            return .timestamp(value.dateValue())
        }
        if let value = value as? NSNumber {
            return .integer(value.intValue)
        }
        throw FirestoreProfileDocumentStoreError.unsupportedValue
    }

    private static func encode(_ value: ProfileDocumentValue) -> Any {
        switch value {
        case let .string(value):
            value
        case let .bool(value):
            value
        case let .integer(value):
            value
        case let .stringList(value):
            value
        case let .timestamp(value):
            Timestamp(date: value)
        case .null:
            NSNull()
        case .serverTimestamp:
            FieldValue.serverTimestamp()
        }
    }
}
