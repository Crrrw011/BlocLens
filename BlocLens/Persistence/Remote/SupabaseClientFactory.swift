import Foundation
import Supabase

nonisolated enum SupabaseClientFactory {
    static func makeClient(
        configuration: RemoteConfiguration,
        authStorage: (any AuthLocalStorage)? = nil
    ) -> SupabaseClient {
        let options = authStorage.map {
            SupabaseClientOptions(auth: .init(storage: $0))
        } ?? SupabaseClientOptions()
        return SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey,
            options: options
        )
    }
}

#if DEBUG
/// Isolates local UI-test sessions from the simulator Keychain while keeping
/// the production SDK persistence path unchanged.
final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        _ = lock.withLock { values.removeValue(forKey: key) }
    }
}
#endif
