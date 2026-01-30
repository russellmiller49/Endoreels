import AVFoundation
import CoreGraphics

#if os(iOS)

public enum EndoEditorEngineError: Error {
    case missingVideoTrack
    case invalidDuration
}

/// High level façade around the video editor pipeline. For now it only produces a
/// pass-through preview item using the custom compositor. Subsequent steps will add
/// freeze frames, overlays, and export plumbing.
public final class EndoEditorEngine {
    public let asset: AVAsset
    public var editGraph: EditGraph

    public init(asset: AVAsset, editGraph: EditGraph = .empty) {
        self.asset = asset
        self.editGraph = editGraph
    }

    public convenience init(url: URL, editGraph: EditGraph = .empty) {
        let asset = AVURLAsset(url: url)
        self.init(asset: asset, editGraph: editGraph)
    }

    /// Builds an `AVPlayerItem` that renders through the custom compositor. The compositor is
    /// currently pass-through but sharing the same path for preview and export keeps the
    /// architecture ready for later augmentation.
    @MainActor
    public func makePreviewPlayerItem() async throws -> AVPlayerItem {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            print("❌ VideoEditorEngine: No video track found")
            throw EndoEditorEngineError.missingVideoTrack
        }

        let trackTimeRange = try await videoTrack.load(.timeRange)
        let rawDuration = try await asset.load(.duration)

        let durationSeconds = rawDuration.sanitizedSeconds
            ?? trackTimeRange.duration.sanitizedSeconds

        guard let safeDurationSeconds = durationSeconds, safeDurationSeconds > 0 else {
            print("❌ VideoEditorEngine: Unable to determine a finite asset duration. raw=\(rawDuration), trackRange=\(trackTimeRange)")
            throw EndoEditorEngineError.invalidDuration
        }

        let preferredTimescale: CMTimeScale
        if rawDuration.timescale > 0 {
            preferredTimescale = rawDuration.timescale
        } else if trackTimeRange.duration.timescale > 0 {
            preferredTimescale = trackTimeRange.duration.timescale
        } else {
            preferredTimescale = 600
        }

        let duration = CMTime(seconds: safeDurationSeconds, preferredTimescale: preferredTimescale)
        print("🎬 VideoEditorEngine: duration=\(duration)")

