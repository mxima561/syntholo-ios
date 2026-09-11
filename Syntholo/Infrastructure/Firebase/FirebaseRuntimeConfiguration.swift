import Foundation
@preconcurrency import FirebaseCore

struct FirebaseRuntimeConfiguration: Sendable, Equatable {
    let environment: AppEnvironment
    let projectID: String?
    let projectNumber: String?
    let useEmulators: Bool
    let isConfigured: Bool

    private let options: FirebaseOptions?

    init(
        environment: AppEnvironment,
        options: FirebaseOptions?,
        useEmulators: Bool
    ) {
        let validatedOptions = options.flatMap { option in
            Self.hasRequiredFirebaseValues(option) ? option : nil
        }
        self.environment = environment
        self.projectID = validatedOptions?.projectID
        self.projectNumber = validatedOptions?.gcmSenderID
        self.useEmulators = useEmulators
        self.isConfigured = validatedOptions != nil
        self.options = validatedOptions
    }

    private init(
        environment: AppEnvironment,
        projectID: String?,
        projectNumber: String?,
        useEmulators: Bool,
        isConfigured: Bool
    ) {
        self.environment = environment
        self.projectID = projectID
        self.projectNumber = projectNumber
        self.useEmulators = useEmulators
        self.isConfigured = isConfigured
        self.options = nil
    }

    static let emulator = FirebaseRuntimeConfiguration(
        environment: .development,
        projectID: "syntholo-local",
        projectNumber: "emulator",
        useEmulators: true,
        isConfigured: true
    )

    static var current: FirebaseRuntimeConfiguration {
        let processInfo = ProcessInfo.processInfo
        return resolve(
            environment: AppEnvironment.current,
            arguments: processInfo.arguments,
            isRunningTests: processInfo.environment["XCTestConfigurationFilePath"] != nil,
            optionsPath: { environment in
                Bundle.main.path(
                    forResource: "\(environment.rawValue).firebase",
                    ofType: "plist"
                )
            }
        )
    }

    static func resolve(
        environment: AppEnvironment,
        arguments: [String],
        isRunningTests: Bool,
        optionsPath: (AppEnvironment) -> String?
    ) -> FirebaseRuntimeConfiguration {
        #if DEBUG
        if arguments.contains("--ui-testing") {
            return .emulator
        }
        #endif

        if environment == .development
            || isRunningTests {
            return .emulator
        }

        guard let path = optionsPath(environment) else {
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
            && lhs.projectNumber == rhs.projectNumber
            && lhs.useEmulators == rhs.useEmulators
            && lhs.isConfigured == rhs.isConfigured
    }

    var firebaseOptions: FirebaseOptions? {
        options
    }

    private static func hasRequiredFirebaseValues(
        _ options: FirebaseOptions
    ) -> Bool {
        guard let apiKey = options.apiKey,
              let projectID = options.projectID,
              !projectID.isEmpty else {
            return false
        }
        let googleAppID = options.googleAppID
        let gcmSenderID = options.gcmSenderID
        guard !googleAppID.isEmpty,
              (6...20).contains(gcmSenderID.count),
              gcmSenderID.utf8.allSatisfy({ (48...57).contains($0) }) else {
            return false
        }

        let apiKeyCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_")
        )
        guard apiKey.count == 39,
              apiKey.first == "A",
              apiKey.unicodeScalars.allSatisfy(apiKeyCharacters.contains) else {
            return false
        }

        let appIDComponents = googleAppID.split(
            separator: ":",
            omittingEmptySubsequences: false
        )
        let hexadecimalCharacters = CharacterSet(
            charactersIn: "0123456789abcdefABCDEF"
        )
        return appIDComponents.count == 4
            && Int(appIDComponents[0]) != nil
            && UInt64(appIDComponents[1]) != nil
            && appIDComponents[1] == Substring(gcmSenderID)
            && appIDComponents[2] == "ios"
            && !appIDComponents[3].isEmpty
            && appIDComponents[3].unicodeScalars.allSatisfy(
                hexadecimalCharacters.contains
            )
    }
}
