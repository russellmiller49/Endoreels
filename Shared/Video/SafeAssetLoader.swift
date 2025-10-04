import Foundation
import AVFoundation
import CoreGraphics

final class SafeAssetLoader {
    enum LoadError: Error {
        case notPlayable
        case noTracks
        case badDuration
        case timeout
        case missingFile
    }

    func load(url: URL,
              timeout: TimeInterval = 8.0,
              completion: @escaping (Result<AVURLAsset, Error>) -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(.failure(LoadError.missingFile))
            return
        }

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        var loadTask: Task<Void, Never>?
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            loadTask?.cancel()
            await MainActor.run { completion(.failure(LoadError.timeout)) }
        }

        loadTask = Task(priority: .userInitiated) { @MainActor in
            do {
                try Task.checkCancellation()

                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else { throw LoadError.notPlayable }

                let durationTime = try await asset.load(.duration)
                guard let durationSeconds = durationTime.sanitizedSeconds, durationSeconds > 0.01 else {
                    throw LoadError.badDuration
                }

                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else { throw LoadError.noTracks }

                let naturalSize = try await track.load(.naturalSize)
                let preferredTransform = try await track.load(.preferredTransform)
                let transformed = naturalSize.applying(preferredTransform)
                _ = safeSize(max(1, abs(transformed.width).finite),
                             max(1, abs(transformed.height).finite),
                             fallback: CGSize(width: 1, height: 1))

                try Task.checkCancellation()

                timeoutTask.cancel()
                completion(.success(asset))
            } catch is CancellationError {
                // Swallow cancellation; timeout handler will notify if needed.
            } catch let loadError as LoadError {
                timeoutTask.cancel()
                completion(.failure(loadError))
            } catch {
                timeoutTask.cancel()
                completion(.failure(error))
            }
        }
    }
}
