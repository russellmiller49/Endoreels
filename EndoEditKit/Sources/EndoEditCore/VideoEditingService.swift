import Foundation
import AVFoundation

public enum ExportPreset: String, CaseIterable, Sendable {
    case hevcSourceMatch
    case hevc1080p
    case h264Compat
}

@MainActor
public protocol VideoEditingService: AnyObject {
    var editGraph: EditGraph { get set }
    func makePreviewItem(for url: URL) async throws -> AVPlayerItem
    func export(to url: URL, preset: ExportPreset, progress: @escaping (Double) -> Void) async throws
}

public extension ExportPreset {
    var presetName: String {
        switch self {
        case .hevcSourceMatch:
            return AVAssetExportPresetHEVCHighestQuality
        case .hevc1080p:
            return AVAssetExportPresetHEVC1920x1080
        case .h264Compat:
            return AVAssetExportPresetHighestQuality
        }
    }

    var outputFileType: AVFileType {
        switch self {
        case .hevcSourceMatch, .hevc1080p:
            return .mov
        case .h264Compat:
            return .mp4
        }
    }

    var fileExtension: String {
        switch self {
        case .h264Compat:
            return "mp4"
        default:
            return "mov"
        }
    }

    var displayName: String {
        switch self {
        case .hevcSourceMatch:
            return "HEVC Source"
        case .hevc1080p:
            return "HEVC 1080p"
        case .h264Compat:
            return "H.264" 
        }
    }
}
