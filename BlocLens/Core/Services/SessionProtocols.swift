import Foundation

nonisolated protocol AuthenticationRepository: Sendable {
    func state() async -> AuthenticationState
    func signInWithMockAccount() async -> UserProfile
    func signOut() async
}

nonisolated protocol OnboardingStore: Sendable {
    func isComplete() -> Bool
    func setComplete(_ isComplete: Bool)
}

final class UserDefaultsOnboardingStore: OnboardingStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "bloclens.onboarding.complete.v1") {
        self.defaults = defaults
        self.key = key
    }

    func isComplete() -> Bool { defaults.bool(forKey: key) }
    func setComplete(_ isComplete: Bool) { defaults.set(isComplete, forKey: key) }
}

final class InMemoryOnboardingStore: OnboardingStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool

    init(isComplete: Bool) { value = isComplete }

    func isComplete() -> Bool { lock.withLock { value } }
    func setComplete(_ isComplete: Bool) { lock.withLock { value = isComplete } }
}
