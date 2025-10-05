import CoreGraphics
import Foundation

public enum FreezeAnnotation: Codable, Hashable, Sendable {
    case shape(ShapeAnnotation)
    case text(TextAnnotation)
    case pen(PenAnnotation)
    case segMask(SegMaskAnnotation)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum Kind: String, Codable {
        case shape
        case text
        case pen
        case segMask
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .shape:
            let payload = try container.decode(ShapeAnnotation.self, forKey: .payload)
            self = .shape(payload)
        case .text:
            let payload = try container.decode(TextAnnotation.self, forKey: .payload)
            self = .text(payload)
        case .pen:
            let payload = try container.decode(PenAnnotation.self, forKey: .payload)
            self = .pen(payload)
        case .segMask:
            let payload = try container.decode(SegMaskAnnotation.self, forKey: .payload)
            self = .segMask(payload)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .shape(let annotation):
            try container.encode(Kind.shape, forKey: .type)
            try container.encode(annotation, forKey: .payload)
        case .text(let annotation):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(annotation, forKey: .payload)
        case .pen(let annotation):
            try container.encode(Kind.pen, forKey: .type)
            try container.encode(annotation, forKey: .payload)
        case .segMask(let annotation):
            try container.encode(Kind.segMask, forKey: .type)
            try container.encode(annotation, forKey: .payload)
        }
    }
}

public struct ShapeAnnotation: Codable, Hashable, Sendable {
    public enum ShapeKind: String, Codable, Hashable, Sendable {
        case rectangle
        case ellipse
        case arrow
        case polyline
    }

    public var id: UUID
    public var kind: ShapeKind
    public var rect: NormalizedRect
    public var points: [NormalizedPoint]

    public init(id: UUID = UUID(), kind: ShapeKind, rect: NormalizedRect, points: [NormalizedPoint] = []) {
        self.id = id
        self.kind = kind
        self.rect = rect
        self.points = points
    }
}

public struct TextAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var rect: NormalizedRect

    public init(id: UUID = UUID(), text: String, rect: NormalizedRect) {
        self.id = id
        self.text = text
        self.rect = rect
    }
}

public struct PenAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var points: [NormalizedPoint]
    public var strokeWidth: CGFloat

    public init(id: UUID = UUID(), points: [NormalizedPoint], strokeWidth: CGFloat) {
        self.id = id
        self.points = points
        self.strokeWidth = strokeWidth
    }
}

public struct SegMaskAnnotation: Codable, Hashable, Sendable {
    public var id: UUID
    public var width: Int
    public var height: Int
    public var rleMask: Data
    public var modelInfo: ModelInfo
    public var style: MaskStyle

    public init(id: UUID = UUID(), width: Int, height: Int, rleMask: Data, modelInfo: ModelInfo, style: MaskStyle = .highlight) {
        self.id = id
        self.width = width
        self.height = height
        self.rleMask = rleMask
        self.modelInfo = modelInfo
        self.style = style
    }
}

public struct ModelInfo: Codable, Hashable, Sendable {
    public var name: String
    public var version: String
    public var sha: String

    public init(name: String, version: String, sha: String) {
        self.name = name
        self.version = version
        self.sha = sha
    }
}

public enum MaskStyle: String, Codable, Hashable, Sendable {
    case highlight
    case outline
}
