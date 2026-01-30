import AVFoundation
import Foundation

/// Describes a freeze-frame segment in the edit graph.
public struct FreezeSegment: Codable, Hashable, Sendable {
    public var id: UUID
    public var start: CMTime
    public var duration: CMTime
    public var sourceTime: CMTime
    public var annotations: [FreezeAnnotation]

    public init(id: UUID = UUID(), start: CMTime, duration: CMTime, sourceTime: CMTime, annotations: [FreezeAnnotation] = []) {
        self.id = id
        self.start = start
        self.duration = duration
        self.sourceTime = sourceTime
        self.annotations = annotations
    }

    public var timeRange: CMTimeRange {
        CMTimeRange(start: start, duration: duration)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case start
        case duration
        case sourceTime
        case annotations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.start = try container.decode(TimeValue.self, forKey: .start).cmTime
        self.duration = try container.decode(TimeValue.self, forKey: .duration).cmTime
        self.sourceTime = try container.decode(TimeValue.self, forKey: .sourceTime).cmTime
        self.annotations = try container.decode([FreezeAnnotation].self, forKey: .annotations)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(TimeValue(start), forKey: .start)
        try container.encode(TimeValue(duration), forKey: .duration)
        try container.encode(TimeValue(sourceTime), forKey: .sourceTime)
        try container.encode(annotations, forKey: .annotations)
    }

    public func sanitized(maxDuration: CMTime) -> FreezeSegment {
        let maxSeconds = sanitize(CMTimeGetSeconds(maxDuration)).clamped(to: 0...Double.greatestFiniteMagnitude)

        let startSeconds = sanitize(CMTimeGetSeconds(start)).clamped(to: 0...maxSeconds)
        let rawDuration = sanitize(CMTimeGetSeconds(duration))
        let clampedDuration = min(max(rawDuration, 0.1), max(maxSeconds - startSeconds, 0.1))

        let sanitizedStart = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let sanitizedDuration = CMTime(seconds: clampedDuration, preferredTimescale: 600)
        let sanitizedSource = sanitizedStart

        return FreezeSegment(id: id,
                             start: sanitizedStart,
                             duration: sanitizedDuration,
                             sourceTime: sanitizedSource,
                             annotations: annotations)
    }

    public func isValid(maxDuration: CMTime, tolerance: Double = 1e-3) -> Bool {
        guard let maxSeconds = maxDuration.sanitizedSeconds else { return false }
        guard let startSeconds = start.sanitizedSeconds else { return false }
        guard let durationSeconds = duration.sanitizedSeconds, durationSeconds > 0 else { return false }
        guard let sourceSeconds = sourceTime.sanitizedSeconds else { return false }

        if startSeconds < 0 || sourceSeconds < 0 { return false }
        if startSeconds > maxSeconds + tolerance { return false }
        if sourceSeconds > maxSeconds + tolerance { return false }

        return startSeconds + durationSeconds <= maxSeconds + tolerance
    }
}

private extension FreezeSegment {
    func sanitize(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return value
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
