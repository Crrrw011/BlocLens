import Foundation

nonisolated struct RemoteConfiguration: Equatable, Sendable {
    let projectURL: URL
    let publishableKey: String

    init(projectURL: URL, publishableKey: String) throws {
        guard projectURL.scheme?.lowercased() == "https", projectURL.host != nil else {
            throw RepositoryError.invalidConfiguration
        }
        guard !publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.invalidConfiguration
        }
        self.projectURL = projectURL
        self.publishableKey = publishableKey
    }
}
