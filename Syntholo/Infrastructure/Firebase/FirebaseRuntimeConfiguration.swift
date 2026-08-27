import Foundation
@preconcurrency import FirebaseCore

struct FirebaseRuntimeConfiguration: Sendable, Equatable {
    let environment: AppEnvironment
    let projectID: String?
    let useEmulators: Bool
    let isConfigured: Bool

    private let options: FirebaseOptions?

    init(
        environment: AppEnvironment,
        options: FirebaseOptions?,
        useEmulators: Bool
    ) {
        self.environment = environment
        self.projectID = options?.projectID
        self.useEmulators = useEmulators
        self.isConfigured = options != nil
        self.options = options
    }

    private init(
        environment: AppEnvironment,
        projectID: String?,
        useEmulators: Bool,
        isConfigured: Bool
    ) {
        self.environment = environment
        self.projectID = projectID
        self.useEmulators = useEmulators
        self.isConfigured = isConfigured
        self.options = nil
    }

    static let emulator = FirebaseRuntimeConfiguration(
        environment: .development,
        projectID: "syntholo-local",
        useEmulators: true,
        isConfigured: true
    )

    static var current: FirebaseRuntimeConfiguration {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("--ui-testing")
            || processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .emulator
        }

        let environment = AppEnvironment.current
        let resourceName = "\(environment.rawValue).firebase"
        guard let path = Bundle.main.path(
            forResource: resourceName,
            ofType: "plist"
        ) else {
            return FirebaseRuntimeConfiguration(
                environment: environment,
                options: nil,
                useEmulators: false
            )
        }

        return FirebaseRuntimeConfiguration(
            environment: environment,
            options: FirebaseOptions(contentsOfFile: path),
            useEmulators: false
        )
    }

    static func == (
        lhs: FirebaseRuntimeConfiguration,
        rhs: FirebaseRuntimeConfiguration
    ) -> Bool {
        lhs.environment == rhs.environment
            && lhs.projectID == rhs.projectID
            && lhs.useEmulators == rhs.useEmulators
            && lhs.isConfigured == rhs.isConfigured
    }

    var firebaseOptions: FirebaseOptions? {
        options
    }
}
