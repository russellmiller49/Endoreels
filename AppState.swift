import Foundation
import Combine

/// Root application state shared across major features.
@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: CurrentUser
    @Published var creditsStore: CreditsStore

    init(currentUser: CurrentUser? = nil, creditsStore: CreditsStore? = nil) {
        if let currentUser {
            self.currentUser = currentUser
        } else {
            self.currentUser = CurrentUser.demoUser()
        }

        if let creditsStore {
            self.creditsStore = creditsStore
        } else {
            self.creditsStore = CreditsStore()
        }
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
