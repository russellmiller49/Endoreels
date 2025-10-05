import AVFoundation
import CoreGraphics
import Foundation

/// Represents a compliance-grade redact bar that spans the full width of the frame.
public struct CeilingRedact: Codable, Hashable, Sendable {
    public private(set) var heightFraction: CGFloat
    public var activeTime: CMTimeRange

    public init(heightFraction: CGFloat = 0.15, activeTime: CMTimeRange) {
        self.heightFraction = Self.clamp(heightFraction)
        self.activeTime = activeTime
    }

    private enum CodingKeys: String, CodingKey {
        case heightFraction
        case activeTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.heightFraction = Self.clamp(try container.decode(CGFloat.self, forKey: .heightFraction))
        let range = try container.decode(TimeRangeValue.self, forKey: .activeTime)
        self.activeTime = range.cmTimeRange
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(heightFraction, forKey: .heightFraction)
        try container.encode(TimeRangeValue(activeTime), forKey: .activeTime)
    }

    public mutating func updateHeightFraction(_ newValue: CGFloat) {
        self.heightFraction = Self.clamp(newValue)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.0), 1.0)
    }
}
