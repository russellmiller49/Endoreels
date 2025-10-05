#if os(iOS)
import SwiftUI
import AVKit
import EndoEditCore

/// Placeholder editor surface. Later revisions will replace this with the full
/// timeline, overlay controls, and annotation canvas. For now it simply plays the
/// source item through the custom compositor to validate the pipeline.
@available(iOS 17, *)
public struct VideoEditorView: View {
    private let engine: EndoEditorEngine
    @State private var player: AVPlayer?
    @State private var loadError: String?
    @State private var isLoading = false

    public init(engine: EndoEditorEngine) {
        self.engine = engine
        self._player = State(initialValue: nil)
        self._loadError = State(initialValue: nil)
        self._isLoading = State(initialValue: false)
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else if let loadError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(loadError)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else if isLoading {
                ProgressView("Preparing preview…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "video.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Preview unavailable")
                    .foregroundStyle(.secondary)
            }

            Text("EndoEditKit – New Editor Preview")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            await loadPlayerIfNeeded()
        }
    }

    @MainActor
    private func loadPlayerIfNeeded() async {
        guard !isLoading, player == nil else { return }
        isLoading = true
        do {
            let item = try await engine.makePreviewPlayerItem()
            player = AVPlayer(playerItem: item)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}
#endif
