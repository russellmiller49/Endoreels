import Foundation

public enum TimelineError: Error {
    case invalidRange
    case missingAsset
    case exportInProgress
}

public struct MediaAsset: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var uri: URL
    public var duration: TimeInterval
    public var frameRate: Double
    public var createdAt: Date
    public var proxyURL: URL?
    public var thumbnailSpriteURL: URL?
    public var waveformURL: URL?

    public init(id: UUID = UUID(),
                uri: URL,
                duration: TimeInterval,
                frameRate: Double,
                createdAt: Date = .now,
                proxyURL: URL? = nil,
                thumbnailSpriteURL: URL? = nil,
                waveformURL: URL? = nil) {
        self.id = id
        self.uri = uri
        self.duration = duration.finiteOrZero
        self.frameRate = frameRate
        self.createdAt = createdAt
        self.proxyURL = proxyURL
        self.thumbnailSpriteURL = thumbnailSpriteURL
        self.waveformURL = waveformURL
    }
}

extension MediaAsset {
    private enum CodingKeys: String, CodingKey {
        case id
        case uri
        case duration
        case frameRate
        case createdAt
        case proxyURL
        case thumbnailSpriteURL
        case waveformURL
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uri.absoluteString, forKey: .uri)
        try container.encode(duration, forKey: .duration)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
        try container.encodeIfPresent(proxyURL?.absoluteString, forKey: .proxyURL)
        try container.encodeIfPresent(thumbnailSpriteURL?.absoluteString, forKey: .thumbnailSpriteURL)
        try container.encodeIfPresent(waveformURL?.absoluteString, forKey: .waveformURL)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        let uriString = try container.decode(String.self, forKey: .uri)
        self.uri = try MediaAsset.resolveURL(from: uriString)
        let rawDuration = try container.decode(TimeInterval.self, forKey: .duration)
        self.duration = rawDuration.finiteOrZero
        self.frameRate = try container.decode(Double.self, forKey: .frameRate)
        let createdAtInterval = try container.decode(TimeInterval.self, forKey: .createdAt)
        self.createdAt = Date(timeIntervalSince1970: createdAtInterval)
        if let proxyString = try container.decodeIfPresent(String.self, forKey: .proxyURL) {
            self.proxyURL = try MediaAsset.resolveURL(from: proxyString)
        } else {
            self.proxyURL = nil
        }
        if let spriteString = try container.decodeIfPresent(String.self, forKey: .thumbnailSpriteURL) {
            self.thumbnailSpriteURL = try MediaAsset.resolveURL(from: spriteString)
        } else {
            self.thumbnailSpriteURL = nil
        }
        if let waveformString = try container.decodeIfPresent(String.self, forKey: .waveformURL) {
            self.waveformURL = try MediaAsset.resolveURL(from: waveformString)
        } else {
            self.waveformURL = nil
        }
    }

    private static func resolveURL(from string: String) throws -> URL {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}

public struct Marker: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var time_s: TimeInterval
    public var label: String

    public init(id: UUID = UUID(), time_s: TimeInterval, label: String) {
        self.id = id
        self.time_s = time_s
        self.label = label
    }
}

public struct Segment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var assetID: UUID
    public var start_s: TimeInterval
    public var end_s: TimeInterval
    public var speed: Double
    public var label: String
    public var markers: [Marker]

    public init(id: UUID = UUID(),
                assetID: UUID,
                start_s: TimeInterval,
                end_s: TimeInterval,
                speed: Double = 1.0,
                label: String,
                markers: [Marker] = []) {
        self.id = id
        self.assetID = assetID
        self.start_s = start_s
        self.end_s = end_s
        self.speed = speed
        self.label = label
        self.markers = markers
    }
}

public struct Timeline: Identifiable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var difficulty: String
    public var segmentOrder: [UUID]

    public init(id: UUID = UUID(), title: String, difficulty: String, segmentOrder: [UUID] = []) {
        self.id = id
        self.title = title
        self.difficulty = difficulty
        self.segmentOrder = segmentOrder
    }
}

public struct Draft: Identifiable, Codable, Sendable {
    public var id: UUID
    public var asset: MediaAsset
    public var segments: [UUID: Segment]
    public var timeline: Timeline
    public var playhead_s: TimeInterval
    public var zoomLevel: Double
    public var selectedSegmentID: UUID?
    public var updatedAt: Date

    public init(id: UUID = UUID(),
                asset: MediaAsset,
                segments: [UUID: Segment],
                timeline: Timeline,
                playhead_s: TimeInterval = 0,
                zoomLevel: Double = 1.0,
                selectedSegmentID: UUID? = nil,
                updatedAt: Date = .now) {
        self.id = id
        self.asset = asset
        self.segments = segments
        self.timeline = timeline
        // Sanitize playhead to prevent NaN in layout
        self.playhead_s = playhead_s.isFinite ? max(playhead_s, 0) : 0
        self.zoomLevel = zoomLevel.isFinite ? max(zoomLevel, 0.1) : 1.0
        self.selectedSegmentID = selectedSegmentID
        self.updatedAt = updatedAt
    }
}

extension Draft {
    private enum CodingKeys: String, CodingKey {
        case id
        case asset
        case segments
        case timeline
        case playhead_s
        case zoomLevel
        case selectedSegmentID
        case updatedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(asset, forKey: .asset)
        try container.encode(segments, forKey: .segments)
        try container.encode(timeline, forKey: .timeline)
        try container.encode(playhead_s, forKey: .playhead_s)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encodeIfPresent(selectedSegmentID, forKey: .selectedSegmentID)
        try container.encode(updatedAt.timeIntervalSince1970, forKey: .updatedAt)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.asset = try container.decode(MediaAsset.self, forKey: .asset)
        self.segments = try container.decode([UUID: Segment].self, forKey: .segments)
        self.timeline = try container.decode(Timeline.self, forKey: .timeline)

        // Sanitize decoded values to prevent NaN propagation
        let decodedPlayhead = try container.decode(TimeInterval.self, forKey: .playhead_s)
        self.playhead_s = decodedPlayhead.isFinite ? max(decodedPlayhead, 0) : 0

        let decodedZoom = try container.decode(Double.self, forKey: .zoomLevel)
        self.zoomLevel = decodedZoom.isFinite ? max(decodedZoom, 0.1) : 1.0

        self.selectedSegmentID = try container.decodeIfPresent(UUID.self, forKey: .selectedSegmentID)
        let updatedAtInterval = try container.decode(TimeInterval.self, forKey: .updatedAt)
        self.updatedAt = Date(timeIntervalSince1970: updatedAtInterval)
    }
}

public struct DraftDelta: Codable, Sendable {
    public var timestamp: Date
    public var description: String
    public var patchData: Data

    public init(timestamp: Date = .now, description: String, patchData: Data) {
        self.timestamp = timestamp
        self.description = description
        self.patchData = patchData
    }
}

extension DraftDelta {
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case description
        case patchData
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(patchData, forKey: .patchData)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let interval = try container.decode(TimeInterval.self, forKey: .timestamp)
        self.timestamp = Date(timeIntervalSince1970: interval)
        self.description = try container.decode(String.self, forKey: .description)
        self.patchData = try container.decode(Data.self, forKey: .patchData)
    }
}
