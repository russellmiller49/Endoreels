import Foundation
import Combine

@MainActor
final class CreditsStore: ObservableObject {
    @Published private(set) var balance: CreditBalance = CreditBalance(remaining: 0)
    @Published private(set) var transactions: [CreditTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func loadDemoData() {
        #if DEBUG
        balance = CreditBalance(remaining: CreditsResponse.demo.balance)
        transactions = CreditsResponse.demo.transactions
        #endif
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
