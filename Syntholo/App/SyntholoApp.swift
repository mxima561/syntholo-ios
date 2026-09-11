import SwiftUI

@main
struct SyntholoApp: App {
    @State private var dependencies: AppDependencies
    private let rootPresentation: SyntholoRootPresentation
    #if DEBUG
    private let usesMaximumUITestDynamicType: Bool
    #endif

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let composition = SyntholoLaunchComposition.make(
            arguments: arguments
        )
        rootPresentation = composition.rootPresentation
        _dependencies = State(
            initialValue: composition.dependencies
        )
        #if DEBUG
        usesMaximumUITestDynamicType = arguments.contains("--ui-testing")
            && arguments.contains("--dynamic-type-size=accessibility5")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .onOpenURL { url in
                    _ = GoogleSignInCoordinator.handle(url)
                }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if usesMaximumUITestDynamicType {
            RootView(dependencies: dependencies)
                .dynamicTypeSize(.accessibility5)
        } else {
            RootView(dependencies: dependencies)
        }
        #else
        RootView(dependencies: dependencies)
        #endif
    }
}
