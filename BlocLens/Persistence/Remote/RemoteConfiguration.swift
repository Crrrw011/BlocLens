import Foundation

nonisolated enum RemoteEnvironmentMode: Equatable, Sendable {
    case production
    case localDevelopment
    case integrationTest
}

nonisolated struct RemoteConfiguration: Equatable, Sendable {
    let mode: RemoteEnvironmentMode
    let projectURL: URL
    let publishableKey: String

    init(mode: RemoteEnvironmentMode, projectURL: URL, publishableKey: String) throws {
        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw RepositoryError.invalidConfiguration }
        guard let scheme = projectURL.scheme?.lowercased(), projectURL.host != nil else {
            throw RepositoryError.invalidConfiguration
        }

        switch mode {
        case .production:
            guard scheme == "https" else { throw RepositoryError.invalidConfiguration }
        case .localDevelopment, .integrationTest:
            guard scheme == "http" || scheme == "https" else { throw RepositoryError.invalidConfiguration }
            if scheme == "http", !Self.isLoopback(projectURL) {
                throw RepositoryError.invalidConfiguration
            }
        }

        if mode != .production, Self.isSupabaseCloud(projectURL) {
            throw RepositoryError.invalidConfiguration
        }

        self.mode = mode
        self.projectURL = projectURL
        self.publishableKey = trimmedKey
    }

    private static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    private static func isSupabaseCloud(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "supabase.co" || host.hasSuffix(".supabase.co")
    }
}
