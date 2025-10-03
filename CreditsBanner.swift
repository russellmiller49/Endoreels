import SwiftUI

struct CreditsBanner: View {
    @ObservedObject var store: CreditsStore
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.shield")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Credits")
                    .font(.subheadline.weight(.semibold))
                Text(creditSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: action) {
                Text("History")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var creditSubtitle: String {
        "Remaining: \(store.balance.remaining)"
    }
}
