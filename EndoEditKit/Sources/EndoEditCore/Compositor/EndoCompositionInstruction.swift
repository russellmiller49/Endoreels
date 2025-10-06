import AVFoundation

/// Instruction object consumed by the custom Metal-backed compositor.
public final class EndoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public let timeRange: CMTimeRange
    public let sourceTrackID: CMPersistentTrackID
    public let cropRect: NormalizedRect?
    public let freezeSegments: [FreezeSegment]
    public let imageGenerator: AVAssetImageGenerator?

    public var enablePostProcessing: Bool = false
    public var containsTweening: Bool = false
    public var requiredSourceTrackIDs: [NSValue]?
    public var passthroughTrackID: CMPersistentTrackID

    public init(timeRange: CMTimeRange,
                sourceTrackID: CMPersistentTrackID,
                cropRect: NormalizedRect?,
                freezeSegments: [FreezeSegment],
                imageGenerator: AVAssetImageGenerator?) {
        self.timeRange = timeRange
        self.sourceTrackID = sourceTrackID
        self.cropRect = cropRect
        self.freezeSegments = freezeSegments
        self.imageGenerator = imageGenerator
        self.passthroughTrackID = sourceTrackID
        self.requiredSourceTrackIDs = [NSNumber(value: sourceTrackID)]
        super.init()
    }

    public var requiredSourceSampleDataTrackIDs: [NSNumber] {
        []
    }
}
