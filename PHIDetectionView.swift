import SwiftUI
import AVKit
import Vision

// MARK: - PHI Detection Models

struct PHIDetectionResult: Identifiable {
    let id = UUID()
    var frameTime: Double
    var findingType: PHIFindingType
    var boundingBox: CGRect
    var confidence: Float
    var detectedText: String
    var mitigation: MitigationAction
    var isResolved: Bool

    enum PHIFindingType: String, CaseIterable {
        case patientName = "Patient Name"
        case dateOfBirth = "Date of Birth"
        case mrn = "Medical Record Number"
        case overlayText = "Overlay Text"
        case face = "Face"
        case institutionLogo = "Institution Logo"
        case metadata = "Metadata"

        var systemImage: String {
            switch self {
            case .patientName, .dateOfBirth, .mrn: return "person.text.rectangle"
            case .overlayText: return "text.viewfinder"
            case .face: return "face.smiling"
            case .institutionLogo: return "building.2"
            case .metadata: return "doc.text.magnifyingglass"
            }
        }

        var color: Color {
            switch self {
            case .patientName, .dateOfBirth, .mrn: return .red
            case .overlayText: return .orange
            case .face: return .purple
            case .institutionLogo: return .blue
            case .metadata: return .yellow
            }
        }
    }

    enum MitigationAction: String {
        case blur = "Blur"
        case mask = "Mask"
        case crop = "Crop"
        case replace = "Replace Text"
        case strip = "Strip Metadata"
        case pending = "Pending Review"

        var systemImage: String {
            switch self {
            case .blur: return "camera.filters"
            case .mask: return "rectangle.dashed"
            case .crop: return "crop"
            case .replace: return "text.badge.xmark"
            case .strip: return "trash"
            case .pending: return "clock"
            }
        }
    }
}

struct PHIMask: Identifiable {
    let id: UUID
    var startFrame: Double
    var endFrame: Double
    var boundingBox: CGRect
    var trackingPoints: [CGPoint]
    var isAutoTracked: Bool
    var opacity: Double

    init(id: UUID = UUID(), startFrame: Double, endFrame: Double, boundingBox: CGRect, trackingPoints: [CGPoint] = [], isAutoTracked: Bool = true, opacity: Double = 1.0) {
        self.id = id
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.boundingBox = boundingBox
        self.trackingPoints = trackingPoints
        self.isAutoTracked = isAutoTracked
        self.opacity = opacity
    }
}

// MARK: - PHI Detection View

struct PHIDetectionView: View {
    @Binding var phiFindings: [PHIDetectionResult]
    @Binding var phiMasks: [PHIMask]
    let videoURL: URL?
    let videoDuration: Double

    @State private var currentTime: Double = 0
    @State private var player: AVPlayer?
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var showHeatmap = true
    @State private var selectedFinding: PHIDetectionResult?
    @State private var drawingMask = false
    @State private var maskStartPoint: CGPoint?
    @State private var maskEndPoint: CGPoint?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Video Player with Overlay
                    videoSection

                    // Scan Controls
                    scanControlsSection

                    // PHI Heatmap
                    if showHeatmap {
                        heatmapSection
                    }

                    // Findings List
                    findingsSection

                    // Masks List
                    masksSection

