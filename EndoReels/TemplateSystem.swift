import Foundation
import SwiftUI

// MARK: - Procedure Templates & Blueprints

struct ProcedureTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var specialty: String
    var procedureType: String
    var description: String
    var steps: [TemplateStep]
    var defaultAnnotations: [TimedAnnotation]
    var estimatedDuration: Int
    var difficulty: String
    var isOfficial: Bool
    var createdBy: String
    var tags: [String]

    init(id: UUID = UUID(), name: String, specialty: String, procedureType: String, description: String, steps: [TemplateStep], defaultAnnotations: [TimedAnnotation] = [], estimatedDuration: Int, difficulty: String, isOfficial: Bool = false, createdBy: String = "", tags: [String] = []) {
        self.id = id
        self.name = name
        self.specialty = specialty
        self.procedureType = procedureType
        self.description = description
        self.steps = steps
        self.defaultAnnotations = defaultAnnotations
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.isOfficial = isOfficial
        self.createdBy = createdBy
        self.tags = tags
    }
}

struct TemplateStep: Identifiable, Codable {
    let id: UUID
    var order: Int
    var title: String
    var description: String
    var keyPoints: [String]
    var suggestedDuration: Int
    var mediaType: MediaType
    var annotationPresets: [String]
    var checklistItems: [String]

    init(id: UUID = UUID(), order: Int, title: String, description: String, keyPoints: [String] = [], suggestedDuration: Int, mediaType: MediaType = .video, annotationPresets: [String] = [], checklistItems: [String] = []) {
        self.id = id
        self.order = order
        self.title = title
        self.description = description
        self.keyPoints = keyPoints
        self.suggestedDuration = suggestedDuration
        self.mediaType = mediaType
        self.annotationPresets = annotationPresets
        self.checklistItems = checklistItems
    }
}

// MARK: - Sample Templates

