import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
enum FirebaseBootstrap {
    static func configure(
        _ configuration: FirebaseRuntimeConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        #if DEBUG
        guard !arguments.contains("--ui-testing") else {
            return false
        }
        #endif

        guard configuration.isConfigured else {
            return false
        }

        if FirebaseApp.app() == nil {
            guard let options = configuration.firebaseOptions
                ?? emulatorOptions(for: configuration) else {
                return false
            }
            FirebaseApp.configure(options: options)
        }

        if configuration.useEmulators {
            configureEmulators()
        }

        return FirebaseApp.app() != nil
    }

    private static func emulatorOptions(
        for configuration: FirebaseRuntimeConfiguration
    ) -> FirebaseOptions? {
        guard configuration.useEmulators,
              let projectID = configuration.projectID else {
            return nil
        }

        let options = FirebaseOptions(
            googleAppID: "1:1234567890:ios:abcdef1234567890",
            gcmSenderID: "1234567890"
        )
        options.apiKey = "A" + String(repeating: "0", count: 38)
        options.projectID = projectID
        options.bundleID = Bundle.main.bundleIdentifier ?? "com.syntholo.ios"
        return options
    }

    private static func configureEmulators() {
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        firestore.settings = settings
    }
}
