import Foundation

struct CreditBalance: Identifiable {
    let id = UUID()
    var remaining: Int
}

struct CreditTransaction: Identifiable, Codable {
    enum TransactionType: String, Codable {
        case debit
        case refund
        case grant
    }

    let id: UUID
    let reelID: UUID?
    let amount: Int
    let type: TransactionType
    let reason: String
    let occurredAt: Date
    let idempotencyKey: String

    init(id: UUID = UUID(), reelID: UUID? = nil, amount: Int, type: TransactionType, reason: String, occurredAt: Date = .now, idempotencyKey: String = UUID().uuidString) {
        self.id = id
        self.reelID = reelID
        self.amount = amount
        self.type = type
        self.reason = reason
        self.occurredAt = occurredAt
        self.idempotencyKey = idempotencyKey
    }

    static let demoTransactions: [CreditTransaction] = [
        CreditTransaction(reelID: UUID(), amount: -1, type: .debit, reason: "PHI review", occurredAt: Date().addingTimeInterval(-3600)),
        CreditTransaction(reelID: UUID(), amount: 1, type: .refund, reason: "Review refund", occurredAt: Date().addingTimeInterval(-7200)),
        CreditTransaction(amount: 5, type: .grant, reason: "Admin grant", occurredAt: Date().addingTimeInterval(-86400))
    ].sorted { $0.occurredAt > $1.occurredAt }
}
