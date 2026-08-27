@preconcurrency import FirebaseAnalytics

enum FirebaseAnalyticsValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)

    fileprivate var firebaseValue: Any {
        switch self {
        case let .string(value):
            value
        case let .bool(value):
            value
        }
    }
}

@MainActor
struct FirebaseAnalyticsClient: AnalyticsClient {
    typealias EventLogger = @MainActor (
        _ name: String,
        _ parameters: [String: FirebaseAnalyticsValue]
    ) -> Void

    private let logEvent: EventLogger

    init() {
        logEvent = { name, parameters in
            Analytics.logEvent(
                name,
                parameters: parameters.mapValues(\.firebaseValue)
            )
        }
    }

    init(logEvent: @escaping EventLogger) {
        self.logEvent = logEvent
    }

    func log(_ event: AnalyticsEvent) {
        let payload = event.payload
        let parameters = Dictionary(
            uniqueKeysWithValues: payload.parameters.map { parameter in
                (parameter.key.rawValue, Self.value(for: parameter))
            }
        )
        logEvent(payload.name.rawValue, parameters)
    }

    private static func value(
        for parameter: AnalyticsParameter
    ) -> FirebaseAnalyticsValue {
        switch parameter {
        case let .goal(goal):
            .string(goal.rawValue)
        case let .path(path):
            .string(path.rawValue)
        case let .coachMode(mode):
            .string(mode.rawValue)
        case let .authenticationProvider(provider):
            .string(provider.rawValue)
        case let .restoredSession(isRestored):
            .bool(isRestored)
        }
    }
}
