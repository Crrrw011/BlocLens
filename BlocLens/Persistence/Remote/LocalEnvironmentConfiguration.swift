import Foundation

nonisolated enum LocalEnvironmentConfiguration {
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> RemoteConfiguration? {
        guard let urlString = environment["BLOCLENS_SUPABASE_URL"],
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        let key = environment["BLOCLENS_SUPABASE_ANON_KEY"] ?? ""
        return try RemoteConfiguration(mode: .localDevelopment, projectURL: url, publishableKey: key)
    }

    static func makeCloud(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> RemoteConfiguration? {
        guard let urlString = environment["BLOCLENS_CLOUD_URL"],
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        let key = environment["BLOCLENS_CLOUD_ANON_KEY"] ?? ""
        return try RemoteConfiguration(mode: .production, projectURL: url, publishableKey: key)
    }
}
