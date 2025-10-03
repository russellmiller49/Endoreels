import Foundation
import SwiftUI

// MARK: - Annotation Models

enum AnnotationType: String, Codable, CaseIterable {
    case arrow
    case circle
    case text
    case callout
    case magnifier
    case measurement
    case counter

    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        case .text: return "Text"
        case .callout: return "Callout"
        case .magnifier: return "Magnifier"
        case .measurement: return "Measurement"
        case .counter: return "Counter"
        }
    }

    var systemImage: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .circle: return "circle"
        case .text: return "text.cursor"
        case .callout: return "text.bubble"
        case .magnifier: return "magnifyingglass.circle"
        case .measurement: return "ruler"
        case .counter: return "number.circle"
        }
    }
}

struct TimedAnnotation: Identifiable, Codable {
    let id: UUID
    var type: AnnotationType
    var startTime: Double
    var endTime: Double
    var position: CGPoint
    var text: String
    var color: AnnotationColor
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
    var preset: AnnotationPreset?

    init(id: UUID = UUID(), type: AnnotationType, startTime: Double, endTime: Double, position: CGPoint = .zero, text: String = "", color: AnnotationColor = .red, scale: CGFloat = 1.0, rotation: Double = 0, opacity: Double = 1.0, preset: AnnotationPreset? = nil) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
        self.text = text
        self.color = color
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.preset = preset
    }
}

enum AnnotationColor: String, Codable, CaseIterable {
    case red
    case blue
    case green
    case yellow
    case orange
    case purple
    case white
    case black

    var displayName: String { rawValue.capitalized }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .white: return .white
        case .black: return .black
        }
    }
}

// MARK: - Clinical Presets

enum AnnotationPreset: String, Codable, CaseIterable {
    case ebusStation2R = "EBUS Station 2R"
    case ebusStation4R = "EBUS Station 4R"
    case ebusStation4L = "EBUS Station 4L"
    case ebusStation7 = "EBUS Station 7"
    case ebusStation10R = "EBUS Station 10R"
    case ebusStation11R = "EBUS Station 11R"
    case lesionSizeCaliper = "Lesion Size (Caliper)"
    case biopsyLocation = "Biopsy Location"
    case stricturePoint = "Stricture Point"
    case bleedingSource = "Bleeding Source"
    case deviceTip = "Device Tip"
    case anatomicalLandmark = "Anatomical Landmark"

    var id: String { rawValue }

    var category: PresetCategory {
        switch self {
        case .ebusStation2R, .ebusStation4R, .ebusStation4L, .ebusStation7, .ebusStation10R, .ebusStation11R:
            return .ebusStaging
        case .lesionSizeCaliper, .biopsyLocation, .stricturePoint:
            return .measurement
        case .bleedingSource, .deviceTip:
            return .interventional
        case .anatomicalLandmark:
            return .general
        }
    }

    var defaultAnnotations: [TimedAnnotation] {
        switch self {
        case .ebusStation2R, .ebusStation4R, .ebusStation4L, .ebusStation7, .ebusStation10R, .ebusStation11R:
            return [
                TimedAnnotation(type: .circle, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: rawValue, color: .yellow, scale: 1.2),
                TimedAnnotation(type: .text, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.7), text: rawValue, color: .white)
            ]
        case .lesionSizeCaliper:
            return [
                TimedAnnotation(type: .measurement, startTime: 0, endTime: 5, position: CGPoint(x: 0.3, y: 0.5), text: "Measure", color: .green)
            ]
        case .biopsyLocation:
            return [
                TimedAnnotation(type: .arrow, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Biopsy site", color: .red, scale: 1.5)
            ]
        case .stricturePoint:
            return [
                TimedAnnotation(type: .circle, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Stricture", color: .orange, scale: 1.3),
                TimedAnnotation(type: .arrow, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "", color: .orange, scale: 1.2)
            ]
        case .bleedingSource:
            return [
                TimedAnnotation(type: .callout, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Bleeding source", color: .red, scale: 1.4)
            ]
        case .deviceTip:
            return [
                TimedAnnotation(type: .arrow, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Device tip", color: .blue, scale: 1.3)
            ]
        case .anatomicalLandmark:
            return [
                TimedAnnotation(type: .text, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Landmark", color: .white)
            ]
        }
    }
}

enum PresetCategory: String, CaseIterable {
    case ebusStaging = "EBUS Staging"
    case measurement = "Measurement"
    case interventional = "Interventional"
    case general = "General"

    var presets: [AnnotationPreset] {
        AnnotationPreset.allCases.filter { $0.category == self }
    }
}

// MARK: - Annotation Pack (Reusable Template)

struct AnnotationPack: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var annotations: [TimedAnnotation]
    var specialty: String
    var isOfficial: Bool
    var createdBy: String

    init(id: UUID = UUID(), name: String, description: String, annotations: [TimedAnnotation], specialty: String, isOfficial: Bool = false, createdBy: String = "") {
        self.id = id
        self.name = name
        self.description = description
        self.annotations = annotations
        self.specialty = specialty
        self.isOfficial = isOfficial
        self.createdBy = createdBy
    }

    static let samples: [AnnotationPack] = [
        AnnotationPack(
            name: "EBUS Complete Staging",
            description: "Full mediastinal lymph node station map for staging workup",
            annotations: [
                TimedAnnotation(type: .circle, startTime: 0, endTime: 3, position: CGPoint(x: 0.5, y: 0.3), text: "Station 2R", color: .yellow),
                TimedAnnotation(type: .circle, startTime: 3, endTime: 6, position: CGPoint(x: 0.5, y: 0.4), text: "Station 4R", color: .yellow),
                TimedAnnotation(type: .circle, startTime: 6, endTime: 9, position: CGPoint(x: 0.5, y: 0.5), text: "Station 7", color: .yellow)
            ],
            specialty: "Interventional Pulmonology",
            isOfficial: true,
            createdBy: "AABIP"
        ),
        AnnotationPack(
            name: "GI Bleeding Control",
            description: "Standard bleeding source identification and intervention markers",
            annotations: [
                TimedAnnotation(type: .callout, startTime: 0, endTime: 5, position: CGPoint(x: 0.5, y: 0.5), text: "Bleeding source", color: .red),
                TimedAnnotation(type: .arrow, startTime: 5, endTime: 10, position: CGPoint(x: 0.6, y: 0.5), text: "Clip placement", color: .blue)
            ],
            specialty: "Gastroenterology",
            isOfficial: true,
            createdBy: "ASGE"
        )
    ]
}
