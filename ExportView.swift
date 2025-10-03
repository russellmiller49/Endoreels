import SwiftUI
import PDFKit
import AVFoundation

// MARK: - Export Models

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4 Video"
    case pdf = "PDF Storyboard"
    case powerpoint = "PowerPoint Deck"
    case hlsStream = "HLS Streaming"
    case archivalMaster = "Archival Master"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .mp4: return "film"
        case .pdf: return "doc.richtext"
        case .powerpoint: return "rectangle.stack.badge.play"
        case .hlsStream: return "antenna.radiowaves.left.and.right"
        case .archivalMaster: return "archivebox"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .pdf: return "pdf"
        case .powerpoint: return "pptx"
        case .hlsStream: return "m3u8"
        case .archivalMaster: return "mov"
        }
    }
}

struct ExportConfig: Identifiable {
    let id = UUID()
    var format: ExportFormat
    var includeWatermark: Bool
    var watermarkText: String
    var includeMetadataRibbon: Bool
    var quality: ExportQuality
    var includeAnnotations: Bool
    var includeCaptions: Bool

    enum ExportQuality: String, CaseIterable {
        case low = "540p (Low)"
        case medium = "720p (Medium)"
        case high = "1080p (High)"
        case master = "Original (Master)"

        var resolution: CGSize {
            switch self {
            case .low: return CGSize(width: 960, height: 540)
            case .medium: return CGSize(width: 1280, height: 720)
            case .high: return CGSize(width: 1920, height: 1080)
            case .master: return CGSize(width: 3840, height: 2160)
            }
        }
    }

    static func `default`(format: ExportFormat) -> ExportConfig {
        ExportConfig(
            format: format,
            includeWatermark: true,
            watermarkText: "EndoReels",
            includeMetadataRibbon: true,
            quality: .high,
            includeAnnotations: true,
            includeCaptions: true
        )
    }
}

struct ExportJob: Identifiable {
    let id = UUID()
    var config: ExportConfig
    var status: ExportStatus
    var progress: Double
    var startedAt: Date
    var completedAt: Date?
    var outputURL: URL?
    var errorMessage: String?

    enum ExportStatus {
        case queued
        case processing
        case completed
        case failed

