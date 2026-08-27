import Foundation
@preconcurrency import FirebaseFirestore

enum ProfileRepositoryError: Error, Equatable, Sendable {
    case ageBandIsImmutable
    case incompleteProfileDocuments
    case unsupportedSchemaVersion
}

struct FirestoreProfileRepository: ProfileRepository {
    private let backend: FirestoreProfileBackend

    init(firestore: Firestore = .firestore()) {
        backend = FirestoreProfileBackend(firestore: firestore)
    }

    func save(_ profile: LearnerProfile) async throws {
        try await backend.save(profile)
    }

    func load(userID: String) async throws -> LearnerProfile? {
        try await backend.load(userID: userID)
    }
}

private final class FirestoreProfileBackend: @unchecked Sendable {
    private let firestore: Firestore

    init(firestore: Firestore) {
        self.firestore = firestore
    }

    func save(_ profile: LearnerProfile) async throws {
        let userReference = firestore.collection("users").document(profile.userID)
        let preferencesReference = firestore
            .collection("preferences")
            .document(profile.userID)
        let publicProfileReference = firestore
            .collection("publicProfiles")
            .document(profile.userID)

        let existingUser = try await userReference.getDocument()
        if existingUser.exists {
            guard existingUser.data()?["ageBand"] as? String
                == profile.ageBand.rawValue else {
                throw ProfileRepositoryError.ageBandIsImmutable
            }
        }

        let isInitialCreation = !existingUser.exists
        let serverTimestamp = FieldValue.serverTimestamp()
        var userData: [String: Any] = [
            "userID": profile.userID,
            "email": profile.email ?? NSNull(),
            "displayName": profile.displayName ?? NSNull(),
            "schemaVersion": LearnerProfile.currentSchemaVersion,
            "updatedAt": serverTimestamp,
        ]
        var preferencesData: [String: Any] = [
            "userID": profile.userID,
            "goal": profile.goal.rawValue,
            "experience": profile.experience.rawValue,
            "selectedPath": profile.selectedPath.rawValue,
            "coachMode": profile.coachMode.rawValue,
            "enrolledProgramIDs": profile.enrolledProgramIDs,
            "schemaVersion": LearnerProfile.currentSchemaVersion,
            "updatedAt": serverTimestamp,
        ]

        if isInitialCreation {
            userData["ageBand"] = profile.ageBand.rawValue
            userData["createdAt"] = serverTimestamp
            preferencesData["createdAt"] = serverTimestamp
        }

        let batch = firestore.batch()
        batch.setData(userData, forDocument: userReference, merge: true)
        batch.setData(
            preferencesData,
            forDocument: preferencesReference,
            merge: true
        )
        batch.setData(
            [
                "handle": profile.handle,
                "isDiscoverable": isInitialCreation
                    ? false
                    : profile.isDiscoverable,
            ],
            forDocument: publicProfileReference,
            merge: true
        )
        try await batch.commit()
    }

    func load(userID: String) async throws -> LearnerProfile? {
        let userSnapshot = try await firestore
            .collection("users")
            .document(userID)
            .getDocument()
        guard userSnapshot.exists else {
            return nil
        }

        let preferencesSnapshot = try await firestore
            .collection("preferences")
            .document(userID)
            .getDocument()
        let publicProfileSnapshot = try await firestore
            .collection("publicProfiles")
            .document(userID)
            .getDocument()

        guard let userData = userSnapshot.data(),
              let preferencesData = preferencesSnapshot.data(),
              let publicProfileData = publicProfileSnapshot.data(),
              userData["userID"] as? String == userID,
              preferencesData["userID"] as? String == userID,
              let userSchemaVersion = integer(userData["schemaVersion"]),
              let preferencesSchemaVersion = integer(
                preferencesData["schemaVersion"]
              ) else {
            throw ProfileRepositoryError.incompleteProfileDocuments
        }

        guard userSchemaVersion == LearnerProfile.currentSchemaVersion,
              preferencesSchemaVersion == LearnerProfile.currentSchemaVersion else {
            throw ProfileRepositoryError.unsupportedSchemaVersion
        }

        guard let ageBandValue = userData["ageBand"] as? String,
              let ageBand = AgeBand(rawValue: ageBandValue),
              let goalValue = preferencesData["goal"] as? String,
              let goal = LearnerGoal(rawValue: goalValue),
              let experienceValue = preferencesData["experience"] as? String,
              let experience = ExperienceLevel(rawValue: experienceValue),
              let selectedPathValue = preferencesData["selectedPath"] as? String,
              let selectedPath = LearningPath(rawValue: selectedPathValue),
              let coachModeValue = preferencesData["coachMode"] as? String,
              let coachMode = CoachMode(rawValue: coachModeValue),
              let enrolledProgramIDs = preferencesData["enrolledProgramIDs"]
                as? [String],
              enrolledProgramIDs == [
                LearnerProfile.foundationsProgramID,
                LearnerProfile.specializationProgramID(for: selectedPath),
              ],
              let handle = publicProfileData["handle"] as? String,
              let isDiscoverable = publicProfileData["isDiscoverable"] as? Bool,
              let createdAt = timestampDate(userData["createdAt"]),
              let updatedAt = timestampDate(userData["updatedAt"]) else {
            throw ProfileRepositoryError.incompleteProfileDocuments
        }

        return LearnerProfile(
            userID: userID,
            email: userData["email"] as? String,
            displayName: userData["displayName"] as? String,
            ageBand: ageBand,
            goal: goal,
            experience: experience,
            selectedPath: selectedPath,
            coachMode: coachMode,
            enrolledProgramIDs: enrolledProgramIDs,
            handle: handle,
            isDiscoverable: isDiscoverable,
            schemaVersion: userSchemaVersion,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func timestampDate(_ value: Any?) -> Date? {
        (value as? Timestamp)?.dateValue()
    }
}
