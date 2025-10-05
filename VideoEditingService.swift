import Foundation
import AVFoundation
import EndoEditCore

enum ExportPreset: String, CaseIterable, Sendable {
    case hevcSourceMatch
    case hevc1080p
    case h264Compat
}

@MainActor
protocol VideoEditingService: AnyObject {
    var editGraph: EditGraph { get set }
    func makePreviewItem(for url: URL) async throws -> AVPlayerItem
    func export(to url: URL, preset: ExportPreset, progress: @escaping (Double) -> Void) async throws
}
