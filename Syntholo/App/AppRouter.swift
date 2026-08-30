import Observation

@MainActor
@Observable
final class AppRouter {
    private(set) var selectedRoute: AppRoute = .learn

    func select(_ route: AppRoute) {
        selectedRoute = route
    }
}
