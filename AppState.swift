import Foundation
import Combine

/// Root application state shared across major features.
@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: CurrentUser
    @Published var creditsStore: CreditsStore

    init(currentUser: CurrentUser = CurrentUser.demoUser(), creditsStore: CreditsStore = CreditsStore()) {
        self.currentUser = currentUser
        self.creditsStore = creditsStore
    }
}

struct CurrentUser: Identifiable {
    let id: UUID
    var name: String
    var role: ServiceLine?
    var isAdmin: Bool

    static func demoUser() -> CurrentUser {
        CurrentUser(id: UUID(), name: "Dr. Demo User", role: .pulmonary, isAdmin: true)
    }
}
