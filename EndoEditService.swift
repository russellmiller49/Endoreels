import Foundation
import AVFoundation
import EndoEditCore

@MainActor
final class EndoEditService: VideoEditingService {
    private enum ExportError: Error {
        case unableToCreateExportSession
    }

    let sourceURL: URL
    let engine: EndoEditorEngine
    private let fileManager: FileManager
    private let graphURL: URL

    var editGraph: EditGraph {
        get { engine.editGraph }
        set {
            engine.editGraph = newValue
            saveGraphIfPossible()
        }
    }

    init(sourceURL: URL, existingGraph: EditGraph = .empty, fileManager: FileManager = .default) {
        self.sourceURL = sourceURL
        self.fileManager = fileManager
        self.graphURL = sourceURL
            .deletingPathExtension()
            .appendingPathExtension("endoeditgraph.json")

        let persistedGraph = (try? EndoEditService.loadGraph(from: self.graphURL)) ?? existingGraph
        self.engine = EndoEditorEngine(url: sourceURL, editGraph: persistedGraph)
    }

    func makePreviewItem(for url: URL) async throws -> AVPlayerItem {
        if url == sourceURL {
            return try await engine.makePreviewPlayerItem()
        }

        let tempEngine = EndoEditorEngine(url: url, editGraph: editGraph)
        return try await tempEngine.makePreviewPlayerItem()
    }

    func export(to url: URL, preset: ExportPreset, progress: @escaping (Double) -> Void) async throws {
        progress(0.0)

        try prepareExportDestination(url)

        guard let exportSession = AVAssetExportSession(asset: engine.asset, presetName: preset.presetName) else {
            throw ExportError.unableToCreateExportSession
        }

        exportSession.enableLifecycleManagement()
        exportSession.outputURL = url
        exportSession.outputFileType = preset.outputFileType
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.metadataItemFilter = .forSharing()

        let previewItem = try await engine.makePreviewPlayerItem()
        exportSession.videoComposition = previewItem.videoComposition

        if #available(iOS 18, *) {
            let progressTask = Task {
                while !Task.isCancelled {
                    progress(Double(exportSession.progress))
                    if exportSession.progress >= 1.0 {
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }

            do {
                try await exportSession.export(to: url, as: preset.outputFileType)
                progress(1.0)
            } catch {
                progressTask.cancel()
                throw error
            }

            progressTask.cancel()
            exportSession.disableLifecycleManagement()
        } else {
            exportSession.outputFileType = preset.outputFileType

            let progressTask = Task {
                while !Task.isCancelled {
                    progress(Double(exportSession.progress))
                    if exportSession.status != .waiting && exportSession.status != .exporting {
                        break
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }

            let boxedSession = ExportSessionBox(session: exportSession)

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    boxedSession.session.exportAsynchronously {
                        boxedSession.session.disableLifecycleManagement()
                        switch boxedSession.session.status {
                        case .completed:
                            progress(1.0)
                            continuation.resume()
                        case .failed:
                            let error = boxedSession.session.error ?? ExportError.unableToCreateExportSession
                            continuation.resume(throwing: error)
                        case .cancelled:
                            continuation.resume(throwing: CancellationError())
                        default:
                            continuation.resume(throwing: boxedSession.session.error ?? ExportError.unableToCreateExportSession)
                        }
                    }
                }
            } catch {
                progressTask.cancel()
                throw error
            }

            progressTask.cancel()
        }
    }

    private func prepareExportDestination(_ url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func saveGraphIfPossible() {
        do {
            let data = try JSONEncoder().encode(engine.editGraph)
            try data.write(to: graphURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to persist edit graph: \(error.localizedDescription)")
            #endif
        }
    }

    private static func loadGraph(from url: URL) throws -> EditGraph {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(EditGraph.self, from: data)
    }
}

extension ExportPreset {
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

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }
}
