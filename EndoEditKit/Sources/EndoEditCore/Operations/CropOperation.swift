import Foundation

/// Describes a normalized crop rectangle applied to the whole asset.
public struct CropOperation: Codable, Hashable, Sendable {
    public var rect: NormalizedRect

    public init(rect: NormalizedRect) {
        self.rect = rect
    }

    public func sanitized() -> CropOperation {
        CropOperation(rect: rect.sanitized())
    }
}
