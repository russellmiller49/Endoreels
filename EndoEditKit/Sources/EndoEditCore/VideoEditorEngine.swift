import AVFoundation
import CoreGraphics

#if os(iOS)

public enum EndoEditorEngineError: Error {
    case missingVideoTrack
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
            throw EndoEditorEngineError.missingVideoTrack
        }

        let summary = GraphSummary(from: editGraph, assetDuration: duration)

        let duration = try await asset.load(.duration)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        let timeRange = CMTimeRange(start: .zero, duration: duration)
        let instruction = EndoCompositionInstruction(
            timeRange: timeRange,
            sourceTrackID: videoTrack.trackID,
            cropRect: summary.cropRect,
            freezeSegments: summary.freezeSegments
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = EndoCompositor.self
        videoComposition.instructions = [instruction]

        let framesPerSecond = frameRate > 0 ? frameRate : 30
        let timescale = CMTimeScale(max(1, Int(round(framesPerSecond))))
        videoComposition.frameDuration = CMTime(value: 1, timescale: timescale)

        let transformedSize = naturalSize.applying(preferredTransform)
        let baseWidth = abs(transformedSize.width)
        let baseHeight = abs(transformedSize.height)
        if let crop = summary.cropRect {
            videoComposition.renderSize = CGSize(width: baseWidth * crop.size.width,
                                                height: baseHeight * crop.size.height)
        } else {
            videoComposition.renderSize = CGSize(width: baseWidth, height: baseHeight)
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
                crop = cropOp.sanitized().rect
            case .freeze(let segment):
                freezes.append(segment.sanitized(maxDuration: assetDuration))
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
#endif
