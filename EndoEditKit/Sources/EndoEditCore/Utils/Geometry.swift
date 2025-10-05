import AVFoundation
import CoreGraphics
import Foundation

/// Represents a point in normalized coordinates (0...1) relative to the display space
/// after applying the asset's preferred transform.
public struct NormalizedPoint: Codable, Hashable, Sendable {
    public let x: CGFloat
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.0), 1.0)
    }
}

/// Represents a rectangle in normalized coordinates (0...1) relative to the display space
/// after applying the asset's preferred transform.
public struct NormalizedRect: Codable, Hashable, Sendable {
    public let origin: NormalizedPoint
    public let size: CGSize

    public var cgRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    public init(origin: NormalizedPoint, size: CGSize) {
        self.origin = origin
        self.size = NormalizedRect.clamp(size, respecting: origin)
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let origin = NormalizedPoint(x: x, y: y)
        let size = NormalizedRect.clamp(CGSize(width: width, height: height), respecting: origin)
        self.init(origin: origin, size: size)
    }

    private static func clamp(_ size: CGSize, respecting origin: NormalizedPoint) -> CGSize {
        let width = min(max(size.width, 0.0), 1.0 - origin.x)
        let height = min(max(size.height, 0.0), 1.0 - origin.y)
        return CGSize(width: width, height: height)
    }
}

public extension NormalizedRect {
    func rect(inWidth width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: origin.x * width,
               y: origin.y * height,
               width: size.width * width,
               height: size.height * height)
    }

    func sanitized() -> NormalizedRect {
        var clampedWidth = min(max(size.width, 0.0), 1.0)
        var clampedHeight = min(max(size.height, 0.0), 1.0)
        if clampedWidth <= 0.0 { clampedWidth = 1.0 }
        if clampedHeight <= 0.0 { clampedHeight = 1.0 }

        let clampedX = min(max(origin.x, 0.0), 1.0 - clampedWidth)
        let clampedY = min(max(origin.y, 0.0), 1.0 - clampedHeight)

        return NormalizedRect(origin: NormalizedPoint(x: clampedX, y: clampedY),
                              size: CGSize(width: clampedWidth, height: clampedHeight))
    }
}

/// Utility container used to encode/decode CMTime values.
public struct TimeValue: Codable, Hashable, Sendable {
    public let value: Int64
    public let timescale: Int32
    public let flags: UInt32
    public let epoch: Int64

    public init(_ time: CMTime) {
        self.value = time.value
        self.timescale = time.timescale
        self.flags = time.flags.rawValue
        self.epoch = time.epoch
    }

    public var cmTime: CMTime {
        CMTime(value: value, timescale: timescale, flags: CMTimeFlags(rawValue: flags), epoch: epoch)
    }
}

/// Utility container used to encode/decode CMTimeRange values.
public struct TimeRangeValue: Codable, Hashable, Sendable {
    public let start: TimeValue
    public let duration: TimeValue

    public init(_ timeRange: CMTimeRange) {
        self.start = TimeValue(timeRange.start)
        self.duration = TimeValue(timeRange.duration)
    }

    public var cmTimeRange: CMTimeRange {
        CMTimeRange(start: start.cmTime, duration: duration.cmTime)
    }
}
