import Foundation
import Combine

/// Root application state shared across major features.
@MainActor
final class AppState: ObservableObject {
    enum PendingNavigationAction: Equatable {
        case openSampleCase
        case openCreator(ServiceLine)
    }

    private enum Keys {
        static let onboardingCompleted = "com.endoreels.onboardingCompleted"
        static let preferredServiceLine = "com.endoreels.preferredServiceLine"
    }

    @Published var currentUser: CurrentUser
    @Published var creditsStore: CreditsStore
    @Published var onboardingCompleted: Bool
    @Published var pendingNavigation: PendingNavigationAction?
    @Published var authSession: AuthSession?
    @Published var isAuthenticating = false
    @Published var authError: String?

    private let authService = AuthService()

    init(currentUser: CurrentUser? = nil) {
        let storedRole = UserDefaults.standard.string(forKey: Keys.preferredServiceLine).flatMap(ServiceLine.init(rawValue:))
        let user = currentUser ?? CurrentUser.demoUser(role: storedRole)
        _currentUser = Published(initialValue: user)

        _creditsStore = Published(initialValue: CreditsStore(tokenProvider: { nil }))

        onboardingCompleted = UserDefaults.standard.bool(forKey: Keys.onboardingCompleted)
        authSession = nil
        pendingNavigation = nil

        creditsStore.updateTokenProvider { [weak self] in self?.authSession?.accessToken }
    }

    func completeOnboarding(with role: ServiceLine, navigation: PendingNavigationAction?) {
        currentUser.role = role
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: Keys.onboardingCompleted)
        UserDefaults.standard.set(role.rawValue, forKey: Keys.preferredServiceLine)
        pendingNavigation = nil
        if let navigation {
            pendingNavigation = navigation
        }
    }

    func resetPendingNavigation() {
        pendingNavigation = nil
    }

    func login(email: String, password: String) async {
        isAuthenticating = true
        authError = nil
        do {
            let session = try await authService.login(email: email, password: password)
            authSession = session
            creditsStore.updateTokenProvider { [weak self] in self?.authSession?.accessToken }
            if let email = session.user.email {
                currentUser.name = email
            }
            await creditsStore.refresh()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    func logout() {
        authSession = nil
        creditsStore.updateTokenProvider { nil }
    }
}

struct CurrentUser: Identifiable {
    let id: UUID
    var name: String
    var role: ServiceLine?
    var isAdmin: Bool

    static func demoUser(role: ServiceLine? = .pulmonary) -> CurrentUser {
        CurrentUser(id: UUID(), name: "Dr. Demo User", role: role, isAdmin: true)
    }
}
