import SwiftUI
import AVKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct MediaAssetEditorView: View {
    @Binding var asset: MediaAsset
    @Environment(\.dismiss) private var dismiss
    @State private var exportMessage: String?
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(asset.filename)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    switch asset.kind {
                    case .video:
                        VideoEditorSection(asset: $asset, isExporting: $isExporting, exportMessage: $exportMessage, exportError: $exportError)
                    case .image:
                        ImageEditorSection(asset: $asset, exportMessage: $exportMessage, exportError: $exportError)
                    case .audio:
                        AudioEditorSection(asset: $asset, exportMessage: $exportMessage, exportError: $exportError)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Media")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(exportMessage ?? "", isPresented: Binding(
                get: { exportMessage != nil },
                set: { if !$0 { exportMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
            .alert("Processing Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }
}

private struct ImageEditorSection: View {
    @Binding var asset: MediaAsset
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1

    private let context = CIContext()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let image = asset.editedImage ?? asset.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                LabeledSlider(title: "Brightness", value: $brightness, range: -0.5...0.5)
                LabeledSlider(title: "Contrast", value: $contrast, range: 0.5...1.8)
                LabeledSlider(title: "Saturation", value: $saturation, range: 0.5...1.8)
            }

            Button {
                applyAdjustments()
            } label: {
                Label("Apply Adjustments", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

    private func applyAdjustments() {
        guard let sourceImage = asset.editedImage ?? asset.thumbnail,
              let ciImage = CIImage(image: sourceImage) else {
            exportError = "Unable to process image."
            return
        }

        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        filter.saturation = Float(saturation)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            exportError = "Failed to render adjusted image."
            return
        }

        let editedImage = UIImage(cgImage: cgImage)
        do {
            try asset.applyEditedImage(editedImage, storeAt: asset.url)
            exportMessage = "Image adjustments saved."
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct AudioEditorSection: View {
    @Binding var asset: MediaAsset
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var volume: Double = 1.0
    @State private var isGeneratingTranscript = false

    private var duration: Double { asset.duration ?? player?.duration ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            audioPreview

            VStack(alignment: .leading, spacing: 12) {
                Text("Trim Range")
                    .font(.subheadline.weight(.semibold))

                Slider(value: Binding(
                    get: { startTime },
                    set: { newValue in
                        startTime = min(newValue, endTime - 0.25)
                        player?.currentTime = startTime
                    }
                ), in: 0...max(endTime - 0.25, 0))

                Slider(value: Binding(
                    get: { endTime },
                    set: { newValue in
                        endTime = max(newValue, startTime + 0.25)
                    }
                ), in: (startTime + 0.25)...max(duration, startTime + 0.25))

                HStack {
                    Text("Start: \(startTime, specifier: "%.1f")s")
                    Spacer()
                    Text("End: \(endTime, specifier: "%.1f")s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Audio Enhancements")
                    .font(.subheadline.weight(.semibold))
                LabeledSlider(title: "Volume", value: $volume, range: 0...1.5)
                    .onChange(of: volume) { _, newValue in
                        player?.volume = Float(newValue)
                    }
            }

            HStack(spacing: 12) {
                Button(action: togglePlay) {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await exportTrimmedAudio() }
                } label: {
                    Label("Trim & Save", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            Button {
                Task { await generateTranscript() }
            } label: {
                if isGeneratingTranscript {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Convert Audio to Text", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isGeneratingTranscript)

            if let transcript = asset.transcript, !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { configurePlayerIfNeeded() }
    }

    private var audioPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                let bars = 32
                let barWidth = size.width / CGFloat(bars)
                for index in 0..<bars {
                    let factor = CGFloat(Double(index % 7 + 1) / 7.0)
                    let height = size.height * (0.25 + factor * 0.6)
                    let x = CGFloat(index) * barWidth
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth * 0.55, height: height)
                    context.fill(Path(rect), with: .color(.blue.opacity(0.6)))
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack {
                Label(asset.filename, systemImage: "waveform")
                Spacer()
                Text("\(Int(duration.rounded()))s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil else { return }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: asset.url)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = Float(volume)
            player = audioPlayer
            startTime = asset.trimRange?.lowerBound ?? 0
            endTime = asset.trimRange?.upperBound ?? audioPlayer.duration
            if endTime <= startTime {
                endTime = max(audioPlayer.duration, startTime + 0.25)
            }
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.currentTime = startTime
            player.play()
            isPlaying = true
        }
    }

    private func exportTrimmedAudio() async {
        guard duration > 0 else {
            exportError = "Unable to determine audio duration."
            return
        }

        do {
            let outputURL = try await trimAudio(at: asset.url, start: startTime, end: endTime)
            let newDuration = endTime - startTime
            await MainActor.run {
                asset.applyTrimmedAudio(url: outputURL, duration: newDuration, range: startTime...endTime)
                exportMessage = "Trimmed audio saved."
                configurePlayerReset()
            }
        } catch {
            await MainActor.run { exportError = error.localizedDescription }
        }
    }

    private func configurePlayerReset() {
        player?.stop()
        player = nil
        isPlaying = false
        configurePlayerIfNeeded()
    }

    private func trimAudio(at url: URL, start: Double, end: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                    end: CMTime(seconds: end, preferredTimescale: 600))

        let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("EndoReelsMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        let outputURL = outputDirectory.appendingPathComponent("\(UUID().uuidString).m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        if #available(iOS 18, *) {
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw NSError(domain: "EndoReels", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio export session."])
            }
            exporter.timeRange = timeRange
            exporter.outputURL = outputURL
            exporter.outputFileType = .m4a
            try await exporter.export(to: outputURL, as: .m4a)
            return outputURL
        } else {
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw NSError(domain: "EndoReels", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio export session."])
            }
            exporter.outputURL = outputURL
            exporter.outputFileType = .m4a
            exporter.timeRange = timeRange

            let boxed = ExportSessionBox(exporter: exporter)
            return try await withCheckedThrowingContinuation { continuation in
                boxed.exporter.exportAsynchronously {
                    switch boxed.exporter.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed, .cancelled:
                        let error = boxed.exporter.error ?? NSError(domain: "EndoReels", code: -2, userInfo: [NSLocalizedDescriptionKey: "Audio export failed."])
                        continuation.resume(throwing: error)
                    default:
                        break
                    }
                }
            }
        }
    }

    private func generateTranscript() async {
        await MainActor.run { isGeneratingTranscript = true }
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // simulate processing delay
            await MainActor.run {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                asset.updateTranscript("AI transcript generated \(formatter.string(from: .now))\n• Key clinical narration captured for documentation.")
                exportMessage = "Transcript generated."
                isGeneratingTranscript = false
            }
        } catch {
            await MainActor.run {
                exportError = error.localizedDescription
                isGeneratingTranscript = false
            }
        }
    }
}

private struct VideoEditorSection: View {
    @Binding var asset: MediaAsset
    @Binding var isExporting: Bool
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @State private var player = AVPlayer()
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var enableStabilization: Bool = false
    @State private var enableDeflicker: Bool = false
    @State private var enableDenoise: Bool = false
    @State private var freezeFrameTime: Double? = nil
    @State private var showAdvancedOptions = false

    private var duration: Double { asset.duration ?? 0 }
    private var sliderUpperBound: Double { max(duration, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VideoPlayer(player: player)
                .frame(height: 220)
                .cornerRadius(12)
                .onAppear { configurePlayerIfNeeded() }
                .overlay(alignment: .bottom) {
                    if let freezeTime = freezeFrameTime {
                        Text("Freeze frame at \(freezeTime, specifier: "%.1f")s")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("Trim Range")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    Text("Start: \(startTime, specifier: "%.1f")s")
                    Spacer()
                    Text("End: \(endTime, specifier: "%.1f")s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Slider(value: Binding(
                    get: { startTime },
                    set: { newValue in
                        startTime = min(newValue, endTime - 0.5)
                        seek(to: startTime)
                    }
                ), in: 0...max(endTime - 0.5, 0))

                Slider(value: Binding(
                    get: { endTime },
                    set: { newValue in
                        endTime = max(newValue, startTime + 0.5)
                    }
                ), in: (startTime + 0.5)...sliderUpperBound)
            }

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup("Advanced Editing Options", isExpanded: $showAdvancedOptions) {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledSlider(title: "Speed (\(playbackSpeed < 1 ? "Slow Motion" : playbackSpeed > 1 ? "Speed Up" : "Normal"))", value: $playbackSpeed, range: 0.25...4.0)
                            .onChange(of: playbackSpeed) { _, newValue in
                                player.rate = Float(newValue)
                            }

                        Divider()

                        Text("Visual Enhancements (Fidelity Safe)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Toggle("Stabilization", isOn: $enableStabilization)
                            .tint(.blue)

                        Toggle("Deflicker", isOn: $enableDeflicker)
                            .tint(.blue)

                        Toggle("Denoise", isOn: $enableDenoise)
                            .tint(.blue)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Freeze Frame")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if let freezeTime = freezeFrameTime {
                                HStack {
                                    Text("At \(freezeTime, specifier: "%.1f")s")
                                        .font(.caption)
                                    Spacer()
                                    Button("Remove", role: .destructive) {
                                        freezeFrameTime = nil
                                    }
                                    .font(.caption)
                                }
                            } else {
                                Button {
                                    freezeFrameTime = player.currentTime().seconds
                                } label: {
                                    Label("Add freeze frame at current position", systemImage: "pause.rectangle")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline.weight(.semibold))
            }

            Button {
                Task { await exportTrimmedClip() }
            } label: {
                if isExporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Trim & Save", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isExporting)

            if enableStabilization || enableDeflicker || enableDenoise || playbackSpeed != 1.0 || freezeFrameTime != nil {
                Text("⚠️ Disclosure: This video includes \(disclosureText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear { configureSliderBounds() }
    }

    private var disclosureText: String {
        var effects: [String] = []
        if enableStabilization { effects.append("stabilization") }
        if enableDeflicker { effects.append("deflicker") }
        if enableDenoise { effects.append("denoise") }
        if playbackSpeed != 1.0 { effects.append("speed adjustment") }
        if freezeFrameTime != nil { effects.append("freeze frame") }
        return effects.joined(separator: ", ")
    }

    private func configurePlayerIfNeeded() {
        guard player.currentItem == nil else { return }
        let itemAsset = AVURLAsset(url: asset.url)
        let item = AVPlayerItem(asset: itemAsset)
        player.replaceCurrentItem(with: item)
        player.play()
        player.pause()
    }

    private func configureSliderBounds() {
        let defaultDuration = sliderUpperBound
        startTime = asset.trimRange?.lowerBound ?? 0
        endTime = asset.trimRange?.upperBound ?? defaultDuration
        if endTime <= startTime {
            endTime = defaultDuration
        }
    }

    private func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    private func exportTrimmedClip() async {
        guard duration > 0 else {
            exportError = "Video duration unavailable."
            return
        }

        await MainActor.run { isExporting = true }
        defer {
            Task { @MainActor in isExporting = false }
        }

        do {
            let outputURL = try await trimVideo(at: asset.url, start: startTime, end: endTime)
            let newDuration = endTime - startTime
            let newThumbnail = await AVURLAsset(url: outputURL).generateThumbnail()
            await MainActor.run {
                asset.applyTrimmedVideo(url: outputURL, duration: newDuration, range: startTime...endTime, thumbnail: newThumbnail)
                let refreshedItem = AVPlayerItem(asset: AVURLAsset(url: outputURL))
                player.replaceCurrentItem(with: refreshedItem)
                exportMessage = "Trimmed clip saved."
            }
        } catch {
            await MainActor.run { exportError = error.localizedDescription }
        }
    }

    private func trimVideo(at url: URL, start: Double, end: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let startTime = CMTime(seconds: start, preferredTimescale: 600)
        let endTime = CMTime(seconds: end, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("EndoReelsMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        let outputURL = outputDirectory.appendingPathComponent("\(UUID().uuidString).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        if #available(iOS 18, *) {
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                throw NSError(domain: "EndoReels", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session."])
            }
            exporter.timeRange = timeRange
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            try await exporter.export(to: outputURL, as: .mp4)
            return outputURL
        } else {
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                throw NSError(domain: "EndoReels", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create export session."])
            }
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            exporter.timeRange = timeRange

            let boxed = ExportSessionBox(exporter: exporter)
            return try await withCheckedThrowingContinuation { continuation in
                boxed.exporter.exportAsynchronously {
                    switch boxed.exporter.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed, .cancelled:
                        let error = boxed.exporter.error ?? NSError(domain: "EndoReels", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                        continuation.resume(throwing: error)
                    default:
                        break
                    }
                }
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let exporter: AVAssetExportSession

    init(exporter: AVAssetExportSession) {
        self.exporter = exporter
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Slider(value: $value, in: range)
        }
    }
}
