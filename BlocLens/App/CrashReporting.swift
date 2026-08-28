import Foundation
import Sentry

nonisolated protocol CrashReporting: Sendable {
    func start()
    func setUserID(_ userID: String?)
    func recordError(_ error: Error)
}

struct SentryCrashReporter: CrashReporting, Sendable {
    private let dsn: String

    init(dsn: String) {
        self.dsn = dsn
    }

    static func makeFromBundle() -> CrashReporting {
        let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String ?? ""
        guard !dsn.isEmpty, dsn != "YOUR_SENTRY_DSN" else {
            return NoopCrashReporter()
        }
        return SentryCrashReporter(dsn: dsn)
    }

    func start() {
        guard !dsn.isEmpty, dsn != "YOUR_SENTRY_DSN" else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAutoSessionTracking = true
            options.enableWatchdogTerminationTracking = true
            options.tracesSampleRate = 0.1
        }
    }

    func setUserID(_ userID: String?) {
        guard let userID, !userID.isEmpty else {
            SentrySDK.setUser(nil)
            return
        }
        SentrySDK.setUser(User(userId: userID))
    }

    func recordError(_ error: Error) {
        SentrySDK.capture(error: error)
    }
}

struct NoopCrashReporter: CrashReporting, Sendable {
    func start() {}
    func setUserID(_ userID: String?) {}
    func recordError(_ error: Error) {}
}

@MainActor
enum CrashReportingService {
    static let shared: any CrashReporting = SentryCrashReporter.makeFromBundle()

    static func configure() {
        shared.start()
    }

    static func syncUser(_ userID: UserID?) {
        shared.setUserID(userID?.rawValue)
    }

    static func record(_ error: Error) {
        shared.recordError(error)
    }
}
