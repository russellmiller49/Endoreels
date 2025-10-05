#if os(iOS)
import SwiftUI

@available(iOS 17, *)
public struct RedactionHUD: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Redaction Tools")
                .font(.headline)
            Text("Controls will appear here once implemented.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
#endif
