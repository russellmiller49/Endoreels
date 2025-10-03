import Foundation
import Combine

@MainActor
final class CreditsStore: ObservableObject {
    @Published private(set) var balance: CreditBalance = CreditBalance(remaining: 0)
    @Published private(set) var transactions: [CreditTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var apiClient: APIClient
    private var tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
        self.apiClient = APIClient(authTokenProvider: tokenProvider)
        #if DEBUG
        self.balance = CreditBalance(remaining: CreditsResponse.demo.balance)
        self.transactions = CreditsResponse.demo.transactions
        #endif
    }

    func updateTokenProvider(_ provider: @escaping () -> String?) {
        tokenProvider = provider
        apiClient = APIClient(authTokenProvider: provider)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        guard let token = tokenProvider(), !token.isEmpty else {
            balance = CreditBalance(remaining: 0)
            transactions = []
            return
        }
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
        guard let token = tokenProvider(), !token.isEmpty else { throw CreditsError.notAuthenticated }
        let key = UUID().uuidString
        let request = DeductCreditsRequest(payload: .init(amount: amount, reelID: reelID, reason: reason), idempotencyKey: key)
        do {
            let response = try await apiClient.send(request)
            balance = CreditBalance(remaining: response.balance)
            transactions = response.transactions.sorted { $0.occurredAt > $1.occurredAt }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func refundCredits(amount: Int, reelID: UUID, reason: String) async {
        guard let token = tokenProvider(), !token.isEmpty else {
            errorMessage = CreditsError.notAuthenticated.localizedDescription
            return
        }
        let request = RefundCreditsRequest(payload: .init(amount: amount, reelID: reelID, reason: reason))
        do {
            let response = try await apiClient.send(request)
            balance = CreditBalance(remaining: response.balance)
            transactions = response.transactions.sorted { $0.occurredAt > $1.occurredAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func grantCredits(amount: Int, reason: String, userID: UUID? = nil) async {
        guard let token = tokenProvider(), !token.isEmpty else {
            errorMessage = CreditsError.notAuthenticated.localizedDescription
            return
        }
        let request = GrantCreditsRequest(payload: .init(amount: amount, reason: reason, userID: userID))
        do {
            let response = try await apiClient.send(request)
            balance = CreditBalance(remaining: response.balance)
            transactions = response.transactions.sorted { $0.occurredAt > $1.occurredAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum CreditsError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to manage AI credits."
        }
    }
}

#if DEBUG
extension CreditsStore {
    static var preview: CreditsStore {
        CreditsStore(tokenProvider: { nil })
    }
}
#endif
