import AVFoundation
import os

final class PlayerOwner: NSObject {
    enum PlayerError: Error { case unknown }

    private(set) var player: AVPlayer?
    private var item: AVPlayerItem?
    private let log = Logger(subsystem: "EndoReels", category: "Player")
    private var autoPlay = false
    private var onReady: (() -> Void)?
    private var onFailure: ((Error) -> Void)?

    func start(with asset: AVAsset,
               autoPlay: Bool = false,
               onReady: (() -> Void)? = nil,
               onFailure: ((Error) -> Void)? = nil) {
        stop()

        self.autoPlay = autoPlay
        self.onReady = onReady
        self.onFailure = onFailure

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 0

        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false

        self.item = item
        self.player = player

        item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.initial, .new], context: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(failedToPlayToEnd(_:)),
                                               name: .AVPlayerItemFailedToPlayToEndTime,
                                               object: item)
    }

    func stop() {
        if let item = item {
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
        NotificationCenter.default.removeObserver(self)
        item = nil
        player = nil
        onReady = nil
        onFailure = nil
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(AVPlayerItem.status), let item = item else { return }

        switch item.status {
        case .readyToPlay:
            log.info("Player ready to play")
            if autoPlay {
                player?.play()
            }
            onReady?()
        case .failed:
            let error = item.error ?? PlayerError.unknown
            log.error("Player failed: \(String(describing: item.error))")
            log.error("ErrorLog: \(String(describing: item.errorLog()?.events))")
            onFailure?(error)
        default:
            break
        }
    }

    @objc private func failedToPlayToEnd(_ note: Notification) {
        if let error = (note.object as? AVPlayerItem)?.error {
            log.error("Failed to play to end: \(error.localizedDescription)")
            onFailure?(error)
        }
    }

    deinit {
        stop()
    }
}
