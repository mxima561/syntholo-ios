import Observation

enum AppSessionState: Equatable {
    case loading
    case signedOut
    case onboarding
    case accountPendingProfile(userID: String)
    case firstLessonHandoff
    case signedIn
    case configurationRequired
}

@MainActor
@Observable
final class AppSession {
    private(set) var state: AppSessionState

    init(configurationAvailable: Bool) {
        state = configurationAvailable ? .loading : .configurationRequired
    }

    func transition(to state: AppSessionState) {
        self.state = state
    }
}
