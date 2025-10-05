import Foundation

public struct EditGraph: Codable, Hashable, Sendable {
    public static let schemaVersion = 1

    public var version: Int
    public var operations: [EditOperation]

    public init(version: Int = EditGraph.schemaVersion, operations: [EditOperation] = []) {
        self.version = version
        self.operations = operations
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case operations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? EditGraph.schemaVersion
        self.operations = try container.decode([EditOperation].self, forKey: .operations)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(operations, forKey: .operations)
    }
}

public extension EditGraph {
    static let empty = EditGraph()
}

public enum EditOperation: Codable, Hashable, Sendable {
    case freeze(FreezeSegment)
    case redact(RedactOverlay)
    case ceiling(CeilingRedact)
    case crop(CropOperation)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum Kind: String, Codable {
        case freeze
        case redact
        case ceiling
        case crop
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .freeze:
            let segment = try container.decode(FreezeSegment.self, forKey: .payload)
            self = .freeze(segment)
        case .redact:
            let overlay = try container.decode(RedactOverlay.self, forKey: .payload)
            self = .redact(overlay)
        case .ceiling:
            let ceiling = try container.decode(CeilingRedact.self, forKey: .payload)
            self = .ceiling(ceiling)
        case .crop:
            let crop = try container.decode(CropOperation.self, forKey: .payload)
            self = .crop(crop)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .freeze(let segment):
            try container.encode(Kind.freeze, forKey: .type)
            try container.encode(segment, forKey: .payload)
        case .redact(let overlay):
            try container.encode(Kind.redact, forKey: .type)
            try container.encode(overlay, forKey: .payload)
        case .ceiling(let ceiling):
            try container.encode(Kind.ceiling, forKey: .type)
            try container.encode(ceiling, forKey: .payload)
        case .crop(let crop):
            try container.encode(Kind.crop, forKey: .type)
            try container.encode(crop, forKey: .payload)
        }
    }
}
