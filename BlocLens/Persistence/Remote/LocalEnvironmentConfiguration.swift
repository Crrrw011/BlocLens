import Foundation

nonisolated enum LocalEnvironmentConfiguration {
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> RemoteConfiguration? {
        // 1. Ephemeral Scheme env — ignore localhost on physical device
        if let urlString = environment["BLOCLENS_SUPABASE_URL"],
           !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: urlString),
           !isUnreachableLocalhost(url) {
            let key = environment["BLOCLENS_SUPABASE_ANON_KEY"] ?? ""
            return try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: key)
        }
        // 2. Bundled Info.plist (xcconfig → build-time) — ignore localhost on device
        if let urlString = infoDictionary["BLOCLENS_SUPABASE_URL"] as? String,
           !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !urlString.hasPrefix("$("),
           let url = URL(string: urlString),
           !isUnreachableLocalhost(url) {
            let key = (infoDictionary["BLOCLENS_SUPABASE_ANON_KEY"] as? String) ?? ""
            return try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: key)
        }
        return nil
    }

    /// Returns true if url is localhost/127.0.0.1 and we are on a physical device (not simulator).
    private static func isUnreachableLocalhost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
        guard isLocalhost else { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static func makeCloud(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> RemoteConfiguration? {
        if let urlString = environment["BLOCLENS_CLOUD_URL"],
           !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: urlString) {
            let key = environment["BLOCLENS_CLOUD_ANON_KEY"] ?? ""
            return try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: key)
        }
        if let urlString = infoDictionary["BLOCLENS_CLOUD_URL"] as? String,
           !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !urlString.hasPrefix("$("),
           let url = URL(string: urlString) {
            let key = (infoDictionary["BLOCLENS_CLOUD_ANON_KEY"] as? String) ?? ""
            return try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: key)
        }
        return nil
    }
}
