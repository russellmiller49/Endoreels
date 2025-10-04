import AVFoundation
import Combine

final class VideoPlaybackCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case failed(String)

        static func == (lhs: VideoPlaybackCoordinator.State, rhs: VideoPlaybackCoordinator.State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.ready, .ready):
                return true
            case let (.failed(a), .failed(b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published private(set) var player: AVPlayer?
    @Published private(set) var state: State = .idle

    private let loader = SafeAssetLoader()
    private let playerOwner = PlayerOwner()
    private let watchdog = VideoLoadWatchdog()

    private var autoPlay = false
    private var readinessHandler: (() -> Void)?
    private var failureHandler: ((Error) -> Void)?

    func prepare(url: URL,
                 autoPlay: Bool = false,
                 timeout: TimeInterval = 8,
                 onReady: (() -> Void)? = nil,
                 onFailure: ((Error) -> Void)? = nil) {
        state = .loading
        player = nil
        self.autoPlay = autoPlay
        readinessHandler = onReady
        failureHandler = onFailure

        watchdog.start(timeout: timeout) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                let error = SafeAssetLoader.LoadError.timeout
                self.handleFailure(error)
            }
        }

        loader.load(url: url, timeout: timeout) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.watchdog.cancel()
                switch result {
                case .success(let asset):
                    self.attach(asset: asset)
                case .failure(let error):
                    self.handleFailure(error)
                }
            }
        }
    }

    func teardown() {
        watchdog.cancel()
        player?.pause()
        player = nil
        playerOwner.stop()
        state = .idle
    }

    private func attach(asset: AVURLAsset) {
        playerOwner.start(with: asset, autoPlay: autoPlay, onReady: { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.player = self.playerOwner.player
                self.state = .ready
                self.readinessHandler?()
            }
        }, onFailure: { [weak self] error in
            self?.handleFailure(error)
        })
    }

    private func handleFailure(_ error: Error) {
        watchdog.cancel()
        player?.pause()
        player = nil
        playerOwner.stop()
        let message = prettyMessage(for: error)
        state = .failed(message)
        failureHandler?(error)
    }

    private func prettyMessage(for error: Error) -> String {
        if let loadError = error as? SafeAssetLoader.LoadError {
            switch loadError {
            case .timeout:
                return "Video failed to become ready before timeout."
            case .missingFile:
                return "Video file could not be found."
            case .noTracks:
                return "Clip has no playable video tracks."
            case .badDuration:
                return "Clip duration is invalid."
            case .notPlayable:
                return "Clip is not playable on this device."
            }
        }
        return error.localizedDescription
    }
}
