import SwiftUI

struct ToolbarView: View {
    let isRippleOn: Bool
    let canUndo: Bool
    let canRedo: Bool
    let onSplit: () -> Void
    let onMerge: () -> Void
    let onRippleToggle: () -> Void
    let onRemoveSilence: () -> Void
    let onSpeed: () -> Void
    let onMarker: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onSplit()
            } label: {
                Label("Split", systemImage: "scissors")
            }
            .buttonStyle(.bordered)

            Button {
                onMerge()
            } label: {
                Label("Merge", systemImage: "link")
            }
            .buttonStyle(.bordered)

            Button {
                onRippleToggle()
            } label: {
                Label(isRippleOn ? "Ripple" : "Overwrite", systemImage: isRippleOn ? "waveform.path" : "square")
            }
            .buttonStyle(.borderedProminent)

            Button {
                onSpeed()
            } label: {
                Label("Speed", systemImage: "speedometer")
            }
            .buttonStyle(.bordered)

            Button {
                onMarker()
            } label: {
                Label("Marker", systemImage: "bookmark")
            }
            .buttonStyle(.bordered)

            Button {
                onRemoveSilence()
            } label: {
                Label("Silence", systemImage: "waveform.badge.mute")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!canUndo)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
            .disabled(!canRedo)
        }
        .font(.caption)
    }
}
