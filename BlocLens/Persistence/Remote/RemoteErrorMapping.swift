import Foundation
import Supabase

nonisolated enum RemoteErrorMapping {
    static func map(_ error: any Error) -> RepositoryError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed, .dataNotAllowed:
                return .network
            default:
                return .network
            }
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "PGRST116", "PGRST205":
                return .notFound
            case "42501", "PGRST301":
                return .forbidden
            default:
                return .unknown
            }
        }

        if let httpError = error as? HTTPError {
            switch httpError.response.statusCode {
            case 401:
                return .unauthenticated
            case 403:
                return .forbidden
            case 404:
                return .notFound
            case 408:
                return .timeout
            case 429:
                return .rateLimited
            case 500...599:
                return .unavailable
            default:
                return .unknown
            }
        }

        if error is DecodingError {
            return .decodingFailure
        }

        return .unknown
    }
}