        let summary = GraphSummary(from: editGraph, assetDuration: duration)
        let sanitizedCropRect: NormalizedRect?
        if let rect = summary.cropRect {
            let sanitizedRect = rect.sanitized()
            if sanitizedRect.isValidNormalized {
                sanitizedCropRect = sanitizedRect
            } else {
                print("⚠️ VideoEditorEngine: Ignoring crop rect with non-finite values=\(sanitizedRect)")
                sanitizedCropRect = nil
            }
        } else {
            sanitizedCropRect = nil
        }
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)
        var preferredTransform = try await videoTrack.load(.preferredTransform)

        if preferredTransform.isFinite == false {
            print("⚠️ VideoEditorEngine: preferredTransform contains non-finite values. Falling back to identity. transform=\(preferredTransform)")
            preferredTransform = .identity
        }

        print("🎬 VideoEditorEngine: frameRate=\(frameRate), naturalSize=\(naturalSize)")
        print("🎬 VideoEditorEngine: naturalSize.width.isFinite=\(naturalSize.width.isFinite), naturalSize.height.isFinite=\(naturalSize.height.isFinite)")

        // Critical check: ensure natural size is valid before proceeding
        guard naturalSize.width.isFinite, naturalSize.height.isFinite,
              naturalSize.width > 0, naturalSize.height > 0 else {
            print("❌ VideoEditorEngine: Invalid naturalSize=\(naturalSize)")
            throw EndoEditorEngineError.missingVideoTrack
        }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        let timeRange = CMTimeRange(start: .zero, duration: duration)
        let instruction = EndoCompositionInstruction(
            timeRange: timeRange,
            sourceTrackID: videoTrack.trackID,
            cropRect: sanitizedCropRect,
            freezeSegments: summary.freezeSegments,
            imageGenerator: imageGenerator
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = EndoCompositor.self
        videoComposition.instructions = [instruction]

        let framesPerSecond = frameRate > 0 ? frameRate : 30
        let timescale = CMTimeScale(max(1, Int(round(framesPerSecond))))
        videoComposition.frameDuration = CMTime(value: 1, timescale: timescale)

        let transformedSize = naturalSize.applying(preferredTransform)
        let safeWidthSource = transformedSize.width.isFinite ? transformedSize.width : naturalSize.width
        let safeHeightSource = transformedSize.height.isFinite ? transformedSize.height : naturalSize.height
        print("🎬 VideoEditorEngine: naturalSize=\(naturalSize), transform=\(preferredTransform), transformed=\(transformedSize), safeComponents=(\(safeWidthSource), \(safeHeightSource))")

        let baseWidth = sanitize(abs(safeWidthSource), min: 1)
        let baseHeight = sanitize(abs(safeHeightSource), min: 1)
        print("🎬 VideoEditorEngine: baseWidth=\(baseWidth), baseHeight=\(baseHeight)")

        let finalRenderSize: CGSize
        if let crop = sanitizedCropRect {
            print("🎬 VideoEditorEngine: crop rect=\(crop)")
            let cropWidth = sanitize(crop.size.width, min: 0.1, max: 1.0)
            let cropHeight = sanitize(crop.size.height, min: 0.1, max: 1.0)
            let width = sanitize(baseWidth * cropWidth, min: 1)
            let height = sanitize(baseHeight * cropHeight, min: 1)
            finalRenderSize = CGSize(width: width, height: height)
            print("🎬 VideoEditorEngine: finalRenderSize (cropped)=\(finalRenderSize)")
        } else {
            finalRenderSize = CGSize(width: baseWidth, height: baseHeight)
            print("🎬 VideoEditorEngine: finalRenderSize (uncropped)=\(finalRenderSize)")
        }

        if finalRenderSize.width.isFinite == false || finalRenderSize.height.isFinite == false || finalRenderSize.width <= 0 || finalRenderSize.height <= 0 {
            print("⚠️ VideoEditorEngine: Invalid renderSize computed=\(finalRenderSize). Resetting to base dimensions.")
            videoComposition.renderSize = CGSize(width: baseWidth, height: baseHeight)
        } else {
            videoComposition.renderSize = finalRenderSize
        }

        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = videoComposition
        return playerItem
    }
}

private struct GraphSummary {
    var cropRect: NormalizedRect?
    var freezeSegments: [FreezeSegment]

    init(from graph: EditGraph, assetDuration: CMTime) {
        var crop: NormalizedRect?
        var freezes: [FreezeSegment] = []

        for operation in graph.operations {
            switch operation {
            case .crop(let cropOp):
                let sanitizedRect = cropOp.sanitized().rect.sanitized()
                if sanitizedRect.isValidNormalized {
                    crop = sanitizedRect
                } else {
                    print("⚠️ VideoEditorEngine: Ignoring invalid crop rect=\(sanitizedRect)")
                }
            case .freeze(let segment):
                let sanitizedSegment = segment.sanitized(maxDuration: assetDuration)
                if sanitizedSegment.isValid(maxDuration: assetDuration) {
                    freezes.append(sanitizedSegment)
                } else {
                    print("⚠️ VideoEditorEngine: Ignoring invalid freeze segment id=\(segment.id)")
                }
            default:
                continue
            }
        }

        if let crop {
            self.cropRect = crop
        } else {
            self.cropRect = nil
        }
        self.freezeSegments = freezes.sorted { $0.start < $1.start }
    }
}

private func sanitize(_ value: CGFloat, min minValue: CGFloat = 0, max maxValue: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
    guard value.isFinite else { return minValue }
    return Swift.min(Swift.max(value, minValue), maxValue)
}
#endif
