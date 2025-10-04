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

    init(currentUser: CurrentUser? = nil, creditsStore: CreditsStore? = nil) {
        let storedRole = UserDefaults.standard.string(forKey: Keys.preferredServiceLine).flatMap(ServiceLine.init(rawValue:))
        let user = currentUser ?? CurrentUser.demoUser(role: storedRole)
        self.currentUser = user

        if let creditsStore {
            self.creditsStore = creditsStore
        } else {
            let store = CreditsStore()
            store.loadDemoData()
            self.creditsStore = store
        }

        self.onboardingCompleted = UserDefaults.standard.bool(forKey: Keys.onboardingCompleted)
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
}

struct CurrentUser: Identifiable {
    let id = UUID()
    var name: String
    var role: ServiceLine?
    var isAdmin: Bool

    static func demoUser(role: ServiceLine? = .pulmonary) -> CurrentUser {
        CurrentUser(name: "Dr. Demo User", role: role, isAdmin: true)
    }
}
