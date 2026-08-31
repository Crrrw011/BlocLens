import Foundation

/// Centralised, deterministic data-source decision.
/// Preview > Test explicit > Scheme remote > Persistent/Bundled Supabase > Offline/Error handling.
enum DataSourceMode: Equatable {
    case mock(reason: String)
    case supabase(configuration: RemoteConfiguration, reason: String)
    case offlineWithCache
    case offlineWithoutCache
    case error(reason: String)
}

enum DataSourceResolver {
    // MARK: - Public entry

    static func resolve(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1",
        isTest: Bool = NSClassFromString("XCTest") != nil
    ) -> DataSourceMode {
        // 1. Preview: always Mock
        if isPreview {
            return .mock(reason: "Preview — Mock")
        }

        // 2. Explicit Mock launch arguments (Debug only, but check regardless)
        if arguments.contains("--mock-empty") {
            return .mock(reason: "LaunchArgument --mock-empty")
        }
        if arguments.contains("--mock-error") {
            return .mock(reason: "LaunchArgument --mock-error")
        }
        if arguments.contains("--mock-offline-cached") {
            return .offlineWithCache
        }
        if arguments.contains("--mock-offline-no-cache") {
            return .offlineWithoutCache
        }

        // 3. Explicit remote launch arguments (Debug)
        if arguments.contains("--cloud-supabase") {
            if let config = try? LocalEnvironmentConfiguration.makeCloud(environment: environment, infoDictionary: infoDictionary) {
                return .supabase(configuration: config, reason: "LaunchArgument --cloud-supabase")
            }
            return .error(reason: "Missing BLOCLENS_CLOUD_URL/BLOCLENS_CLOUD_ANON_KEY for --cloud-supabase")
        }
        if arguments.contains("--local-supabase") {
            if let config = try? LocalEnvironmentConfiguration.make(environment: environment, infoDictionary: infoDictionary) {
                return .supabase(configuration: config, reason: "LaunchArgument --local-supabase")
            }
            return .error(reason: "Missing BLOCLENS_SUPABASE_URL/BLOCLENS_SUPABASE_ANON_KEY for --local-supabase")
        }

        // 4. Persisted / Bundled Supabase (normal Debug/Release)
        //    Try ephemeral env first, then Info.plist, then UserDefaults persisted from previous Scheme launch.
        if let config = try? LocalEnvironmentConfiguration.make(environment: environment, infoDictionary: infoDictionary) {
            persistForHomeScreenLaunchIfNeeded(environment: environment, config: config)
            return .supabase(configuration: config, reason: "Bundled/Persisted Supabase — \(config.mode == .production ? "cloud" : "local")")
        }
        if let config = try? LocalEnvironmentConfiguration.makeCloud(environment: environment, infoDictionary: infoDictionary) {
            persistForHomeScreenLaunchIfNeeded(environment: environment, config: config)
            return .supabase(configuration: config, reason: "Bundled/Persisted Supabase — \(config.mode == .production ? "cloud" : "local")")
        }
        if let persisted = try? PersistedRemoteConfigurationStore.load() {
            // Filter localhost persisted on physical device (migrating from simulator localhost)
            #if targetEnvironment(simulator)
            return .supabase(configuration: persisted, reason: "Persisted Supabase — home-screen launch")
            #else
            if let host = persisted.projectURL.host?.lowercased(),
               host == "localhost" || host == "127.0.0.1" || host == "::1" {
                // Stale localhost persisted — ignore and fall through to mock/error
            } else {
                return .supabase(configuration: persisted, reason: "Persisted Supabase — home-screen launch")
            }
            #endif
        }

        // 5. No config
        #if DEBUG
        // Debug without config: Mock with diagnostic reason (not silent)
        return .mock(reason: "No Supabase config — Mock (Debug)")
        #else
        // Release without config: error, never Mock masquerade
        return .error(reason: "Missing Supabase configuration — Release requires bundled Info.plist")
        #endif
    }

    // MARK: - Persistence for home-screen launch

    private static func persistForHomeScreenLaunchIfNeeded(environment: [String: String], config: RemoteConfiguration) {
        // Only persist when we have just read from ephemeral Scheme env (not from Info.plist/persisted)
        // to seed future home-screen launches. Check if env actually contained the keys.
        let hasEnvCloud = environment["BLOCLENS_CLOUD_URL"] != nil || environment["BLOCLENS_CLOUD_ANON_KEY"] != nil
        let hasEnvLocal = environment["BLOCLENS_SUPABASE_URL"] != nil || environment["BLOCLENS_SUPABASE_ANON_KEY"] != nil
        guard hasEnvCloud || hasEnvLocal else { return }
        try? PersistedRemoteConfigurationStore.save(config)
    }
}

// MARK: - Persisted store (UserDefaults, no key logged)

enum PersistedRemoteConfigurationStore {
    private static let urlKey = "bloclens.persisted.supabase.url"
    private static let keyKey = "bloclens.persisted.supabase.key"
    private static let modeKey = "bloclens.persisted.supabase.mode"

    static func save(_ config: RemoteConfiguration) throws {
        UserDefaults.standard.set(config.projectURL.absoluteString, forKey: urlKey)
        UserDefaults.standard.set(config.publishableKey, forKey: keyKey)
        UserDefaults.standard.set(String(describing: config.mode), forKey: modeKey)
    }

    static func load() throws -> RemoteConfiguration? {
        guard let urlString = UserDefaults.standard.string(forKey: urlKey),
              let url = URL(string: urlString),
              let key = UserDefaults.standard.string(forKey: keyKey),
              let modeString = UserDefaults.standard.string(forKey: modeKey) else { return nil }
        let mode: RemoteEnvironmentMode = modeString.contains("production") ? .production : modeString.contains("integrationTest") ? .integrationTest : .localDevelopment
        return try RemoteConfiguration(mode: mode, projectURL: url, publishableKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: urlKey)
        UserDefaults.standard.removeObject(forKey: keyKey)
        UserDefaults.standard.removeObject(forKey: modeKey)
    }
}
