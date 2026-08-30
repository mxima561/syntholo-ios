@preconcurrency import FirebaseAnalytics

enum FirebaseAnalyticsValue: Equatable, Sendable {
    case string(String)
    case integer(Int)

    fileprivate var firebaseValue: Any {
        switch self {
        case let .string(value):
            value
        case let .integer(value):
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
            .integer(isRestored ? 1 : 0)
        case let .locale(locale):
            .string(locale.rawValue)
        // Stable IDs and numeric versions stay separate because a complete
        // local version ID can exceed Firebase's standard string-value limit.
        case let .catalogVersion(version):
            .integer(version.rawValue)
        case let .programID(identifier):
            .string(identifier.rawValue)
        case let .programVersion(version):
            .integer(version.rawValue)
        case let .moduleID(identifier):
            .string(identifier.rawValue)
        case let .moduleVersion(version):
            .integer(version.rawValue)
        case let .lessonID(identifier):
            .string(identifier.rawValue)
        case let .lessonVersion(version):
            .integer(version.rawValue)
        case let .rubricID(identifier):
            .string(identifier.rawValue)
        case let .rubricVersion(version):
            .integer(version.rawValue)
        case let .curriculumSource(source):
            .string(source.rawValue)
        case let .durationBucket(bucket):
            .string(bucket.rawValue)
        }
    }
}
