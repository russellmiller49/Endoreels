import SwiftUI
import AVKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import EndoEditUI
import EndoEditCore

struct MediaAssetEditorView: View {
    @Binding var asset: ImportedMediaAsset
    @EnvironmentObject private var store: DemoDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportMessage: String?
    @State private var exportError: String?
    @State private var isExporting = false
    @AppStorage("useNewEditor") private var useNewEditor = false
    private let onClose: (() -> Void)?

    init(asset: Binding<ImportedMediaAsset>, onClose: (() -> Void)? = nil) {
        _asset = asset
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(asset.filename)
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    switch asset.kind {
                    case .video:
                        if useNewEditor {
                            if #available(iOS 17, *) {
                                NewVideoEditorSection(asset: $asset, exportMessage: $exportMessage, exportError: $exportError)
                            } else {
                                legacyEditor
                            }
                        } else {
                            legacyEditor
                        }
                    case .image:
                        ImageEditorSection(asset: $asset, exportMessage: $exportMessage, exportError: $exportError)
                    case .audio:
                        AudioEditorSection(asset: $asset, exportMessage: $exportMessage, exportError: $exportError)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { closeEditor() }
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

    @ViewBuilder
    private var legacyEditor: some View {
        VideoEditorSection(asset: $asset, isExporting: $isExporting, exportMessage: $exportMessage, exportError: $exportError)
    }

    private func closeEditor() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

private struct ImageEditorSection: View {
    @Binding var asset: ImportedMediaAsset
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

@available(iOS 17, *)
private struct NewVideoEditorSection: View {
    @EnvironmentObject private var store: DemoDataStore
    @Binding var asset: ImportedMediaAsset
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @State private var selectedPreset: ExportPreset = .hevcSourceMatch
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedURL: URL?
    @State private var cropEnabled = false
    @State private var cropOriginX: Double = 0
    @State private var cropOriginY: Double = 0
    @State private var cropWidth: Double = 1
    @State private var cropHeight: Double = 1
    @State private var freezeModels: [FreezeUIModel] = []
    @State private var graphVersion: Int = 0
    @State private var resolvedDuration: Double = 0
    @State private var legacyIsExporting = false

    private var sourceURL: URL { asset.proxyURL ?? asset.url }
    private var assetDuration: Double {
        resolvedDuration.finiteOrZero
    }

    var body: some View {
#if DEBUG
        let _ = print("🧱 NewVideoEditorSection init for asset=\(asset.filename)")
#endif

        return VStack(alignment: .leading, spacing: 16) {
            if !FileManager.default.fileExists(atPath: sourceURL.path) {
                missingFileView
            } else {
                let service = store.editingService(for: asset)
                VideoEditorView(engine: service.engine)
                    .id(graphVersion)
                cropControls(service: service)
                freezeControls(service: service)
                exportControls(service: service)
                legacyTrimSection
            }
        }
        .task {
#if DEBUG
            print("🔁 NewVideoEditorSection.task starting")
#endif
            let service = store.editingService(for: asset)
            await MainActor.run { syncState(with: service) }
            await loadDuration(using: service)
#if DEBUG
            print("🔁 NewVideoEditorSection.task finished (resolvedDuration=\(resolvedDuration))")
#endif
        }
        .onChange(of: asset.url) { _, _ in
#if DEBUG
            print("🔄 asset.url changed → resync")
#endif
            let service = store.editingService(for: asset)
            syncState(with: service)
            Task { await loadDuration(using: service) }
        }
    }

    private var missingFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Video file missing at \(sourceURL.lastPathComponent).")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func cropControls(service: EndoEditService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Crop", isOn: $cropEnabled)
                .onChange(of: cropEnabled) { _, _ in
                    clampCropState()
                    persistGraph(using: service)
#if DEBUG
                    print("✂️ Crop toggled: enabled=\(cropEnabled) rect={x: \(cropOriginX), y: \(cropOriginY), w: \(cropWidth), h: \(cropHeight)}")
#endif
                }

            if cropEnabled {
                cropSlider(title: "Left", value: $cropOriginX, range: 0...1) {
                    clampCropState()
                    persistGraph(using: service)
#if DEBUG
                    print("✂️ Crop updated: rect={x: \(cropOriginX), y: \(cropOriginY), w: \(cropWidth), h: \(cropHeight)}")
#endif
                }
                cropSlider(title: "Top", value: $cropOriginY, range: 0...1) {
                    clampCropState()
                    persistGraph(using: service)
#if DEBUG
                    print("✂️ Crop updated: rect={x: \(cropOriginX), y: \(cropOriginY), w: \(cropWidth), h: \(cropHeight)}")
#endif
                }
                cropSlider(title: "Width", value: $cropWidth, range: 0.1...1) {
                    clampCropState()
                    persistGraph(using: service)
#if DEBUG
                    print("✂️ Crop updated: rect={x: \(cropOriginX), y: \(cropOriginY), w: \(cropWidth), h: \(cropHeight)}")
#endif
                }
                cropSlider(title: "Height", value: $cropHeight, range: 0.1...1) {
                    clampCropState()
                    persistGraph(using: service)
#if DEBUG
                    print("✂️ Crop updated: rect={x: \(cropOriginX), y: \(cropOriginY), w: \(cropWidth), h: \(cropHeight)}")
#endif
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func freezeControls(service: EndoEditService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Freeze Frames")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    addFreeze(duration: assetDuration, using: service)
#if DEBUG
                    print("🧊 Freeze added. total=\(freezeModels.count)")
#endif
                } label: {
                    Label("Add Freeze", systemImage: "snowflake")
                }
                .buttonStyle(.bordered)
                .disabled(assetDuration <= 0)
            }

            if freezeModels.isEmpty {
                if assetDuration <= 0 {
                    Text("Freeze frames become available once video metadata finishes loading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No freeze frames configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach($freezeModels) { $model in
                    FreezeEditorRow(model: $model,
                                     maxDuration: assetDuration,
                                     onRemove: {
                                         freezeModels.removeAll { $0.id == model.id }
                                         persistGraph(using: service)
#if DEBUG
                                         print("🧊 Freeze removed. total=\(freezeModels.count)")
#endif
                                     },
                                     onUpdate: {
                                         clampFreeze(&model, maxDuration: assetDuration)
                                         persistGraph(using: service)
#if DEBUG
                                         print("🧊 Freeze updated: id=\(model.id) start=\(model.start) dur=\(model.duration)")
#endif
                                     })
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func exportControls(service: EndoEditService) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.subheadline.weight(.semibold))

            Picker("Preset", selection: $selectedPreset) {
                ForEach(ExportPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            if isExporting {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: exportProgress, total: 1.0) {
                        Text("Encoding…")
                    }
                    .progressViewStyle(.linear)
                    Text("\(Int(exportProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
#if DEBUG
                    print("📤 Export requested preset=\(selectedPreset) asset=\(asset.filename)")
#endif
                    Task { await export(service: service) }
                } label: {
                    Label("Export Clip", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            Button {
                Task {
                    let summary = await service.validateCompositionDiagnostics()
                    #if DEBUG
                    print("✅ Composition diagnostics complete")
                    #endif
                    await MainActor.run {
                        exportMessage = "Diagnostics captured. Check console.\n\n\(summary.split(separator: "\n").prefix(4).joined(separator: "\n"))"
                    }
                }
            } label: {
                Label("Validate Composition", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)

            if let exportedURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last export: \(exportedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShareLink(item: exportedURL) {
                        Label("Share Exported File", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func export(service: EndoEditService) async {
        guard !isExporting else { return }

        isExporting = true
        exportProgress = 0
        exportedURL = nil
        exportMessage = nil
        exportError = nil

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(selectedPreset.fileExtension)

        do {
            try await service.export(to: destination, preset: selectedPreset) { value in
                Task { @MainActor in
                    exportProgress = min(max(value, 0), 1)
                }
            }
            exportedURL = destination
            exportMessage = "Exported to \(destination.lastPathComponent)"
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private func cropSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, onChange: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    value.wrappedValue = newValue
                    onChange()
                }
            ), in: range)
        }
    }

    private func clampCropState() {
        // Sanitize inputs first to prevent NaN propagation
        cropWidth = sanitizeDouble(cropWidth, min: 0.1, max: 1.0)
        cropHeight = sanitizeDouble(cropHeight, min: 0.1, max: 1.0)
        cropOriginX = sanitizeDouble(cropOriginX, min: 0, max: 1.0)
        cropOriginY = sanitizeDouble(cropOriginY, min: 0, max: 1.0)

        // Now clamp origin to ensure crop doesn't exceed bounds
        cropOriginX = min(cropOriginX, 1 - cropWidth)
        cropOriginY = min(cropOriginY, 1 - cropHeight)
    }

    private func sanitizeDouble(_ value: Double, min minValue: Double, max maxValue: Double = .greatestFiniteMagnitude) -> Double {
        guard value.isFinite else { return minValue }
        return Swift.min(Swift.max(value, minValue), maxValue)
    }

    private func clampFreeze(_ model: inout FreezeUIModel, maxDuration: Double) {
        let duration = sanitizeDouble(maxDuration, min: 0.1)
        model.start = sanitizeDouble(model.start, min: 0, max: duration)
        let remainingDuration = sanitizeDouble(duration - model.start, min: 0.1)
        model.duration = sanitizeDouble(model.duration, min: 0.1, max: remainingDuration)
    }

    private func addFreeze(duration: Double, using service: EndoEditService) {
        guard duration > 0 else { return }
        let start = min(Double(freezeModels.count) * 2.0, max(duration - 0.5, 0))
        let model = FreezeUIModel(start: start, duration: min(1.0, max(duration - start, 0.5)))
        freezeModels.append(model)
        clampFreeze(&freezeModels[freezeModels.count - 1], maxDuration: assetDuration)
        persistGraph(using: service)
    }

    private func persistGraph(using service: EndoEditService) {
        var operations = service.editGraph.operations.filter { operation in
            switch operation {
            case .crop, .freeze:
                return false
            default:
                return true
            }
        }

        if cropEnabled {
            let rect = NormalizedRect(
                origin: NormalizedPoint(x: cropOriginX, y: cropOriginY),
                size: CGSize(width: cropWidth, height: cropHeight)
            ).sanitized()
            operations.append(.crop(CropOperation(rect: rect)))
        }

        if resolvedDuration > 0 {
            let maxDuration = CMTime(seconds: resolvedDuration, preferredTimescale: 600)
            for model in freezeModels {
                let startTime = CMTime(seconds: model.start, preferredTimescale: 600)
                let durationTime = CMTime(seconds: model.duration, preferredTimescale: 600)
                let segment = FreezeSegment(id: model.id,
                                            start: startTime,
                                            duration: durationTime,
                                            sourceTime: startTime,
                                            annotations: [])
                    .sanitized(maxDuration: maxDuration)
                operations.append(.freeze(segment))
            }
        }

        var newGraph = service.editGraph
        newGraph.operations = operations
        service.editGraph = newGraph
        graphVersion &+= 1

#if DEBUG
        let cropCount = operations.compactMap { if case .crop = $0 { return 1 } else { return nil } }.count
        let freezeCount = operations.compactMap { if case .freeze = $0 { return 1 } else { return nil } }.count
        print("📝 Graph persisted: cropCount=\(cropCount) freezeCount=\(freezeCount) version=\(graphVersion)")
#endif
    }

    private func syncState(with service: EndoEditService) {
#if DEBUG
        print("🔗 syncState begin: ops=\(service.editGraph.operations.count)")
#endif
        let graph = service.editGraph
        resolvedDuration = asset.duration ?? resolvedDuration
        if let cropOp = graph.operations.compactMap({ operation -> CropOperation? in
            if case let .crop(op) = operation { return op }
            return nil
        }).last {
            let sanitizedRect = cropOp.sanitized().rect
            cropEnabled = true
            cropOriginX = Double(sanitizedRect.origin.x)
            cropOriginY = Double(sanitizedRect.origin.y)
            cropWidth = Double(sanitizedRect.size.width)
            cropHeight = Double(sanitizedRect.size.height)
            clampCropState()
        } else {
            cropEnabled = false
            cropOriginX = 0
            cropOriginY = 0
            cropWidth = 1
            cropHeight = 1
        }

        let freezes = graph.operations.compactMap { operation -> FreezeSegment? in
            if case let .freeze(segment) = operation { return segment }
            return nil
        }

        freezeModels = freezes.map { segment in
            FreezeUIModel(id: segment.id,
                          start: CMTimeGetSeconds(segment.start).finiteOrZero,
                          duration: CMTimeGetSeconds(segment.duration).finiteOrZero)
        }.map { model in
            var copy = model
            clampFreeze(&copy, maxDuration: assetDuration)
            return copy
        }

#if DEBUG
        print("🔗 syncState end: cropEnabled=\(cropEnabled) freezes=\(freezeModels.count) duration=\(resolvedDuration)")
#endif
        graphVersion &+= 1
    }

    private func loadDuration(using service: EndoEditService) async {
        if let known = asset.duration {
            await MainActor.run { resolvedDuration = known }
#if DEBUG
            print("⏱️ Duration loaded: \(known)s")
#endif
            return
        }

        do {
            let duration = try await service.engine.asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration).finiteOrZero
#if DEBUG
            print("⏱️ Duration loaded: \(seconds)s")
#endif
            await MainActor.run {
                resolvedDuration = seconds
                freezeModels = freezeModels.map { model in
                    var copy = model
                    clampFreeze(&copy, maxDuration: resolvedDuration)
                    return copy
                }
                persistGraph(using: service)
            }
        } catch {
#if DEBUG
            print("⚠️ Failed to load duration: \(error.localizedDescription)")
#endif
            // Leave resolvedDuration as-is if duration fails to load.
        }
    }

    private var legacyTrimSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trim Clip")
                .font(.subheadline.weight(.semibold))
            VideoEditorSection(
                asset: $asset,
                isExporting: $legacyIsExporting,
                exportMessage: $exportMessage,
                exportError: $exportError
            )
        }
    }

    fileprivate struct FreezeUIModel: Identifiable, Hashable {
        let id: UUID
        var start: Double
        var duration: Double

        init(id: UUID = UUID(), start: Double, duration: Double) {
            self.id = id
            self.start = start
            self.duration = duration
        }
    }
}

private struct AudioEditorSection: View {
    @Binding var asset: ImportedMediaAsset
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var volume: Double = 1.0
    @State private var isGeneratingTranscript = false

    private var duration: Double {
        if let sanitized = asset.duration.sanitizedNonNegative {
            return sanitized
        }
        if let playerDuration = player?.duration {
            return playerDuration.finiteOrZero
        }
        return 0
    }

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
                asset.updateTranscript("Manual transcript checkpoint \(formatter.string(from: .now))\n• Key clinical narration captured for documentation.")
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

@available(iOS 17, *)
private struct FreezeEditorRow: View {
    @Binding var model: NewVideoEditorSection.FreezeUIModel
    let maxDuration: Double
    let onRemove: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Freeze @ \(model.start, specifier: "%.2f")s")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { model.start },
                    set: { newValue in
                        model.start = newValue
                        onUpdate()
                    }
                ), in: 0...max(maxDuration, 0.1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { model.duration },
                    set: { newValue in
                        model.duration = newValue
                        onUpdate()
                    }
                ), in: 0.1...max(maxDuration, 0.1))
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15))
        )
    }
}

private struct VideoEditorSection: View {
    @Binding var asset: ImportedMediaAsset
    @Binding var isExporting: Bool
    @Binding var exportMessage: String?
    @Binding var exportError: String?

    @StateObject private var playback = VideoPlaybackCoordinator()
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0

    private var duration: Double {
        if let sanitized = asset.duration.sanitizedNonNegative {
            return sanitized
        }
        if let playerDuration = playback.player?.currentItem?.duration.sanitizedSeconds {
            return playerDuration.finiteOrZero
        }
        return 0
    }
    private var sliderUpperBound: Double { max(duration, 1) }
    private var player: AVPlayer? { playback.player }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    Color.black.opacity(0.85)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(height: 220)
            .cornerRadius(12)
            .onAppear { configurePlayer() }
            .onChange(of: asset.proxyURL) { _, _ in configurePlayer() }
            .onChange(of: asset.url) { _, _ in configurePlayer() }

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
        }
        .onAppear { configureSliderBounds() }
        .onDisappear { playback.teardown() }
    }

    private func configurePlayer() {
        playback.teardown()

        let sourceURL = asset.proxyURL ?? asset.url
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            exportError = "Video file not found at \(sourceURL.lastPathComponent)."
            return
        }

        playback.prepare(url: sourceURL, autoPlay: false, onReady: {
            playback.player?.pause()
            playback.player?.seek(to: .zero)
        }, onFailure: { error in
            exportError = error.localizedDescription
        })
    }

    private func configureSliderBounds() {
        let defaultDuration = sliderUpperBound
        if let range = asset.trimRange {
            startTime = range.lowerBound.finiteOrZero
            endTime = max(range.upperBound.finiteOrZero, startTime)
        } else {
            startTime = 0
            endTime = defaultDuration
        }
        if endTime <= startTime {
            endTime = defaultDuration
        }
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
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
                exportMessage = "Trimmed clip saved."
                configurePlayer()
                configureSliderBounds()
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
