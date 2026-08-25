import Foundation
import Supabase

nonisolated enum SupabaseClientFactory {
    static func makeClient(configuration: RemoteConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey
        )
    }
}
