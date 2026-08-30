protocol ProfileRepository: Sendable {
    func save(_ profile: LearnerProfile) async throws
    func load(userID: String) async throws -> LearnerProfile?
}
