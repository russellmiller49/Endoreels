import Foundation

public struct NormalizedRect: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: UUID = UUID(), x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func clamped() -> NormalizedRect {
        var rect = self
        rect.width = min(max(rect.width, 0.05), 1)
        rect.height = min(max(rect.height, 0.05), 1)
        rect.x = min(max(rect.x, 0), 1 - rect.width)
        rect.y = min(max(rect.y, 0), 1 - rect.height)
        return rect
    }
}

struct StepDraft: Identifiable {
    var id: UUID
    var order: Int
    var media: ImportedMediaAsset

    var stepTitle: String
    var keyLearningPoint: String

    /// Crop/zoom transform applied to the step canvas.
    /// `cropOffsetX/Y` are normalized (0…1) relative to the canvas size.
    /// A value of `0` means centered.
    var cropScale: Double
    var cropOffsetX: Double
    var cropOffsetY: Double

    var annotations: [TimedAnnotation]
    var narrationPath: String?
    var manualBlurRects: [NormalizedRect]

    var trimRange: ClosedRange<Double>? {
        get { media.trimRange }
        set { media.trimRange = newValue }
    }

    init(order: Int,
         media: ImportedMediaAsset,
         stepTitle: String? = nil,
         keyLearningPoint: String = "",
         cropScale: Double = 1,
         cropOffsetX: Double = 0,
         cropOffsetY: Double = 0,
         annotations: [TimedAnnotation] = [],
         narrationPath: String? = nil,
         manualBlurRects: [NormalizedRect] = []) {
        self.id = UUID()
        self.order = order
        self.media = media
        self.stepTitle = stepTitle ?? StepDraft.defaultTitle(from: media, order: order)
        self.keyLearningPoint = keyLearningPoint
        self.cropScale = cropScale
        self.cropOffsetX = cropOffsetX
        self.cropOffsetY = cropOffsetY
        self.annotations = annotations
        self.narrationPath = narrationPath
        self.manualBlurRects = manualBlurRects
    }

    private static func defaultTitle(from media: ImportedMediaAsset, order: Int) -> String {
        let raw = media.filename
        let base = raw.split(separator: ".").dropLast().joined(separator: ".")
        let sanitized = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty {
            return "Step \(order)"
        }
        if UUID(uuidString: sanitized) != nil {
            return "Step \(order)"
        }
        return sanitized
    }
}
