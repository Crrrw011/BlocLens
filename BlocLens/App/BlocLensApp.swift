import SwiftUI

@main
struct BlocLensApp: App {
    private let environment: AppEnvironment

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--mock-empty") {
            environment = .development(scenario: .empty)
        } else if arguments.contains("--mock-error") {
            environment = .development(scenario: .error)
        } else if arguments.contains("--mock-offline-no-cache") {
            environment = .development(scenario: .offlineWithoutCache, isOnline: false)
        } else if arguments.contains("--mock-offline-cached") {
            environment = .development(scenario: .offlineWithCache, isOnline: false)
        } else {
            environment = .development()
        }
        #else
        environment = .development()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(environment: environment)
        }
    }
}
