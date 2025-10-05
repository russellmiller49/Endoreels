import AVFoundation
import CoreGraphics
import Foundation

public enum RedactStyle: String, Codable, Hashable, Sendable {
    case solidBlack
}

/// Describes a user-defined redact overlay. The rect is stored in normalized coordinates
/// to ensure non-destructive edits regardless of render resolution.
public struct RedactOverlay: Codable, Hashable, Sendable {
    public var id: UUID
    public var rect: NormalizedRect
    public var activeTime: CMTimeRange
    public var style: RedactStyle

    public init(id: UUID = UUID(), rect: NormalizedRect, activeTime: CMTimeRange, style: RedactStyle = .solidBlack) {
        self.id = id
        self.rect = rect
        self.activeTime = activeTime
        self.style = style
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rect
        case activeTime
        case style
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.rect = try container.decode(NormalizedRect.self, forKey: .rect)
        let range = try container.decode(TimeRangeValue.self, forKey: .activeTime)
        self.activeTime = range.cmTimeRange
        self.style = try container.decode(RedactStyle.self, forKey: .style)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(rect, forKey: .rect)
        try container.encode(TimeRangeValue(activeTime), forKey: .activeTime)
        try container.encode(style, forKey: .style)
    }
}
