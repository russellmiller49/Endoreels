#if os(iOS)
import SwiftUI

@available(iOS 17, *)
public struct FreezeAnnotatorView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Text("Freeze Frame Annotations")
                .font(.headline)
            Text("Annotation controls pending implementation.")
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