extension ProcedureTemplate {
    static let samples: [ProcedureTemplate] = [
        ProcedureTemplate(
            name: "Standard EBUS Staging",
            specialty: "Interventional Pulmonology",
            procedureType: "EBUS",
            description: "Complete mediastinal lymph node staging for lung cancer workup",
            steps: [
                TemplateStep(
                    order: 1,
                    title: "Equipment Setup & Patient Positioning",
                    description: "Ensure proper scope positioning and sedation",
                    keyPoints: [
                        "Verify scope calibration",
                        "Confirm sedation level",
                        "Position patient supine"
                    ],
                    suggestedDuration: 30,
                    checklistItems: [
                        "EBUS scope ready",
                        "Suction functional",
                        "Biopsy needles available"
                    ]
                ),
                TemplateStep(
                    order: 2,
                    title: "Station 2R Assessment",
                    description: "Identify and sample right paratracheal nodes",
                    keyPoints: [
                        "Locate station 2R anatomically",
                        "Assess nodal size and echogenicity",
                        "Perform needle aspiration if indicated"
                    ],
                    suggestedDuration: 45,
                    annotationPresets: ["EBUS Station 2R"],
                    checklistItems: [
                        "Station identified",
                        "Measurement recorded",
                        "Sample obtained"
                    ]
                ),
                TemplateStep(
                    order: 3,
                    title: "Station 4R Assessment",
                    description: "Evaluate right lower paratracheal nodes",
                    keyPoints: [
                        "Locate station 4R",
                        "Document nodal characteristics",
                        "Sample if suspicious"
                    ],
                    suggestedDuration: 45,
                    annotationPresets: ["EBUS Station 4R"],
                    checklistItems: [
                        "Station identified",
                        "Sample obtained"
                    ]
                ),
                TemplateStep(
                    order: 4,
                    title: "Station 7 (Subcarinal) Assessment",
                    description: "Assess subcarinal lymph nodes",
                    keyPoints: [
                        "Identify carina and subcarinal space",
                        "Measure and characterize nodes",
                        "Obtain samples bilaterally if needed"
                    ],
                    suggestedDuration: 60,
                    annotationPresets: ["EBUS Station 7"],
                    checklistItems: [
                        "Station identified",
                        "Bilateral sampling complete"
                    ]
                ),
                TemplateStep(
                    order: 5,
                    title: "Station 4L Assessment",
                    description: "Evaluate left paratracheal nodes",
                    keyPoints: [
                        "Navigate to left paratracheal region",
                        "Sample station 4L"
                    ],
                    suggestedDuration: 45,
                    annotationPresets: ["EBUS Station 4L"]
                ),
                TemplateStep(
                    order: 6,
                    title: "Post-Procedure Review",
                    description: "Confirm adequate sampling and hemostasis",
                    keyPoints: [
                        "Review all sampled stations",
                        "Confirm no bleeding",
                        "Document findings"
                    ],
                    suggestedDuration: 15,
                    checklistItems: [
                        "All stations documented",
                        "Samples labeled",
                        "Patient stable"
                    ]
                )
            ],
            estimatedDuration: 240,
            difficulty: "Intermediate",
            isOfficial: true,
            createdBy: "AABIP",
            tags: ["EBUS", "Lung Cancer", "Staging", "Mediastinal Nodes"]
        ),

        ProcedureTemplate(
            name: "Diagnostic Bronchoscopy",
            specialty: "Interventional Pulmonology",
            procedureType: "Bronchoscopy",
            description: "Standard diagnostic bronchoscopy with BAL and/or biopsy",
            steps: [
                TemplateStep(
                    order: 1,
                    title: "Airway Survey",
                    description: "Systematic inspection of upper and lower airways",
                    keyPoints: [
                        "Inspect vocal cords",
                        "Examine trachea",
                        "Survey main bronchi bilaterally"
                    ],
                    suggestedDuration: 60,
                    checklistItems: [
                        "Vocal cords visualized",
                        "Trachea inspected",
                        "Main bronchi inspected"
                    ]
                ),
                TemplateStep(
                    order: 2,
                    title: "Targeted Sampling",
                    description: "Perform BAL, brushing, or biopsy as indicated",
                    keyPoints: [
                        "Navigate to target segment",
                        "Obtain samples using appropriate technique",
                        "Ensure adequate sample volume"
                    ],
                    suggestedDuration: 90,
                    checklistItems: [
                        "Samples obtained",
                        "No bleeding",
                        "Samples labeled"
                    ]
                ),
                TemplateStep(
                    order: 3,
                    title: "Post-Procedure Assessment",
                    description: "Confirm hemostasis and patient stability",
                    keyPoints: [
                        "Inspect sampled areas",
                        "Confirm no active bleeding",
                        "Remove scope gently"
                    ],
                    suggestedDuration: 30
                )
            ],
            estimatedDuration: 180,
            difficulty: "Intro",
            isOfficial: true,
            createdBy: "CHEST",
            tags: ["Bronchoscopy", "Diagnostic", "BAL", "Biopsy"]
        ),

        ProcedureTemplate(
            name: "EMR (Endoscopic Mucosal Resection)",
            specialty: "Gastroenterology",
            procedureType: "EMR",
            description: "Stepwise approach to EMR of colonic lesions",
            steps: [
                TemplateStep(
                    order: 1,
                    title: "Lesion Characterization",
                    description: "Identify lesion morphology and pit pattern",
                    keyPoints: [
                        "Measure lesion size",
                        "Assess Paris classification",
                        "Evaluate NICE/Kudo pit pattern"
                    ],
                    suggestedDuration: 60,
                    annotationPresets: ["Lesion Size (Caliper)"],
                    checklistItems: [
                        "Size documented",
                        "Morphology assessed",
                        "Tattoo placed if needed"
                    ]
                ),
                TemplateStep(
                    order: 2,
                    title: "Submucosal Injection",
                    description: "Elevate lesion with submucosal lift",
                    keyPoints: [
                        "Choose appropriate lifting agent",
                        "Inject circumferentially",
                        "Confirm complete lift"
                    ],
                    suggestedDuration: 45,
                    checklistItems: [
                        "Lesion elevated",
                        "No fibrosis detected"
                    ]
                ),
                TemplateStep(
                    order: 3,
                    title: "Resection",
                    description: "Piecemeal or en bloc resection",
                    keyPoints: [
                        "Use snare technique appropriate for size",
                        "Retrieve all specimens",
                        "Orient specimens for pathology"
                    ],
                    suggestedDuration: 90,
                    annotationPresets: ["Device Tip"],
                    checklistItems: [
                        "Complete resection achieved",
                        "Specimens retrieved",
                        "Defect inspected"
                    ]
                ),
                TemplateStep(
                    order: 4,
                    title: "Defect Closure & Hemostasis",
                    description: "Manage post-resection defect",
                    keyPoints: [
                        "Inspect for residual tissue",
                        "Achieve hemostasis",
                        "Consider prophylactic clips"
                    ],
                    suggestedDuration: 60,
                    annotationPresets: ["Bleeding Source"],
                    checklistItems: [
                        "No bleeding",
                        "Clips placed if indicated",
                        "Defect documented"
                    ]
                )
            ],
            estimatedDuration: 255,
            difficulty: "Advanced",
            isOfficial: true,
            createdBy: "ASGE",
            tags: ["EMR", "Polyp", "Resection", "GI"]
        )
    ]
}

// MARK: - Author Macros