        var displayName: String {
            switch self {
            case .queued: return "Queued"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }

        var color: Color {
            switch self {
            case .queued: return .gray
            case .processing: return .blue
            case .completed: return .green
            case .failed: return .red
            }
        }

        var systemImage: String {
            switch self {
            case .queued: return "clock"
            case .processing: return "gearshape.2"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    let reel: Reel
    let videoURL: URL?

    @State private var selectedFormat: ExportFormat = .mp4
    @State private var exportConfig: ExportConfig = .default(format: .mp4)
    @State private var exportJobs: [ExportJob] = []
    @State private var isExporting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Format Selection
                    formatSection

                    // Export Configuration
                    configurationSection

                    // Watermark Preview
                    if exportConfig.includeWatermark {
                        watermarkPreviewSection
                    }

                    // Export Button
                    exportButtonSection

                    // Active/Recent Exports
                    if !exportJobs.isEmpty {
                        exportsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Export & Deliverables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedFormat) { _, newFormat in
                exportConfig.format = newFormat
            }
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Format")
                .font(.headline)

            ForEach(ExportFormat.allCases) { format in
                ExportFormatCard(
                    format: format,
                    isSelected: selectedFormat == format,
                    onSelect: {
                        selectedFormat = format
                    }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Configuration")
                .font(.headline)

            if exportConfig.format == .mp4 || exportConfig.format == .archivalMaster {
                Picker("Quality", selection: $exportConfig.quality) {
                    ForEach(ExportConfig.ExportQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle("Include Watermark", isOn: $exportConfig.includeWatermark)
                .tint(.blue)

            if exportConfig.includeWatermark {
                HStack {
                    Text("Watermark Text:")
                        .font(.subheadline)
                    TextField("Text", text: $exportConfig.watermarkText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Toggle("Include Metadata Ribbon", isOn: $exportConfig.includeMetadataRibbon)
                .tint(.blue)

            if exportConfig.format == .mp4 || exportConfig.format == .archivalMaster {
                Toggle("Include Annotations", isOn: $exportConfig.includeAnnotations)
                    .tint(.blue)

                Toggle("Include Captions", isOn: $exportConfig.includeCaptions)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var watermarkPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watermark Preview")
                .font(.headline)

            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 180)
                    .overlay(
                        Text("Video Preview")
                            .foregroundStyle(.white.opacity(0.5))
                    )

                VStack(alignment: .trailing, spacing: 4) {
                    Text(exportConfig.watermarkText)
                        .font(.caption.weight(.semibold))
                    Text(reel.author.name)
                        .font(.caption2)
                    Text(reel.author.verification.tier.displayName)
                        .font(.caption2)
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var exportButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isExporting {
                HStack {
                    ProgressView()
                    Text("Preparing export...")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    startExport()
                } label: {
                    Label("Start Export", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            Text("Exported files will include:")
                .font(.caption.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Label("Author attribution & verification badge", systemImage: "checkmark.seal")
                if exportConfig.includeWatermark {
                    Label("Visible watermark", systemImage: "waterbottle")
                }
                if exportConfig.includeMetadataRibbon {
                    Label("Procedure, anatomy, and pathology metadata", systemImage: "doc.text")
                }
                Label("Timestamp of export", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var exportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exports (\(exportJobs.count))")
                .font(.headline)

            ForEach(exportJobs) { job in
                ExportJobRow(job: job, onShare: {
                    shareExport(job)
                })
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Export Logic

    private func startExport() {
        isExporting = true

        let job = ExportJob(
            config: exportConfig,
            status: .queued,
            progress: 0,
            startedAt: .now
        )

        exportJobs.insert(job, at: 0)

        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let index = exportJobs.firstIndex(where: { $0.id == job.id }) {
                exportJobs[index].status = .processing
            }
        }

        simulateExport(jobID: job.id)
    }

    private func simulateExport(jobID: UUID) {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            guard let index = exportJobs.firstIndex(where: { $0.id == jobID }) else {
                timer.invalidate()
                return
            }

            exportJobs[index].progress += 0.05

            if exportJobs[index].progress >= 1.0 {
                timer.invalidate()
                completeExport(jobID: jobID)
            }
        }
    }

    private func completeExport(jobID: UUID) {
        guard let index = exportJobs.firstIndex(where: { $0.id == jobID }) else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndoReelsExports", isDirectory: true)
            .appendingPathComponent("\(reel.title).\(exportJobs[index].config.format.fileExtension)")

        exportJobs[index].status = .completed
        exportJobs[index].completedAt = .now
        exportJobs[index].outputURL = outputURL
        exportJobs[index].progress = 1.0
        isExporting = false

        // Generate actual file based on format
        switch exportJobs[index].config.format {
        case .pdf:
            generatePDF(job: exportJobs[index])
        case .powerpoint:
            generatePowerPoint(job: exportJobs[index])
        case .mp4, .archivalMaster, .hlsStream:
            generateVideo(job: exportJobs[index])
        }
    }

    private func generatePDF(job: ExportJob) {
        // PDF generation logic
        let pdfMetaData = [
            kCGPDFContextCreator: "EndoReels",
            kCGPDFContextAuthor: reel.author.name,
            kCGPDFContextTitle: reel.title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            // Cover page
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let titleString = reel.title as NSString
            titleString.draw(at: CGPoint(x: 50, y: 100), withAttributes: titleAttributes)

            // Metadata
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let metaString = "\(reel.author.name) • \(reel.procedure) • \(reel.anatomy)" as NSString
            metaString.draw(at: CGPoint(x: 50, y: 150), withAttributes: metaAttributes)

            // Steps
            for (index, step) in reel.steps.enumerated() {
                context.beginPage()

                let stepTitle = "Step \(index + 1): \(step.title)" as NSString
                stepTitle.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

                let stepText = step.keyPoint as NSString
                stepText.draw(
                    in: CGRect(x: 50, y: 100, width: pageWidth - 100, height: 200),
                    withAttributes: metaAttributes
                )
            }

            // Watermark on last page
            if job.config.includeWatermark {
                let watermarkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                let watermark = "\(job.config.watermarkText) • \(Date().formatted(date: .abbreviated, time: .omitted))" as NSString
                watermark.draw(at: CGPoint(x: 50, y: pageHeight - 50), withAttributes: watermarkAttributes)
            }
        }

        // Save PDF
        if let outputURL = job.outputURL {
            try? data.write(to: outputURL)
        }
    }

    private func generatePowerPoint(job: ExportJob) {
        // PowerPoint generation (simplified - in production use proper PPTX library)
        // This would generate an XML-based .pptx file with slides for each step
        print("PowerPoint export not fully implemented in demo")
    }

    private func generateVideo(job: ExportJob) {
        // Video export with watermark overlay
        // This would use AVFoundation composition to add watermark and metadata
        print("Video export with watermark not fully implemented in demo")
    }

    private func shareExport(_ job: ExportJob) {
        guard job.outputURL != nil else { return }
        // Share using UIActivityViewController
    }
}

// MARK: - Supporting Views

private struct ExportFormatCard: View {
    let format: ExportFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: format.systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(format.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(formatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var formatDescription: String {
        switch format {
        case .mp4:
            return "Standard video file for sharing and presentations"
        case .pdf:
            return "Printable storyboard with key frames and teaching points"
        case .powerpoint:
            return "Editable slide deck with embedded media"
        case .hlsStream:
            return "Adaptive streaming for web delivery"
        case .archivalMaster:
            return "Uncompressed master for long-term storage"
        }
    }
}

private struct ExportJobRow: View {
    let job: ExportJob
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: job.status.systemImage)
                    .foregroundStyle(job.status.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.config.format.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(job.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if job.status == .completed {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if job.status == .processing {
                ProgressView(value: job.progress)
                    .tint(.blue)
                Text("\(Int(job.progress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.status == .completed, let completedAt = job.completedAt {
                Text("Completed \(relativeDate(from: completedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.status == .failed, let error = job.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    ExportView(
        reel: DemoDataStore().reels.first!,
        videoURL: nil
    )
}
