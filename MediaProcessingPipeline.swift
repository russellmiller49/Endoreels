import Foundation
import AVFoundation
import Accelerate
import UIKit

public struct MediaProxy {
    public var proxyURL: URL
    public var thumbnailSpriteURL: URL
    public var waveformURL: URL
}

public final class MediaProcessingPipeline {
    private let fileManager: FileManager
    private let tempDirectory: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.temporaryDirectory.appendingPathComponent("EndoReelsMediaProxy", isDirectory: true)
        tempDirectory = base
        ensureTempDirectory()
    }

    public func generateProxy(for original: URL) async throws -> URL {
        // Validate file exists and is accessible
        guard fileManager.fileExists(atPath: original.path) else {
            throw NSError(domain: "MediaProcessingPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found: \(original.path)"])
        }
        
        let asset = AVURLAsset(url: original)
        
        // Add timeout and error handling for asset loading
        do {
            _ = try await asset.load(.duration)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard videoTracks.isEmpty == false else {
                throw NSError(domain: "MediaProcessingPipeline", code: -2, userInfo: [NSLocalizedDescriptionKey: "Asset has no video track"])
            }
        } catch {
            print("❌ Failed to load asset: \(error.localizedDescription)")
            throw NSError(domain: "MediaProcessingPipeline", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to load video asset: \(error.localizedDescription)"])
        }

        let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).mp4")
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        do {
            if #available(iOS 18, *) {
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                    throw NSError(domain: "MediaProcessingPipeline", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"])
                }
                try await exportSession.export(to: outputURL, as: .mp4)
            } else {
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
                    throw NSError(domain: "MediaProcessingPipeline", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"])
                }
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    nonisolated(unsafe) let session = exportSession
                    session.exportAsynchronously {
                        switch session.status {
                        case .completed:
                            continuation.resume(returning: ())
                        case .failed, .cancelled:
                            let error = session.error ?? NSError(domain: "MediaProcessingPipeline", code: -4, userInfo: [NSLocalizedDescriptionKey: "Proxy export failed"])
                            continuation.resume(throwing: error)
                        default:
                            break
                        }
                    }
                }
            }
        } catch {
            print("❌ Proxy generation failed: \(error.localizedDescription)")
            throw NSError(domain: "MediaProcessingPipeline", code: -4, userInfo: [NSLocalizedDescriptionKey: "Proxy generation failed: \(error.localizedDescription)"])
        }

        return outputURL
    }

    public func generateThumbnailSprite(for assetURL: URL, frameIntervalSeconds: Double = 2.0) async throws -> URL {
        // Validate file exists and is accessible
        guard fileManager.fileExists(atPath: assetURL.path) else {
            throw NSError(domain: "MediaProcessingPipeline", code: -5, userInfo: [NSLocalizedDescriptionKey: "Video file not found: \(assetURL.path)"])
        }
        
        let asset = AVURLAsset(url: assetURL)
        var durationSeconds: Double = 0
        
        do {
            let duration = try await asset.load(.duration)
            durationSeconds = CMTimeGetSeconds(duration)
            guard durationSeconds.isFinite, durationSeconds > 0 else {
                throw NSError(domain: "MediaProcessingPipeline", code: -5, userInfo: [NSLocalizedDescriptionKey: "Asset duration unavailable"])
            }
        } catch {
            print("❌ Failed to load asset for thumbnails: \(error.localizedDescription)")
            throw NSError(domain: "MediaProcessingPipeline", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unable to load video asset for thumbnails: \(error.localizedDescription)"])
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let frameInterval = max(frameIntervalSeconds, 0.5)
        let frameCount = max(1, Int(ceil(durationSeconds / frameInterval)))
        var images: [CGImage] = []
        images.reserveCapacity(frameCount)

        if #available(iOS 18, *) {
            for index in 0..<frameCount {
                let seconds = min(Double(index) * frameInterval, durationSeconds)
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                let image = try await generateImageAsync(generator: generator, time: time)
                images.append(image)
            }
            if images.isEmpty {
                let fallback = try await generateImageAsync(generator: generator, time: .zero)
                images.append(fallback)
            }
        } else {
            for index in 0..<frameCount {
                let seconds = min(Double(index) * frameInterval, durationSeconds)
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                do {
                    let image = try generator.copyCGImage(at: time, actualTime: nil)
                    images.append(image)
                } catch {
                    continue
                }
            }
            if images.isEmpty, let fallback = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                images.append(fallback)
            }
        }

        guard let firstImage = images.first else {
            throw NSError(domain: "MediaProcessingPipeline", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unable to capture frames for sprite"])
        }

        let columns = min(4, images.count)
        let rows = Int(ceil(Double(images.count) / Double(columns)))
        let baseWidth = CGFloat(firstImage.width)
        let baseHeight = CGFloat(firstImage.height)
        let targetWidth: CGFloat = min(320, baseWidth)
        let scale = targetWidth / baseWidth
        let tileSize = CGSize(width: targetWidth, height: baseHeight * scale)

        let rendererSize = CGSize(width: tileSize.width * CGFloat(columns),
                                  height: tileSize.height * CGFloat(rows))

        let renderer = UIGraphicsImageRenderer(size: rendererSize, format: UIGraphicsImageRendererFormat.default())
        let spriteImage = renderer.image { context in
            for (index, cgImage) in images.enumerated() {
                let column = index % columns
                let row = index / columns
                let origin = CGPoint(x: CGFloat(column) * tileSize.width,
                                     y: CGFloat(row) * tileSize.height)
                let rect = CGRect(origin: origin, size: tileSize)
                UIImage(cgImage: cgImage).draw(in: rect)
            }
        }

        let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).png")
        if let data = spriteImage.pngData() {
            try data.write(to: outputURL, options: [.atomic])
            return outputURL
        } else {
            throw NSError(domain: "MediaProcessingPipeline", code: -7, userInfo: [NSLocalizedDescriptionKey: "Failed to encode sprite image"])
        }
    }

    public func generateWaveform(for assetURL: URL, sampleWindow: Int = 1024) async throws -> URL {
        // Validate file exists and is accessible
        guard fileManager.fileExists(atPath: assetURL.path) else {
            throw NSError(domain: "MediaProcessingPipeline", code: -8, userInfo: [NSLocalizedDescriptionKey: "Video file not found: \(assetURL.path)"])
        }
        
        let asset = AVURLAsset(url: assetURL)
        
        do {
            let tracks = try await asset.load(.tracks)
            if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
                return try await buildWaveform(for: asset, track: audioTrack, sampleWindow: sampleWindow)
            } else {
                // No audio track, return empty waveform
                let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).json")
                let emptyData = Data("[]".utf8)
                try emptyData.write(to: outputURL, options: [.atomic])
                return outputURL
            }
        } catch {
            print("❌ Failed to load asset for waveform: \(error.localizedDescription)")
            // Return empty waveform on error
            let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).json")
            let emptyData = Data("[]".utf8)
            try emptyData.write(to: outputURL, options: [.atomic])
            return outputURL
        }
    }

    private func buildWaveform(for asset: AVAsset, track: AVAssetTrack, sampleWindow: Int) async throws -> URL {
        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "MediaProcessingPipeline", code: -9, userInfo: [NSLocalizedDescriptionKey: "Unable to start audio reader"])
        }

        var samples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                data.withUnsafeMutableBytes { pointer in
                    guard let baseAddress = pointer.baseAddress else { return }
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
                }
                data.withUnsafeBytes { buffer in
                    let floatBuffer = buffer.bindMemory(to: Float.self)
                    samples.append(contentsOf: floatBuffer)
                }
            }
            CMSampleBufferInvalidate(sampleBuffer)
        }

        guard reader.status == .completed else {
            throw reader.error ?? NSError(domain: "MediaProcessingPipeline", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to read audio samples"])
        }

        if samples.isEmpty {
            let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).json")
            let emptyData = Data("[]".utf8)
            try emptyData.write(to: outputURL, options: [.atomic])
            return outputURL
        }

        let windowSize = max(sampleWindow, 256)
        var rmsBuckets: [Float] = []
        rmsBuckets.reserveCapacity(samples.count / windowSize)

        var index = 0
        while index < samples.count {
            let end = Swift.min(index + windowSize, samples.count)
            let slice = samples[index..<end]
            var rms: Float = 0
            let chunk = Array(slice)
            chunk.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                vDSP_rmsqv(baseAddress, 1, &rms, vDSP_Length(buffer.count))
            }
            rmsBuckets.append(rms)
            index = end
        }

        if let maxValue = rmsBuckets.max(), maxValue > 0 {
            var mutableBuckets = rmsBuckets
            var maxValueCopy = maxValue
            vDSP_vsdiv(mutableBuckets, 1, &maxValueCopy, &mutableBuckets, 1, vDSP_Length(mutableBuckets.count))
            rmsBuckets = mutableBuckets
        }

        let outputURL = makeTemporaryURL(filename: "\(UUID().uuidString).json")
        let json = try JSONSerialization.data(withJSONObject: rmsBuckets, options: [])
        try json.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    private func ensureTempDirectory() {
        if !fileManager.fileExists(atPath: tempDirectory.path) {
            try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var directoryURL = tempDirectory
        try? directoryURL.setResourceValues(resourceValues)
    }

    public func makeTemporaryURL(filename: String) -> URL {
        tempDirectory.appendingPathComponent(filename)
    }

    @available(iOS 18, *)
    private func generateImageAsync(generator: AVAssetImageGenerator, time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: NSError(domain: "MediaProcessingPipeline", code: -11, userInfo: [NSLocalizedDescriptionKey: "Image generation returned nil"]))
                }
            }
        }
    }
}

