import Foundation
import Combine

@MainActor
final class CreditsStore: ObservableObject {
    @Published private(set) var balance: CreditBalance = CreditBalance(remaining: 0)
    @Published private(set) var transactions: [CreditTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    // Designated initializer for dependency injection
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        #if DEBUG
        self.balance = CreditBalance(remaining: CreditsResponse.demo.balance)
        self.transactions = CreditsResponse.demo.transactions
        #endif
    }

    // Convenience initializer that safely constructs APIClient on the main actor
    convenience init() {
        self.init(apiClient: APIClient())
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await apiClient.send(CreditsRequest())
            balance = CreditBalance(remaining: response.balance)
            transactions = response.transactions.sorted { $0.occurredAt > $1.occurredAt }
        } catch {
            #if DEBUG
            balance = CreditBalance(remaining: CreditsResponse.demo.balance)
            transactions = CreditsResponse.demo.transactions
            #else
            errorMessage = "Failed to refresh credits: \(error.localizedDescription)"
            #endif
        }
    }

    func deductCredits(amount: Int, reason: String) {
        balance.remaining = max(0, balance.remaining - amount)
        let transaction = CreditTransaction(amount: -amount, type: .debit, reason: reason)
        transactions.insert(transaction, at: 0)
    }

    func grantCredits(amount: Int, reason: String) {
        balance.remaining += amount
        let transaction = CreditTransaction(amount: amount, type: .grant, reason: reason)
        transactions.insert(transaction, at: 0)
    }
}
