import Foundation

enum AppEnvironment: String, Equatable, Sendable {
    case development
    case staging
    case production

    init(buildValue: String?) {
        self = AppEnvironment(rawValue: buildValue ?? "") ?? .development
    }

    static var current: AppEnvironment {
        AppEnvironment(
            buildValue: Bundle.main.object(
                forInfoDictionaryKey: "SYNTHOLO_ENV"
            ) as? String
        )
    }
}
