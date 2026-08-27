import Foundation
import XCTest
@testable import Syntholo

final class ProfileRepositoryContractTests: XCTestCase {
    private let serverDate = Date(timeIntervalSince1970: 1_900_000_000)

    func testInitialSaveCommitsTheCompleteFiveDocumentProfileAtomically() async throws {
        let store = RecordingProfileDocumentStore(serverDate: serverDate)
        let repository = FirestoreProfileRepository(store: store)
        let profile = makeProfile()

        try await repository.save(profile)

        let batches = await store.committedBatches
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0], expectedInitialWrites(for: profile))
        XCTAssertEqual(
            Set(batches[0].map(\.path)),
            [
                "users/firebase-user-123",
                "preferences/firebase-user-123",
                "publicProfiles/firebase-user-123",
                "profileHandleClaims/\(profile.handle)",
                "publicProfileDirectory/\(profile.handle)",
            ]
        )
        XCTAssertEqual(
            Set(batches[0].first { $0.path.hasPrefix("publicProfiles/") }!.data.keys),
            ["handle", "isDiscoverable"]
        )
        XCTAssertEqual(
            Set(batches[0].first { $0.path.hasPrefix("publicProfileDirectory/") }!.data.keys),
            ["handle", "isDiscoverable"]
        )
    }

    func testInitialSaveUsesPublicDirectoryPreflightWithoutReadingPrivateClaim() async throws {
        let store = RecordingProfileDocumentStore(serverDate: serverDate)
        let repository = FirestoreProfileRepository(store: store)
        let profile = makeProfile()

        try await repository.save(profile)

        let readPaths = await store.readPaths
        XCTAssertEqual(
            readPaths,
            [
                "users/\(profile.userID)",
                "publicProfileDirectory/\(profile.handle)",
            ]
        )
        XCTAssertFalse(readPaths.contains("profileHandleClaims/\(profile.handle)"))
    }

    func testSaveThenLoadDecodesTheCompleteStoredProfile() async throws {
        let store = RecordingProfileDocumentStore(serverDate: serverDate)
        let repository = FirestoreProfileRepository(store: store)
        let profile = makeProfile()

        try await repository.save(profile)
        let loaded = try await repository.load(userID: profile.userID)

        XCTAssertEqual(
            loaded,
            replacingDates(in: profile, createdAt: serverDate, updatedAt: serverDate)
        )
    }

    func testSavePreflightRejectsAnAgeBandChangeWithoutWriting() async throws {
        let adult = makeProfile(ageBand: .adult)
        let store = RecordingProfileDocumentStore(
            documents: storedDocuments(for: adult, date: serverDate),
            serverDate: serverDate
        )
        let repository = FirestoreProfileRepository(store: store)

        await assertProfileError(.ageBandIsImmutable) {
            try await repository.save(self.makeProfile(ageBand: .teen))
        }

        let batches = await store.committedBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func testSavePreflightDistinguishesMissingStoredAgeFromAnImmutableConflict() async throws {
        let profile = makeProfile()
        var documents = storedDocuments(for: profile, date: serverDate)
        documents["users/\(profile.userID)"]?.removeValue(forKey: "ageBand")
        let store = RecordingProfileDocumentStore(
            documents: documents,
            serverDate: serverDate
        )
        let repository = FirestoreProfileRepository(store: store)

        await assertProfileError(.malformedStoredAgeBand) {
            try await repository.save(profile)
        }

        let batches = await store.committedBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func testInitialSaveRejectsAnOccupiedHiddenPublicDirectory() async throws {
        let profile = makeProfile()
        let store = RecordingProfileDocumentStore(
            documents: [
                "publicProfileDirectory/\(profile.handle)": [
                    "handle": .string(profile.handle),
                    "isDiscoverable": .bool(false),
                ],
            ],
            serverDate: serverDate
        )
        let repository = FirestoreProfileRepository(store: store)

        await assertProfileError(.handleAlreadyClaimed) {
            try await repository.save(profile)
        }

        let batches = await store.committedBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func testRetryUsesACompleteAdapterShapedBatchAndPreservesCreatedAt() async throws {
        let store = RecordingProfileDocumentStore(serverDate: serverDate)
        let repository = FirestoreProfileRepository(store: store)
        let profile = makeProfile()

        try await repository.save(profile)
        try await repository.save(profile)

        let batches = await store.committedBatches
        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(batches[1].count, 5)
        let retryUser = try XCTUnwrap(
            batches[1].first { $0.path == "users/\(profile.userID)" }
        )
        let retryPreferences = try XCTUnwrap(
            batches[1].first { $0.path == "preferences/\(profile.userID)" }
        )
        XCTAssertNil(retryUser.data["ageBand"])
        XCTAssertNil(retryUser.data["createdAt"])
        XCTAssertNil(retryPreferences.data["createdAt"])
        XCTAssertEqual(retryUser.data["updatedAt"], .serverTimestamp)
        XCTAssertEqual(retryPreferences.data["updatedAt"], .serverTimestamp)
        XCTAssertEqual(
            batches[1].first { $0.path.hasPrefix("profileHandleClaims/") }?.data,
            [
                "handle": .string(profile.handle),
                "ownerUID": .string(profile.userID),
            ]
        )

        let loaded = try await repository.load(userID: profile.userID)
        let documentCount = await store.documentCount
        XCTAssertEqual(loaded?.createdAt, serverDate)
        XCTAssertEqual(documentCount, 5)
    }

    func testLoadDistinguishesIncompleteMalformedAndUnsupportedDocuments() async throws {
        let profile = makeProfile()

        var incomplete = storedDocuments(for: profile, date: serverDate)
        incomplete.removeValue(forKey: "publicProfileDirectory/\(profile.handle)")
        await assertLoadError(
            .incompleteProfileDocuments,
            documents: incomplete,
            userID: profile.userID
        )

        var malformed = storedDocuments(for: profile, date: serverDate)
        malformed["preferences/\(profile.userID)"]?["goal"] = .string("invalid")
        await assertLoadError(
            .malformedProfileDocuments,
            documents: malformed,
            userID: profile.userID
        )

        var unsupported = storedDocuments(for: profile, date: serverDate)
        unsupported["users/\(profile.userID)"]?["schemaVersion"] = .integer(2)
        await assertLoadError(
            .unsupportedSchemaVersion,
            documents: unsupported,
            userID: profile.userID
        )
    }

    func testLoadReturnsNilOnlyWhenThePrivateUserDocumentDoesNotExist() async throws {
        let repository = FirestoreProfileRepository(
            store: RecordingProfileDocumentStore(serverDate: serverDate)
        )

        let loaded = try await repository.load(userID: "missing-user")

        XCTAssertNil(loaded)
    }

    func testBackendReadAndCommitErrorsMapToTheTypedRepositoryError() async throws {
        let profile = makeProfile()
        let readFailureStore = RecordingProfileDocumentStore(
            serverDate: serverDate,
            failure: .read
        )
        let commitFailureStore = RecordingProfileDocumentStore(
            serverDate: serverDate,
            failure: .commit
        )

        await assertProfileError(.backendFailure) {
            _ = try await FirestoreProfileRepository(store: readFailureStore)
                .load(userID: profile.userID)
        }
        await assertProfileError(.backendFailure) {
            try await FirestoreProfileRepository(store: commitFailureStore)
                .save(profile)
        }
    }

    private func assertLoadError(
        _ expected: ProfileRepositoryError,
        documents: [String: ProfileDocument],
        userID: String
    ) async {
        let repository = FirestoreProfileRepository(
            store: RecordingProfileDocumentStore(
                documents: documents,
                serverDate: serverDate
            )
        )
        await assertProfileError(expected) {
            _ = try await repository.load(userID: userID)
        }
    }

    private func assertProfileError(
        _ expected: ProfileRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as ProfileRepositoryError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Expected ProfileRepositoryError, received \(error)")
        }
    }

    private func makeProfile(ageBand: AgeBand = .teen) -> LearnerProfile {
        LearnerProfile.make(
            user: AuthenticatedUser(
                id: "firebase-user-123",
                email: "learner@example.com",
                displayName: "Taylor Learner"
            ),
            draft: OnboardingDraft(
                ageBand: ageBand,
                goal: .buildWithAI,
                experience: .advanced,
                path: .build,
                coachMode: .strict
            ),
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func expectedInitialWrites(
        for profile: LearnerProfile
    ) -> [ProfileDocumentWrite] {
        [
            ProfileDocumentWrite(
                path: "users/\(profile.userID)",
                data: [
                    "userID": .string(profile.userID),
                    "email": .string("learner@example.com"),
                    "displayName": .string("Taylor Learner"),
                    "ageBand": .string(profile.ageBand.rawValue),
                    "schemaVersion": .integer(1),
                    "createdAt": .serverTimestamp,
                    "updatedAt": .serverTimestamp,
                ],
                merge: true
            ),
            ProfileDocumentWrite(
                path: "preferences/\(profile.userID)",
                data: [
                    "userID": .string(profile.userID),
                    "goal": .string("buildWithAI"),
                    "experience": .string("advanced"),
                    "selectedPath": .string("build"),
                    "coachMode": .string("strict"),
                    "enrolledProgramIDs": .stringList(["ai-foundations", "ai-build"]),
                    "schemaVersion": .integer(1),
                    "createdAt": .serverTimestamp,
                    "updatedAt": .serverTimestamp,
                ],
                merge: true
            ),
            ProfileDocumentWrite(
                path: "publicProfiles/\(profile.userID)",
                data: [
                    "handle": .string(profile.handle),
                    "isDiscoverable": .bool(false),
                ],
                merge: true
            ),
            ProfileDocumentWrite(
                path: "profileHandleClaims/\(profile.handle)",
                data: [
                    "handle": .string(profile.handle),
                    "ownerUID": .string(profile.userID),
                ],
                merge: true
            ),
            ProfileDocumentWrite(
                path: "publicProfileDirectory/\(profile.handle)",
                data: [
                    "handle": .string(profile.handle),
                    "isDiscoverable": .bool(false),
                ],
                merge: true
            ),
        ]
    }

    private func storedDocuments(
        for profile: LearnerProfile,
        date: Date
    ) -> [String: ProfileDocument] {
        let timestamp: ProfileDocumentValue = .timestamp(date)
        return [
            "users/\(profile.userID)": [
                "userID": .string(profile.userID),
                "email": profile.email.map(ProfileDocumentValue.string) ?? .null,
                "displayName": profile.displayName.map(ProfileDocumentValue.string) ?? .null,
                "ageBand": .string(profile.ageBand.rawValue),
                "schemaVersion": .integer(1),
                "createdAt": timestamp,
                "updatedAt": timestamp,
            ],
            "preferences/\(profile.userID)": [
                "userID": .string(profile.userID),
                "goal": .string(profile.goal.rawValue),
                "experience": .string(profile.experience.rawValue),
                "selectedPath": .string(profile.selectedPath.rawValue),
                "coachMode": .string(profile.coachMode.rawValue),
                "enrolledProgramIDs": .stringList(profile.enrolledProgramIDs),
                "schemaVersion": .integer(1),
                "createdAt": timestamp,
                "updatedAt": timestamp,
            ],
            "publicProfiles/\(profile.userID)": [
                "handle": .string(profile.handle),
                "isDiscoverable": .bool(profile.isDiscoverable),
            ],
            "profileHandleClaims/\(profile.handle)": [
                "handle": .string(profile.handle),
                "ownerUID": .string(profile.userID),
            ],
            "publicProfileDirectory/\(profile.handle)": [
                "handle": .string(profile.handle),
                "isDiscoverable": .bool(profile.isDiscoverable),
            ],
        ]
    }

    private func replacingDates(
        in profile: LearnerProfile,
        createdAt: Date,
        updatedAt: Date
    ) -> LearnerProfile {
        LearnerProfile(
            userID: profile.userID,
            email: profile.email,
            displayName: profile.displayName,
            ageBand: profile.ageBand,
            goal: profile.goal,
            experience: profile.experience,
            selectedPath: profile.selectedPath,
            coachMode: profile.coachMode,
            enrolledProgramIDs: profile.enrolledProgramIDs,
            handle: profile.handle,
            isDiscoverable: profile.isDiscoverable,
            schemaVersion: profile.schemaVersion,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private actor RecordingProfileDocumentStore: ProfileDocumentStore {
    enum Failure {
        case read
        case commit
    }

    enum StubError: Error {
        case requestedFailure
        case privateClaimPermissionDenied
    }

    private var documents: [String: ProfileDocument]
    private(set) var committedBatches: [[ProfileDocumentWrite]] = []
    private(set) var readPaths: [String] = []
    private let serverDate: Date
    private let failure: Failure?

    init(
        documents: [String: ProfileDocument] = [:],
        serverDate: Date,
        failure: Failure? = nil
    ) {
        self.documents = documents
        self.serverDate = serverDate
        self.failure = failure
    }

    var documentCount: Int {
        documents.count
    }

    func read(path: String) async throws -> ProfileDocument? {
        if failure == .read {
            throw StubError.requestedFailure
        }
        readPaths.append(path)
        if path.hasPrefix("profileHandleClaims/"), documents[path] == nil {
            throw StubError.privateClaimPermissionDenied
        }
        return documents[path]
    }

    func commit(_ writes: [ProfileDocumentWrite]) async throws {
        if failure == .commit {
            throw StubError.requestedFailure
        }
        committedBatches.append(writes)
        for write in writes {
            var result = write.merge ? documents[write.path] ?? [:] : [:]
            for (key, value) in write.data {
                result[key] = value == .serverTimestamp ? .timestamp(serverDate) : value
            }
            documents[write.path] = result
        }
    }
}
