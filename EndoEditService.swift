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

    #if DEBUG
    private func debugLogGraph(prefix: String = "") {
        let ops = engine.editGraph.operations
        print("🧩 EndoEditService.graph \(prefix) ops=\(ops.count)")
        for (idx, op) in ops.enumerated() {
            switch op {
            case .crop(let crop):
                let r = crop.sanitized().rect
                print("  [\(idx)] crop x=\(r.origin.x), y=\(r.origin.y), w=\(r.size.width), h=\(r.size.height)")
            case .freeze(let seg):
                print("  [\(idx)] freeze id=\(seg.id) start=\(CMTimeGetSeconds(seg.start)) dur=\(CMTimeGetSeconds(seg.duration)) src=\(CMTimeGetSeconds(seg.sourceTime))")
            default:
                print("  [\(idx)] other=\(op)")
            }
        }
    }
    #endif

    init(sourceURL: URL, existingGraph: EditGraph = .empty, fileManager: FileManager = .default) {
        self.sourceURL = sourceURL
        self.fileManager = fileManager
        self.graphURL = sourceURL
            .deletingPathExtension()
            .appendingPathExtension("endoeditgraph.json")

        let persistedGraph = (try? EndoEditService.loadGraph(from: self.graphURL)) ?? existingGraph
        self.engine = EndoEditorEngine(url: sourceURL, editGraph: persistedGraph)
        #if DEBUG
        print("🎬 EndoEditService.init source=\(sourceURL.lastPathComponent) graphOps=\(engine.editGraph.operations.count)")
        #endif
    }

    @MainActor func makePreviewItem(for url: URL) async throws -> AVPlayerItem {
        #if DEBUG
        print("🧪 makePreviewItem(for:) url=\(url.lastPathComponent) (source=\(sourceURL.lastPathComponent))")
        debugLogGraph(prefix: "beforePreview")
        #endif

        if url == sourceURL {
            do {
                let item = try await engine.makePreviewPlayerItem()
                #if DEBUG
                print("✅ Preview item (main) created")
                #endif
                return item
            } catch {
                #if DEBUG
                print("❌ Preview item (main) failed: \(error.localizedDescription)")
                #endif
                throw error
            }
        }

        let tempEngine = EndoEditorEngine(url: url, editGraph: editGraph)
        do {
            let item = try await tempEngine.makePreviewPlayerItem()
            #if DEBUG
            print("✅ Preview item (temp) created for \(url.lastPathComponent)")
            #endif
            return item
        } catch {
            #if DEBUG
            print("❌ Preview item (temp) failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    @MainActor func export(to url: URL, preset: ExportPreset, progress: @escaping (Double) -> Void) async throws {
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

        #if DEBUG
        let videoTracks = try? await engine.asset.loadTracks(withMediaType: .video)
        var size: CGSize = .zero
        if let firstTrack = videoTracks?.first {
            size = (try? await firstTrack.load(.naturalSize)) ?? .zero
        }
        print("🎞️ Asset info: tracks=\(videoTracks?.count ?? -1) size=\(size)")
        debugLogGraph(prefix: "beforeExport")
        #endif

        // DEBUG: Feature-flagged passthrough to isolate compositor issues
        let forcePassthrough = UserDefaults.standard.bool(forKey: "EndoEditForcePassthrough")
        let previewItem = try await engine.makePreviewPlayerItem()
        if forcePassthrough {
            exportSession.videoComposition = nil
            #if DEBUG
            print("🎛️ EndoEditService.export: Forcing passthrough (videoComposition=nil)")
            print("🎚️ videoComposition=nil (passthrough)")
            #endif
        } else {
            exportSession.videoComposition = previewItem.videoComposition
            #if DEBUG
            print("🎛️ EndoEditService.export: Using custom videoComposition: \(String(describing: previewItem.videoComposition))")
            print("🎚️ videoComposition from previewItem: \(String(describing: previewItem.videoComposition))")
            #endif
        }

        #if DEBUG
        print("🎛️ EndoEditService.export: Session created with preset=\(preset.presetName), outputType=\(preset.outputFileType.rawValue), url=\(url.path)")
        if #available(iOS 18, *) {
            print("🎛️ EndoEditService.export: Initial progress=\(exportSession.progress)")
        } else {
            print("🎛️ EndoEditService.export: Initial status=\(exportSession.status.rawValue), progress=\(exportSession.progress)")
        }
        #endif

        if #available(iOS 18, *) {
            let progressTask = Task {
                for await _ in exportSession.states(updateInterval: 0.2) {
                    let pct = Double(exportSession.progress)
                    progress(pct)
                    #if DEBUG
                    print("📈 Export progress: \(Int(pct * 100))%")
                    #endif
                }
            }

            do {
                #if DEBUG
                print("🚀 Starting export (iOS 18+ API)…")
                #endif
                try await exportSession.export(to: url, as: preset.outputFileType)
                #if DEBUG
                print("✅ Export completed (iOS 18+).")
                #endif
                progress(1.0)
            } catch {
                #if DEBUG
                print("❌ Export failed (iOS 18+). error=\(error.localizedDescription)")
                #endif
                progressTask.cancel()
                throw error
            }

            progressTask.cancel()
            exportSession.disableLifecycleManagement()
        } else {
            #if DEBUG
            print("🎚️ (legacy) videoComposition=\(String(describing: exportSession.videoComposition)) status=\(exportSession.status.rawValue)")
            #endif

            exportSession.outputFileType = preset.outputFileType

            let progressTask = Task {
                while !Task.isCancelled {
                    progress(Double(exportSession.progress))
                    #if DEBUG
                    print("📈 Export progress: \(Int(exportSession.progress * 100))% (status=\(exportSession.status.rawValue))")
                    #endif
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
                        #if DEBUG
                        print("🧵 Export async completion fired. status=\(boxedSession.session.status.rawValue), error=\(String(describing: boxedSession.session.error))")
                        #endif
                        switch boxedSession.session.status {
                        case .completed:
                            #if DEBUG
                            print("✅ Export completed (legacy).")
                            #endif
                            progress(1.0)
                            continuation.resume()
                        case .failed:
                            #if DEBUG
                            print("❌ Export failed (legacy). error=\(String(describing: boxedSession.session.error))")
                            #endif
                            let error = boxedSession.session.error ?? ExportError.unableToCreateExportSession
                            continuation.resume(throwing: error)
                        case .cancelled:
                            #if DEBUG
                            print("⛔️ Export cancelled (legacy).")
                            #endif
                            continuation.resume(throwing: CancellationError())
                        default:
                            #if DEBUG
                            print("⚠️ Export ended in unexpected state: \(boxedSession.session.status.rawValue)")
                            #endif
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

    @discardableResult
    func validateCompositionDiagnostics() async -> String {
        var lines: [String] = []
        lines.append("🔍 Validate Composition — source=\(sourceURL.lastPathComponent)")
        do {
            let duration = try await engine.asset.load(.duration)
            let vTracks = try? await engine.asset.loadTracks(withMediaType: .video)
            var size: CGSize = .zero
            if let firstTrack = vTracks?.first {
                size = (try? await firstTrack.load(.naturalSize)) ?? .zero
            }
            lines.append("asset: duration=\(CMTimeGetSeconds(duration))s size=\(size) videoTracks=\(vTracks?.count ?? -1)")
        } catch {
            lines.append("asset load failed: \(error.localizedDescription)")
        }

        #if DEBUG
        debugLogGraph(prefix: "validate")
        #endif

        do {
            let item = try await engine.makePreviewPlayerItem()
            if let comp = item.videoComposition {
                lines.append("videoComposition: renderSize=\(comp.renderSize) frameDuration=\(CMTimeGetSeconds(comp.frameDuration))s instructions=\(comp.instructions.count)")
                for (i, instr) in comp.instructions.enumerated() {
                    let tr = instr.timeRange
                    var layerCount = 0
                    if let concrete = instr as? AVVideoCompositionInstruction {
                        layerCount = concrete.layerInstructions.count
                    }
                    lines.append("  [\(i)] timeRange start=\(CMTimeGetSeconds(tr.start))s dur=\(CMTimeGetSeconds(tr.duration))s layers=\(layerCount)")
                }
            } else {
                lines.append("videoComposition: nil (passthrough)")
            }
            lines.append("playerItem: tracks=\(item.tracks.count)")
        } catch {
            lines.append("makePreviewPlayerItem failed: \(error.localizedDescription)")
        }

        let diagnostics = lines.joined(separator: "\n")
        #if DEBUG
        print(diagnostics)
        #endif
        return diagnostics
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

// ExportPreset extension is now defined in EndoEditCore module

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }
}
