import Foundation
import Combine
import SwiftUI

enum VerificationTier: String, CaseIterable, Identifiable {
    case unverified
    case clinicianBlue
    case educatorGold
    case societyEndorsed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unverified:
            return "Unverified"
        case .clinicianBlue:
            return "Clinician (Blue)"
        case .educatorGold:
            return "Educator (Gold)"
        case .societyEndorsed:
            return "Society Endorsed"
        }
    }
}

enum ReelStatus: String {
    case draft
    case review
    case published

    var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .review:
            return "In Review"
        case .published:
            return "Published"
        }
    }
}

enum MediaType: String, Codable {
    case video
    case image
    case dicom

    var displayName: String {
        switch self {
        case .video:
            return "Video"
        case .image:
            return "Image"
        case .dicom:
            return "DICOM"
        }
    }
}

struct VerificationBadge: Identifiable {
    let id = UUID()
    let tier: VerificationTier
    let issuedAt: Date
    let notes: String
}

struct UserProfile: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let institution: String
    let specialties: [String]
    let verification: VerificationBadge
    let bio: String
}

struct PHIFinding: Identifiable {
    enum FindingType: String {
        case metadata
        case overlayText
        case face
        case audio
    }

    let id = UUID()
    let kind: FindingType
    let summary: String
    var resolved: Bool
    let mitigation: String
}

struct ReelStep: Identifiable {
    let id = UUID()
    let orderIndex: Int
    let title: String
    let keyPoint: String
    let mediaType: MediaType
    let durationSeconds: Int
    let annotations: [String]
}

struct EngagementSignals {
    let views: Int
    let saves: Int
    let completionRate: Double
    let endorsements: Int
    let reactions: [String: Int]
}

struct CMETrack {
    let id = UUID()
    let title: String
    let credits: Double
    let provider: String
    let summary: String
}

struct Reel: Identifiable {
    let id = UUID()
    let title: String
    let abstract: String
    let procedure: String
    let anatomy: String
    let pathology: String
    let device: String
    let difficulty: String
    let createdAt: Date
    let status: ReelStatus
    let author: UserProfile
    let steps: [ReelStep]
    let tags: [String]
    let phiFindings: [PHIFinding]
    let cmeTrack: CMETrack?
    let engagement: EngagementSignals
    let knowledgeHighlights: [String]
}

struct KnowledgeCollection: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let specialty: String
    let reels: [Reel]
    let endorsedBy: String?
}

struct ModerationTicket: Identifiable {
    let id = UUID()
    let createdAt: Date
    let reel: Reel
    let issue: String
    let status: String
    let slaDue: Date
}

struct PipelineRun: Identifiable {
    let id = UUID()
    let startedAt: Date
    let assetName: String
    let stages: [PipelineStage]
    let resolvedFindings: Int
    let status: String

    struct PipelineStage: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let durationSeconds: Int
        let outcome: String
    }
}

final class DemoDataStore: ObservableObject {
    @Published var reels: [Reel] = []
    @Published var collections: [KnowledgeCollection] = []
    @Published var moderationQueue: [ModerationTicket] = []
    @Published var pipelineRuns: [PipelineRun] = []
    @Published var importedAssets: [MediaAsset] = []

    init() {
        seed()
    }

    func addImportedAsset(_ asset: MediaAsset) {
        importedAssets.append(asset)
    }

    func updateImportedAsset(_ asset: MediaAsset) {
        guard let index = importedAssets.firstIndex(where: { $0.id == asset.id }) else { return }
        importedAssets[index] = asset
    }