                    // Pre-Publish Gate
                    publishGateSection
                }
                .padding()
            }
            .navigationTitle("PHI Detection & De-ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        resolveAllFindings()
                    } label: {
                        Label("Resolve All", systemImage: "checkmark.circle")
                    }
                    .disabled(phiFindings.allSatisfy { $0.isResolved })
                }
            }
            .onAppear { setupPlayer() }
        }
    }

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Preview with PHI Overlay")
                .font(.headline)

            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .frame(height: 250)
                        .overlay(
                            Text("No video loaded")
                                .foregroundStyle(.white)
                        )
                }

                // PHI Finding Overlays
                GeometryReader { geometry in
                    ForEach(currentFrameFindings) { finding in
                        phiFindingOverlay(finding, in: geometry.size)
                    }

                    ForEach(currentFrameMasks) { mask in
                        phiMaskOverlay(mask, in: geometry.size)
                    }
                }
                .frame(height: 250)
                .allowsHitTesting(false)

                // Drawing Mask
                if drawingMask, let start = maskStartPoint, let end = maskEndPoint {
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .background(Color.red.opacity(0.2))
                        .frame(
                            width: abs(end.x - start.x),
                            height: abs(end.y - start.y)
                        )
                        .position(
                            x: (start.x + end.x) / 2,
                            y: (start.y + end.y) / 2
                        )
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if drawingMask {
                            if maskStartPoint == nil {
                                maskStartPoint = value.startLocation
                            }
                            maskEndPoint = value.location
                        }
                    }
                    .onEnded { value in
                        if drawingMask, let start = maskStartPoint, let end = maskEndPoint {
                            addManualMask(start: start, end: end)
                            maskStartPoint = nil
                            maskEndPoint = nil
                            drawingMask = false
                        }
                    }
            )

            HStack(spacing: 12) {
                Slider(value: $currentTime, in: 0...max(videoDuration, 1))
                    .onChange(of: currentTime) { _, newValue in
                        seekPlayer(to: newValue)
                    }

                Button {
                    drawingMask.toggle()
                } label: {
                    Image(systemName: drawingMask ? "rectangle.dashed.badge.checkmark" : "rectangle.dashed")
                }
                .buttonStyle(.bordered)
                .tint(drawingMask ? .blue : .gray)
            }

            Text("Time: \(currentTime, specifier: "%.2f")s / \(videoDuration, specifier: "%.2f")s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var currentFrameFindings: [PHIDetectionResult] {
        phiFindings.filter { !$0.isResolved && abs($0.frameTime - currentTime) < 0.5 }
    }

    private var currentFrameMasks: [PHIMask] {
        phiMasks.filter { $0.startFrame <= currentTime && currentTime <= $0.endFrame }
    }

    private func phiFindingOverlay(_ finding: PHIDetectionResult, in size: CGSize) -> some View {
        Rectangle()
            .stroke(finding.findingType.color, lineWidth: 3)
            .background(finding.findingType.color.opacity(0.2))
            .frame(
                width: finding.boundingBox.width * size.width,
                height: finding.boundingBox.height * size.height
            )
            .position(
                x: finding.boundingBox.midX * size.width,
                y: finding.boundingBox.midY * size.height
            )
            .overlay(
                Text(finding.findingType.rawValue)
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(
                        x: finding.boundingBox.midX * size.width,
                        y: finding.boundingBox.minY * size.height - 15
                    )
            )
    }

    private func phiMaskOverlay(_ mask: PHIMask, in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(mask.opacity))
            .frame(
                width: mask.boundingBox.width * size.width,
                height: mask.boundingBox.height * size.height
            )
            .position(
                x: mask.boundingBox.midX * size.width,
                y: mask.boundingBox.midY * size.height
            )
            .overlay(
                Image(systemName: "eye.slash")
                    .foregroundStyle(.white.opacity(0.7))
                    .position(
                        x: mask.boundingBox.midX * size.width,
                        y: mask.boundingBox.midY * size.height
                    )
            )
    }

    private var scanControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automated PHI Scan")
                .font(.headline)

            if isScanning {
                VStack(spacing: 8) {
                    ProgressView(value: scanProgress)
                    Text("Scanning: \(Int(scanProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    runPHIScan()
                } label: {
                    Label("Run OCR & Face Detection", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Toggle("Show PHI Heatmap", isOn: $showHeatmap)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHI Heatmap")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 80)

                    ForEach(phiFindings) { finding in
                        phiHeatmapBar(finding, containerWidth: geometry.size.width)
                    }

                    let offset = (currentTime / max(videoDuration, 1)) * geometry.size.width * 0.85
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 80)
                        .offset(x: offset)
                }
            }
            .frame(height: 80)

            HStack(spacing: 16) {
                ForEach(PHIDetectionResult.PHIFindingType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 8, height: 8)
                        Text(type.rawValue)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func phiHeatmapBar(_ finding: PHIDetectionResult, containerWidth: CGFloat) -> some View {
        let offset = (finding.frameTime / max(videoDuration, 1)) * containerWidth * 0.85

        return Rectangle()
            .fill(finding.findingType.color.opacity(finding.isResolved ? 0.3 : 0.8))
            .frame(width: 4, height: 60)
            .offset(x: offset)
    }

    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PHI Findings (\(phiFindings.count))")
                    .font(.headline)
                Spacer()
                Text("\(phiFindings.filter { $0.isResolved }.count) resolved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if phiFindings.isEmpty {
                Text("No PHI detected yet. Run the automated scan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach($phiFindings) { $finding in
                    PHIFindingRow(finding: $finding, onResolve: {
                        applyMitigation(finding)
                    })
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var masksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applied Masks (\(phiMasks.count))")
                .font(.headline)

            if phiMasks.isEmpty {
                Text("No masks applied")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(phiMasks) { mask in
                    PHIMaskRow(mask: mask, onDelete: {
                        phiMasks.removeAll { $0.id == mask.id }
                    })
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var publishGateSection: some View {
        let unresolvedCount = phiFindings.filter { !$0.isResolved }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: unresolvedCount == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(unresolvedCount == 0 ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(unresolvedCount == 0 ? "Ready to Publish" : "Action Required")
                        .font(.headline)
                    Text(unresolvedCount == 0 ? "All PHI findings resolved" : "\(unresolvedCount) unresolved findings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if unresolvedCount > 0 {
                Text("⚠️ This reel cannot be published until all PHI findings are resolved.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(unresolvedCount == 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(unresolvedCount == 0 ? Color.green : Color.orange, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper Functions

    private func setupPlayer() {
        guard let videoURL = videoURL else { return }
        player = AVPlayer(url: videoURL)
    }

    private func seekPlayer(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    private func runPHIScan() {
        isScanning = true
        scanProgress = 0

        // Simulate scanning
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            scanProgress += 0.05
            if scanProgress >= 1.0 {
                timer.invalidate()
                isScanning = false
                generateMockFindings()
            }
        }
    }

    private func generateMockFindings() {
        // Simulate OCR and face detection results
        phiFindings = [
            PHIDetectionResult(
                frameTime: 2.5,
                findingType: .overlayText,
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05),
                confidence: 0.92,
                detectedText: "Patient: John Doe",
                mitigation: .mask,
                isResolved: false
            ),
            PHIDetectionResult(
                frameTime: 5.8,
                findingType: .face,
                boundingBox: CGRect(x: 0.6, y: 0.3, width: 0.2, height: 0.3),
                confidence: 0.88,
                detectedText: "",
                mitigation: .blur,
                isResolved: false
            ),
            PHIDetectionResult(
                frameTime: 10.2,
                findingType: .mrn,
                boundingBox: CGRect(x: 0.05, y: 0.85, width: 0.25, height: 0.05),
                confidence: 0.95,
                detectedText: "MRN: 123456",
                mitigation: .mask,
                isResolved: false
            )
        ]
    }

    private func applyMitigation(_ finding: PHIDetectionResult) {
        // Create a mask for this finding
        let mask = PHIMask(
            startFrame: max(finding.frameTime - 1, 0),
            endFrame: min(finding.frameTime + 1, videoDuration),
            boundingBox: finding.boundingBox,
            isAutoTracked: true
        )
        phiMasks.append(mask)

        // Mark as resolved
        if let index = phiFindings.firstIndex(where: { $0.id == finding.id }) {
            phiFindings[index].isResolved = true
        }
    }

    private func addManualMask(start: CGPoint, end: CGPoint) {
        let rect = CGRect(
            x: min(start.x, end.x) / 250,
            y: min(start.y, end.y) / 250,
            width: abs(end.x - start.x) / 250,
            height: abs(end.y - start.y) / 250
        )

        let mask = PHIMask(
            startFrame: currentTime,
            endFrame: min(currentTime + 3, videoDuration),
            boundingBox: rect,
            isAutoTracked: false
        )
        phiMasks.append(mask)
    }

    private func resolveAllFindings() {
        for i in phiFindings.indices where !phiFindings[i].isResolved {
            applyMitigation(phiFindings[i])
        }
    }
}

private struct PHIFindingRow: View {
    @Binding var finding: PHIDetectionResult
    let onResolve: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.findingType.systemImage)
                .foregroundStyle(finding.findingType.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(finding.findingType.rawValue)
                    .font(.subheadline.weight(.semibold))

                if !finding.detectedText.isEmpty {
                    Text(finding.detectedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label("Frame \(finding.frameTime, specifier: "%.1f")s", systemImage: "timer")
                    Label("\(Int(finding.confidence * 100))% confidence", systemImage: "checkmark.circle")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("Mitigation:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label(finding.mitigation.rawValue, systemImage: finding.mitigation.systemImage)
                        .font(.caption2)
                }
            }

            Spacer()

            if finding.isResolved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: onResolve) {
                    Text("Resolve")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(finding.findingType.color)
            }
        }
        .padding()
        .background(finding.isResolved ? Color.green.opacity(0.05) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(finding.isResolved ? Color.green : finding.findingType.color, lineWidth: 1)
        )
    }
}

private struct PHIMaskRow: View {
    let mask: PHIMask
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: mask.isAutoTracked ? "wand.and.stars" : "hand.draw")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(mask.isAutoTracked ? "Auto-tracked Mask" : "Manual Mask")
                    .font(.subheadline.weight(.semibold))
                Text("\(mask.startFrame, specifier: "%.1f")s → \(mask.endFrame, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PHIDetectionView(
        phiFindings: .constant([]),
        phiMasks: .constant([]),
        videoURL: nil,
        videoDuration: 60
    )
}
