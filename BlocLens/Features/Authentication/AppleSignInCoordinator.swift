import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

nonisolated struct AppleSignInCredential: Equatable, Sendable {
    let idToken: String
    let nonce: String
}

@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<AppleSignInCredential, Error>?
    private var pendingNonce: String?

    func credential() async throws -> AppleSignInCredential {
        try await withCheckedThrowingContinuation { continuation in
            guard self.continuation == nil else {
                continuation.resume(throwing: RepositoryError.invalidState)
                return
            }
            let rawNonce = UUID().uuidString.lowercased()
            self.continuation = continuation
            pendingNonce = rawNonce
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(rawNonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = pendingNonce else {
            finish(with: .failure(RepositoryError.externalServiceError))
            return
        }
        finish(with: .success(AppleSignInCredential(idToken: token, nonce: nonce)))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(with: .failure(RepositoryError.userCancelled))
        } else {
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<AppleSignInCredential, Error>) {
        let continuation = continuation
        self.continuation = nil
        pendingNonce = nil
        continuation?.resume(with: result)
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let firstWindow = scenes.flatMap(\.windows).first {
            return firstWindow
        }
        return ASPresentationAnchor()
    }
}
