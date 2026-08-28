import Foundation

nonisolated protocol AuthenticationRepository: Sendable {
    func state() async -> AuthenticationState
    func restoreSession() async -> AuthenticationState
    func signIn(email: String, password: String) async -> AuthenticationState
    func signUp(email: String, password: String) async -> AuthenticationState
    func updateUsername(_ username: String) async -> AuthenticationState
    func confirmAge(isOver16: Bool) async -> AuthenticationState
    func signOut() async throws -> AuthenticationState
    func signInWithApple(idToken: String, nonce: String) async -> AuthenticationState
    func signInWithGoogle() async -> AuthenticationState
    func signInWithMockAccount() async -> AuthenticationState
    func deleteAccount() async throws -> AuthenticationState
}

nonisolated protocol OnboardingStore: Sendable {
    func isComplete() -> Bool
    func setComplete(_ isComplete: Bool)
}

nonisolated protocol LanguagePreferenceStore: Sendable {
    func preference() -> LanguagePreference
    func setPreference(_ preference: LanguagePreference)
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

final class UserDefaultsLanguagePreferenceStore: LanguagePreferenceStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "bloclens.language.preference.v1") {
        self.defaults = defaults
        self.key = key
    }

    func preference() -> LanguagePreference {
        guard let rawValue = defaults.string(forKey: key),
              let preference = LanguagePreference(rawValue: rawValue) else {
            return .system
        }
        return preference
    }

    func setPreference(_ preference: LanguagePreference) {
        defaults.set(preference.rawValue, forKey: key)
    }
}

final class InMemoryLanguagePreferenceStore: LanguagePreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: LanguagePreference

    init(preference: LanguagePreference = .system) { value = preference }

    func preference() -> LanguagePreference { lock.withLock { value } }
    func setPreference(_ preference: LanguagePreference) { lock.withLock { value = preference } }
}
