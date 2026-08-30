import Foundation

enum SyntholoRootPresentation: Equatable {
    case application
    case configurationRequired

    init(isFirebaseConfigured: Bool) {
        self = isFirebaseConfigured ? .application : .configurationRequired
    }
}

@MainActor
struct SyntholoLaunchComposition {
    let rootPresentation: SyntholoRootPresentation
    let dependencies: AppDependencies

    #if DEBUG
    static func make(
        arguments: [String],
        readFirebaseConfiguration: () -> FirebaseRuntimeConfiguration = {
            FirebaseRuntimeConfiguration.current
        },
        configureFirebase: (
            FirebaseRuntimeConfiguration,
            [String]
        ) -> Bool = { configuration, arguments in
            FirebaseBootstrap.configure(
                configuration,
                arguments: arguments
            )
        },
        makeUITestingDependencies: ([String]) -> AppDependencies = {
            AppDependencies.makeUITesting(arguments: $0)
        },
        makeLiveDependencies: (
            FirebaseRuntimeConfiguration,
            Bool
        ) -> AppDependencies = { configuration, isFirebaseConfigured in
            AppDependencies.makeLive(
                configuration: configuration,
                isFirebaseConfigured: isFirebaseConfigured
            )
        }
    ) -> SyntholoLaunchComposition {
        if arguments.contains("--ui-testing") {
            return SyntholoLaunchComposition(
                rootPresentation: .application,
                dependencies: makeUITestingDependencies(arguments)
            )
        }

        let configuration = readFirebaseConfiguration()
        let isFirebaseConfigured = configureFirebase(
            configuration,
            arguments
        )
        return SyntholoLaunchComposition(
            rootPresentation: SyntholoRootPresentation(
                isFirebaseConfigured: isFirebaseConfigured
            ),
            dependencies: makeLiveDependencies(
                configuration,
                isFirebaseConfigured
            )
        )
    }
    #else
    static func make(arguments: [String]) -> SyntholoLaunchComposition {
        return makeFirebaseBacked(arguments: arguments)
    }
    #endif

    private static func makeFirebaseBacked(
        arguments: [String]
    ) -> SyntholoLaunchComposition {
        let configuration = FirebaseRuntimeConfiguration.current
        let isFirebaseConfigured = FirebaseBootstrap.configure(
            configuration,
            arguments: arguments
        )
        return SyntholoLaunchComposition(
            rootPresentation: SyntholoRootPresentation(
                isFirebaseConfigured: isFirebaseConfigured
            ),
            dependencies: AppDependencies.makeLive(
                configuration: configuration,
                isFirebaseConfigured: isFirebaseConfigured
            )
        )
    }
}
