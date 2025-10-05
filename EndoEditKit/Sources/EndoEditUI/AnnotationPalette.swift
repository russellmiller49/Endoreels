#if os(iOS)
import SwiftUI

@available(iOS 17, *)
public struct AnnotationPalette: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Annotation Palette")
                .font(.headline)
            Text("Shape, text, and pen tools will live here.")
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
