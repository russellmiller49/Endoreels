import Foundation
import Combine

@MainActor
final class CreditsStore: ObservableObject {
    @Published private(set) var balance: CreditBalance = CreditBalance(remaining: 0)
    @Published private(set) var transactions: [CreditTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        #if DEBUG
        self.balance = CreditBalance(remaining: CreditsResponse.demo.balance)
        self.transactions = CreditsResponse.demo.transactions
        #endif
    }

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
            // Use demo data in debug builds if API not available yet.
            balance = CreditBalance(remaining: CreditsResponse.demo.balance)
            transactions = CreditsResponse.demo.transactions
            #else
            errorMessage = "Failed to refresh credits: \(error.localizedDescription)"
            #endif
        }
    }

    func deductCredits(amount: Int, reelID: UUID, reason: String) async throws {
        let key = UUID().uuidString
        let transaction = CreditTransaction(reelID: reelID, amount: -amount, type: .debit, reason: reason, idempotencyKey: key)
        transactions.insert(transaction, at: 0)
        balance.remaining -= amount
        // TODO: POST /api/process-video or /api/credits with idempotency header.
    }

    func refundCredits(amount: Int, reelID: UUID, reason: String) async {
        let transaction = CreditTransaction(reelID: reelID, amount: amount, type: .refund, reason: reason)
        transactions.insert(transaction, at: 0)
        balance.remaining += amount
    }

    func grantCredits(amount: Int, reason: String) async {
        let transaction = CreditTransaction(amount: amount, type: .grant, reason: reason)
        transactions.insert(transaction, at: 0)
        balance.remaining += amount
    }
}

