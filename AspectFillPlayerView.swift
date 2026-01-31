import SwiftUI
import AVFoundation

struct AspectFillPlayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            guard let layer = layer as? AVPlayerLayer else {
                preconditionFailure("Expected AVPlayerLayer")
            }
            return layer
        }
    }
}

