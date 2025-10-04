import SwiftUI

struct CreditsHistoryView: View {
    @ObservedObject var store: CreditsStore

    var body: some View {
        List {
            Section("Balance") {
                Text("Remaining Credits: \(store.balance.remaining)")
                    .font(.headline)
                    .accessibilityIdentifier("credits-balance")
            }

            Section("Transactions") {
                if store.transactions.isEmpty {
                    Text("No transactions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.transactions) { transaction in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(transactionTitle(for: transaction))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(amountText(for: transaction))
                                    .font(.subheadline)
                                    .foregroundStyle(amountColor(for: transaction))
                            }
                            if let reelID = transaction.reelID {
                                Text("Reel: \(reelID.uuidString.prefix(8))…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(transaction.reason)
                                .font(.caption)
                            Text(transaction.occurredAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Review Credits")
        .task { await store.refresh() }
    }

    private func transactionTitle(for transaction: CreditTransaction) -> String {
        switch transaction.type {
        case .debit: return "Manual Review Processed"
        case .refund: return "Credit Refunded"
        case .grant: return "Credits Granted"
        }
    }

    private func amountText(for transaction: CreditTransaction) -> String {
        let sign = transaction.amount > 0 ? "+" : ""
        return "\(sign)\(transaction.amount)"
    }

    private func amountColor(for transaction: CreditTransaction) -> Color {
        transaction.amount >= 0 ? .green : .orange
    }
}