    private func seed() {
        let author = UserProfile(
            name: "Dr. Aanya Patel, MD",
            role: "Interventional Pulmonologist",
            institution: "Mount Auburn Medical Center",
            specialties: ["Airway Stenting", "Bronchoscopy", "Pleural Procedures"],
            verification: VerificationBadge(
                tier: .clinicianBlue,
                issuedAt: Date().addingTimeInterval(-60 * 60 * 24 * 30),
                notes: "NPI verified via NPPES API"
            ),
            bio: "Fellowship-trained pulmonologist focused on complex airway obstruction and advanced interventional diagnostics."
        )

        let phiFindings = [
            PHIFinding(
                kind: .overlayText,
                summary: "Detected patient name overlay on frame 02:13",
                resolved: true,
                mitigation: "Applied mask + replaced with neutral label"
            ),
            PHIFinding(
                kind: .metadata,
                summary: "DICOM tag (0010,0010) contained PHI",
                resolved: true,
                mitigation: "Removed via de-ident recipe"
            )
        ]

        let steps = [
            ReelStep(
                orderIndex: 1,
                title: "Airway assessment",
                keyPoint: "Severe left main bronchus narrowing with granulation tissue over stent edge.",
                mediaType: .video,
                durationSeconds: 42,
                annotations: ["Cold biopsy forceps overlay", "Arrow marker to stricture"]
            ),
            ReelStep(
                orderIndex: 2,
                title: "Balloon dilation",
                keyPoint: "12mm balloon with 2-minute inflation restored lumen.",
                mediaType: .video,
                durationSeconds: 58,
                annotations: ["Timer callout", "Pressure gauge snapshot"]
            ),
            ReelStep(
                orderIndex: 3,
                title: "Post-dilation inspection",
                keyPoint: "Mucosal blanching, patent airway confirmed. Patient extubated in PACU.",
                mediaType: .image,
                durationSeconds: 30,
                annotations: ["Before/after split", "Key pearls bullet list"]
            )
        ]

        let engagement = EngagementSignals(
            views: 1284,
            saves: 232,
            completionRate: 0.82,
            endorsements: 3,
            reactions: [
                "Insightful": 56,
                "Great Technique": 31,
                "Excellent Teaching": 18
            ]
        )

        let cmeTrack = CMETrack(
            title: "Managing Granulation Tissue over Airway Stents",
            credits: 0.75,
            provider: "CHEST Foundation",
            summary: "Self-assessment quiz covering airway stent complications and rescue options."
        )

        let mainReel = Reel(
            title: "Bronchial Stent Rescue: Managing Granulation Tissue",
            abstract: "Case-based walkthrough of a bronchial stent complication with dilation strategy, pearls, and follow-up care plan.",
            procedure: "Bronchoscopy",
            anatomy: "Left Main Bronchus",
            pathology: "Granulation Tissue",
            device: "Boston Scientific Ultraflex Stent",
            difficulty: "Advanced",
            createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 6),
            status: .published,
            author: author,
            steps: steps,
            tags: ["Pulmonology", "Airway", "Stent", "Complication"],
            phiFindings: phiFindings,
            cmeTrack: cmeTrack,
            engagement: engagement,
            knowledgeHighlights: ["Use balloon dilation to rescue obstructed stents", "Always verify mucosal perfusion post-dilation", "Schedule early follow-up when stent granulation occurs"]
        )

        let secondAuthor = UserProfile(
            name: "Dr. Lina Alvarez",
            role: "Therapeutic Endoscopist",
            institution: "St. Mary's GI Center",
            specialties: ["EMR", "ESD", "Bleeding Control"],
            verification: VerificationBadge(
                tier: .educatorGold,
                issuedAt: Date().addingTimeInterval(-60 * 60 * 24 * 120),
                notes: "Educator tier verified by ASGE"
            ),
            bio: "Advanced endoscopist focusing on complex polypectomy and early GI neoplasia."
        )

