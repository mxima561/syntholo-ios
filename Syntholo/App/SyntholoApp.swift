import SwiftUI

@main
struct SyntholoApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
        }
    }
}