struct AuthorMacro: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var actions: [MacroAction]
    var applicableSteps: [String]
    var isGlobal: Bool

    init(id: UUID = UUID(), name: String, description: String, actions: [MacroAction], applicableSteps: [String] = [], isGlobal: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.actions = actions
        self.applicableSteps = applicableSteps
        self.isGlobal = isGlobal
    }

    enum MacroAction: Codable {
        case applyAnnotationPack(String)
        case setPlaybackSpeed(Double)
        case enableStabilization
        case addFreezeFrame(Double)
        case applyAudioProcessing([AudioProcessing])
        case addTitleCard(String)
        case applyColorGrade(String)

        private enum CodingKeys: String, CodingKey { case type, value }
        private enum Kind: String, Codable {
            case applyAnnotationPack
            case setPlaybackSpeed
            case enableStabilization
            case addFreezeFrame
            case applyAudioProcessing
            case addTitleCard
            case applyColorGrade
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .type)
            switch kind {
            case .applyAnnotationPack:
                let value = try container.decode(String.self, forKey: .value)
                self = .applyAnnotationPack(value)
            case .setPlaybackSpeed:
                let value = try container.decode(Double.self, forKey: .value)
                self = .setPlaybackSpeed(value)
            case .enableStabilization:
                self = .enableStabilization
            case .addFreezeFrame:
                let value = try container.decode(Double.self, forKey: .value)
                self = .addFreezeFrame(value)
            case .applyAudioProcessing:
                let value = try container.decode([AudioProcessing].self, forKey: .value)
                self = .applyAudioProcessing(value)
            case .addTitleCard:
                let value = try container.decode(String.self, forKey: .value)
                self = .addTitleCard(value)
            case .applyColorGrade:
                let value = try container.decode(String.self, forKey: .value)
                self = .applyColorGrade(value)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .applyAnnotationPack(let value):
                try container.encode(Kind.applyAnnotationPack, forKey: .type)
                try container.encode(value, forKey: .value)
            case .setPlaybackSpeed(let value):
                try container.encode(Kind.setPlaybackSpeed, forKey: .type)
                try container.encode(value, forKey: .value)
            case .enableStabilization:
                try container.encode(Kind.enableStabilization, forKey: .type)
            case .addFreezeFrame(let value):
                try container.encode(Kind.addFreezeFrame, forKey: .type)
                try container.encode(value, forKey: .value)
            case .applyAudioProcessing(let value):
                try container.encode(Kind.applyAudioProcessing, forKey: .type)
                try container.encode(value, forKey: .value)
            case .addTitleCard(let value):
                try container.encode(Kind.addTitleCard, forKey: .type)
                try container.encode(value, forKey: .value)
            case .applyColorGrade(let value):
                try container.encode(Kind.applyColorGrade, forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }

        var displayName: String {
            switch self {
            case .applyAnnotationPack(let name): return "Apply annotation pack: \(name)"
            case .setPlaybackSpeed(let speed): return "Set playback speed: \(speed)x"
            case .enableStabilization: return "Enable stabilization"
            case .addFreezeFrame(let time): return "Add freeze frame at \(time)s"
            case .applyAudioProcessing(let types): return "Apply audio: \(types.map(\.rawValue).joined(separator: ", "))"
            case .addTitleCard(let title): return "Add title card: \(title)"
            case .applyColorGrade(let grade): return "Apply color grade: \(grade)"
            }
        }
    }

    static let samples: [AuthorMacro] = [
        AuthorMacro(
            name: "Standard EBUS Workflow",
            description: "Applies consistent styling to all EBUS staging cases",
            actions: [
                .applyAnnotationPack("EBUS Complete Staging"),
                .enableStabilization,
                .applyAudioProcessing([.noiseReduction, .loudnessNormalization])
            ],
            applicableSteps: ["EBUS"],
            isGlobal: false
        ),
        AuthorMacro(
            name: "Polished Teaching Reel",
            description: "Applies professional polish to any teaching case",
            actions: [
                .enableStabilization,
                .applyAudioProcessing([.noiseReduction, .deEss, .loudnessNormalization]),
                .applyColorGrade("Clinical Standard")
            ],
            isGlobal: true
        ),
        AuthorMacro(
            name: "Complication Documentation",
            description: "Prepares case for complication review with key annotations",
            actions: [
                .addFreezeFrame(0),
                .applyAnnotationPack("Bleeding Control"),
                .addTitleCard("Complication Case")
            ],
            isGlobal: true
        )
    ]
}

// MARK: - Template Browser View

struct TemplateBrowserView: View {
    let onSelectTemplate: (ProcedureTemplate) -> Void
    @State private var selectedSpecialty: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var specialties: [String] {
        Array(Set(ProcedureTemplate.samples.map(\.specialty))).sorted()
    }

    private var filteredTemplates: [ProcedureTemplate] {
        guard let specialty = selectedSpecialty else {
            return ProcedureTemplate.samples
        }
        return ProcedureTemplate.samples.filter { $0.specialty == specialty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Specialty Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button {
                            selectedSpecialty = nil
                        } label: {
                            Text("All")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedSpecialty == nil ? Color.blue : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedSpecialty == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }

                        ForEach(specialties, id: \.self) { specialty in
                            Button {
                                selectedSpecialty = specialty
                            } label: {
                                Text(specialty)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedSpecialty == specialty ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedSpecialty == specialty ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Template List
                List {
                    ForEach(filteredTemplates) { template in
                        TemplateCard(template: template, onSelect: {
                            onSelectTemplate(template)
                            dismiss()
                        })
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Procedure Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: ProcedureTemplate
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.specialty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if template.isOfficial {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                }
            }

            Text(template.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("\(template.steps.count) steps", systemImage: "list.number")
                Label("\(template.estimatedDuration / 60) min", systemImage: "timer")
                Label(template.difficulty, systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(template.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            Button(action: onSelect) {
                Label("Use Template", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    TemplateBrowserView { template in
        print("Selected: \(template.name)")
    }
}