        let giReel = Reel(
            title: "Cold EMR of Large Right Colon Lesion",
            abstract: "Technique breakdown for a 35mm laterally spreading tumor using cold EMR with traction clips.",
            procedure: "Endoscopic Mucosal Resection",
            anatomy: "Ascending Colon",
            pathology: "LST-G Tumor",
            device: "Olympus EndoTherapy Snare",
            difficulty: "Advanced",
            createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 2),
            status: .review,
            author: secondAuthor,
            steps: [
                ReelStep(
                    orderIndex: 1,
                    title: "Lesion inspection",
                    keyPoint: "Paris IIa+Is lesion with NICE type 2 pattern.",
                    mediaType: .video,
                    durationSeconds: 38,
                    annotations: ["NICE classification overlay", "Tattoo marker"]
                ),
                ReelStep(
                    orderIndex: 2,
                    title: "Submucosal lift",
                    keyPoint: "Orise gel injection elevated lesion without fibrosis.",
                    mediaType: .video,
                    durationSeconds: 52,
                    annotations: ["Injection plane arc", "Needle entry point"]
                ),
                ReelStep(
                    orderIndex: 3,
                    title: "Cold piecemeal resection",
                    keyPoint: "Traction clip improved visualization; all pieces retrieved.",
                    mediaType: .video,
                    durationSeconds: 74,
                    annotations: ["Clip traction direction", "Specimen bucket"]
                ),
                ReelStep(
                    orderIndex: 4,
                    title: "Defect assessment",
                    keyPoint: "No bleeding; prophylactic clips placed.",
                    mediaType: .image,
                    durationSeconds: 27,
                    annotations: ["Closure pattern diagram"]
                )
            ],
            tags: ["Gastroenterology", "EMR", "Bleeding Control"],
            phiFindings: [
                PHIFinding(
                    kind: .audio,
                    summary: "Transcript contained patient initials during narration.",
                    resolved: false,
                    mitigation: "Pending moderator review for synthetic voiceover"
                )
            ],
            cmeTrack: nil,
            engagement: EngagementSignals(
                views: 642,
                saves: 102,
                completionRate: 0.74,
                endorsements: 2,
                reactions: ["Insightful": 18, "Excellent Teaching": 24]
            ),
            knowledgeHighlights: ["Cold EMR reduces perforation risk in proximal colon", "Traction clips aid visualization", "Assess for residual tissue carefully"]
        )

        reels = [mainReel, giReel]

        collections = [
            KnowledgeCollection(
                title: "Airway Emergencies Sprint",
                description: "Five-case micro curriculum on airway obstruction rescue techniques.",
                specialty: "Interventional Pulmonology",
                reels: [mainReel],
                endorsedBy: "American Association for Bronchology"
            ),
            KnowledgeCollection(
                title: "Early GI Neoplasia Toolkit",
                description: "Curated cases on ESD/EMR with step-by-step overlays.",
                specialty: "Gastroenterology",
                reels: [giReel],
                endorsedBy: nil
            )
        ]

        pipelineRuns = [
            PipelineRun(
                startedAt: Date().addingTimeInterval(-60 * 20),
                assetName: "Bronchial_Rescue_clip.mov",
                stages: [
                    .init(name: "Metadata Scrub", detail: "Removed 23 patient-identifying tags", durationSeconds: 12, outcome: "Pass"),
                    .init(name: "OCR Detection", detail: "Found overlay text in 2 frames", durationSeconds: 18, outcome: "Pass"),
                    .init(name: "Audio Scan", detail: "No PHI terms detected", durationSeconds: 9, outcome: "Pass"),
                    .init(name: "Moderator Review", detail: "Approved by Dr. Sun", durationSeconds: 45, outcome: "Approved")
                ],
                resolvedFindings: 2,
                status: "Completed"
            ),
            PipelineRun(
                startedAt: Date().addingTimeInterval(-60 * 60 * 4),
                assetName: "Cold_EMR_voiceover.wav",
                stages: [
                    .init(name: "ASR Transcript", detail: "Transcribed 3.8 minutes of narration", durationSeconds: 21, outcome: "Pass"),
                    .init(name: "PHI NER", detail: "Detected patient initials", durationSeconds: 15, outcome: "Flagged"),
                    .init(name: "Synth Voice", detail: "Awaiting clean text approval", durationSeconds: 0, outcome: "Pending")
                ],
                resolvedFindings: 0,
                status: "Needs attention"
            )
        ]

        moderationQueue = [
            ModerationTicket(
                createdAt: Date().addingTimeInterval(-60 * 60 * 8),
                reel: giReel,
                issue: "Confirm removal of patient initials in narration",
                status: "Waiting on creator",
                slaDue: Date().addingTimeInterval(60 * 60 * 16)
            )
        ]
    }
}
