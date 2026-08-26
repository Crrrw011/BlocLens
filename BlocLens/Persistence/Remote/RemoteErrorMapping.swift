import AuthenticationServices
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

        if let sessionError = error as? ASWebAuthenticationSessionError,
           sessionError.code == .canceledLogin {
            return .userCancelled
        }
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return .userCancelled
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "PGRST116", "PGRST205":
                return .notFound
            case "42501", "PGRST301":
                return .forbidden
            case "23505":
                return .conflict
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

        if let authError = error as? AuthError {
            return mapAuth(authError)
        }

        return .unknown
    }

    private static func mapAuth(_ error: AuthError) -> RepositoryError {
        switch error {
        case .sessionMissing:
            return .unauthenticated
        case .weakPassword:
            return .invalidInput
        case .api(_, let errorCode, _, _):
            switch errorCode.rawValue {
            case "invalid_credentials", "email_not_confirmed":
                return .unauthenticated
            case "user_not_found":
                return .notFound
            case "weak_password":
                return .invalidInput
            case "user_already_exists", "email_exists":
                return .conflict
            default:
                return .unknown
            }
        default:
            return .unknown
        }
    }
}
