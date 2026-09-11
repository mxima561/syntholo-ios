import Observation

@MainActor
@Observable
final class AppRouter {
    private(set) var selectedRoute: AppRoute = .learn
    var learnPath: [LearnRoute] = []

    func select(_ route: AppRoute) {
        selectedRoute = route
    }

    func presentFirstLesson(_ reference: LessonVersionReference) {
        selectedRoute = .learn
        learnPath = [.lesson(reference)]
    }

    func showLearnHome() {
        selectedRoute = .learn
        learnPath.removeAll(keepingCapacity: true)
    }
}
