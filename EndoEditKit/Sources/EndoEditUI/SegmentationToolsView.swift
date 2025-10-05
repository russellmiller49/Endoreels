#if os(iOS)
import SwiftUI

@available(iOS 17, *)
public struct SegmentationToolsView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Smart Select")
                .font(.headline)
            Text("Segmentation controls to be added in later milestones.")
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
