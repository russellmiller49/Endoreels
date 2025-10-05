#if os(iOS)
import SwiftUI

@available(iOS 17, *)
public struct TimelineMiniView: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                Text("Timeline Preview")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            )
            .frame(height: 80)
    }
}
#endif
