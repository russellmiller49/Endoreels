import SwiftUI
import AVFoundation

// MARK: - QC Models

struct QCIssue: Identifiable {
    let id = UUID()
    var category: QCCategory
    var severity: Severity
    var title: String
    var description: String
    var location: IssueLocation?
    var autoFixable: Bool
    var isFixed: Bool

    enum QCCategory: String, CaseIterable {
        case video = "Video Quality"
        case audio = "Audio Quality"
        case accessibility = "Accessibility"
        case safety = "Safety & PHI"
        case metadata = "Metadata"
        case clinical = "Clinical Integrity"

        var systemImage: String {
            switch self {
            case .video: return "video"
            case .audio: return "waveform"
            case .accessibility: return "eye"
            case .safety: return "shield"
            case .metadata: return "doc.text"
            case .clinical: return "stethoscope"
            }
        }

        var color: Color {
            switch self {
            case .video: return .blue
            case .audio: return .purple
            case .accessibility: return .green
            case .safety: return .red
            case .metadata: return .orange
            case .clinical: return .indigo
            }
        }
    }

    enum Severity: String {
        case error = "Error"
        case warning = "Warning"
        case info = "Info"

        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }

        var systemImage: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    struct IssueLocation {
        var timeRange: ClosedRange<Double>?
        var frameNumber: Int?
        var stepIndex: Int?
    }
}

// MARK: - Pre-Publish Checklist

struct PublishChecklist: Identifiable {
    let id = UUID()
    var items: [ChecklistItem]

    struct ChecklistItem: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var isRequired: Bool
        var isCompleted: Bool
        var category: ChecklistCategory

        enum ChecklistCategory: String {
            case consent = "Patient Consent"
            case phi = "PHI Removal"
            case quality = "Quality Standards"
            case metadata = "Metadata & Tags"
            case disclosure = "Disclosure"
        }
    }

    var completionPercentage: Double {
        let completed = items.filter { $0.isCompleted }.count
        return items.isEmpty ? 0 : Double(completed) / Double(items.count)
    }

    var canPublish: Bool {
        items.filter { $0.isRequired }.allSatisfy { $0.isCompleted }
    }

    static func standard() -> PublishChecklist {
        PublishChecklist(items: [
            ChecklistItem(
                title: "Patient Consent Obtained",
                description: "Written or documented verbal consent for case publication",
                isRequired: true,
                isCompleted: false,
                category: .consent
            ),
            ChecklistItem(
                title: "PHI Scan Completed",
                description: "Automated PHI detection run and all findings resolved",
                isRequired: true,
                isCompleted: false,
                category: .phi
            ),
            ChecklistItem(
                title: "No Unmasked Patient Identifiers",
                description: "All names, MRNs, DOBs, and faces removed or masked",
                isRequired: true,
                isCompleted: false,
                category: .phi
            ),
            ChecklistItem(
                title: "Audio PHI Cleared",
                description: "Narration reviewed and no patient-identifying information present",
                isRequired: true,
                isCompleted: false,
                category: .phi
            ),
            ChecklistItem(
                title: "Captions Added",
                description: "All narration and key audio transcribed with captions",
                isRequired: true,
                isCompleted: false,
                category: .quality
            ),
            ChecklistItem(
                title: "Metadata Complete",
                description: "Procedure, anatomy, pathology, device, and tags entered",
                isRequired: true,
                isCompleted: false,
                category: .metadata
            ),
            ChecklistItem(
                title: "Teaching Points Defined",
                description: "Key learning objectives clearly stated",
                isRequired: true,
                isCompleted: false,
                category: .quality
            ),
            ChecklistItem(
                title: "Video Enhancements Disclosed",
                description: "Any stabilization, speed changes, or edits noted",
                isRequired: false,
                isCompleted: false,
                category: .disclosure
            ),
            ChecklistItem(
                title: "Clinical Review (if applicable)",
                description: "Peer review completed for complex or unusual cases",
                isRequired: false,
                isCompleted: false,
                category: .quality
            ),
            ChecklistItem(
                title: "Institutional Approval",
                description: "If required by your institution, compliance approved",
                isRequired: false,
                isCompleted: false,
                category: .consent
            )
        ])
    }
}

// MARK: - Quality Control View

struct QualityControlView: View {
    @Binding var issues: [QCIssue]
    @Binding var checklist: PublishChecklist
    let videoURL: URL?
    let narrations: [NarrationSegment]
    let steps: [TemplateStep]

    @State private var isRunningQC = false
    @State private var qcProgress: Double = 0
    @State private var selectedCategory: QCIssue.QCCategory? = nil
    @State private var showOnlyUnfixed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // QC Summary
                    summarySection

                    // Run QC Button
                    qcControlsSection

                    // Issues List
                    issuesSection

                    // Pre-Publish Checklist
                    checklistSection

                    // Publish Gate
                    publishGateSection
                }
                .padding()
            }
            .navigationTitle("Quality Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        autoFixIssues()
                    } label: {
                        Label("Auto-Fix", systemImage: "wand.and.stars")
                    }
                    .disabled(issues.filter { $0.autoFixable && !$0.isFixed }.isEmpty)
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                qcSummaryTile(
                    title: "Errors",
                    count: issues.filter { $0.severity == .error && !$0.isFixed }.count,
                    color: .red,
                    icon: "xmark.circle.fill"
                )

                qcSummaryTile(
                    title: "Warnings",
                    count: issues.filter { $0.severity == .warning && !$0.isFixed }.count,
                    color: .orange,
                    icon: "exclamationmark.triangle.fill"
                )

                qcSummaryTile(
                    title: "Info",
                    count: issues.filter { $0.severity == .info && !$0.isFixed }.count,
                    color: .blue,
                    icon: "info.circle.fill"
                )
            }

            HStack(spacing: 12) {
                Image(systemName: checklist.canPublish ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title)
                    .foregroundStyle(checklist.canPublish ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(checklist.canPublish ? "Ready to Publish" : "Checklist Incomplete")
                        .font(.headline)
                    Text("\(Int(checklist.completionPercentage * 100))% complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(checklist.canPublish ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func qcSummaryTile(title: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var qcControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Linting")
                .font(.headline)

            if isRunningQC {
                VStack(spacing: 8) {
                    ProgressView(value: qcProgress)
                    Text("Running checks... \(Int(qcProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    runQualityChecks()
                } label: {
                    Label("Run All QC Checks", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Issues (\(filteredIssues.count))")
                    .font(.headline)

                Spacer()

                Toggle("Unfixed Only", isOn: $showOnlyUnfixed)
                    .toggleStyle(.button)
                    .font(.caption)
            }

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("All")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == nil ? Color.blue : Color(.tertiarySystemBackground))
                            .foregroundStyle(selectedCategory == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }

                    ForEach(QCIssue.QCCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.rawValue, systemImage: category.systemImage)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? category.color : Color(.tertiarySystemBackground))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if filteredIssues.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No issues found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach($issues.filter { issue in
                    filterIssue(issue.wrappedValue)
                }) { $issue in
                    QCIssueRow(issue: $issue, onFix: {
                        fixIssue(issue)
                    })
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var filteredIssues: [QCIssue] {
        issues.filter { filterIssue($0) }
    }

    private func filterIssue(_ issue: QCIssue) -> Bool {
        let categoryMatch = selectedCategory == nil || issue.category == selectedCategory
        let fixedMatch = !showOnlyUnfixed || !issue.isFixed
        return categoryMatch && fixedMatch
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pre-Publish Checklist")
                .font(.headline)

            ProgressView(value: checklist.completionPercentage)
                .tint(.blue)

            ForEach($checklist.items) { $item in
                ChecklistItemRow(item: $item)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var publishGateSection: some View {
        let errorCount = issues.filter { $0.severity == .error && !$0.isFixed }.count
        let canPublish = checklist.canPublish && errorCount == 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: canPublish ? "checkmark.seal.fill" : "exclamationmark.octagon.fill")
                    .font(.title2)
                    .foregroundStyle(canPublish ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(canPublish ? "Ready for Publication" : "Publication Blocked")
                        .font(.headline)
                    if !canPublish {
                        if errorCount > 0 {
                            Text("\(errorCount) critical error(s) must be fixed")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !checklist.canPublish {
                            Text("Required checklist items incomplete")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("All quality checks passed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if canPublish {
                Button {
                    // Proceed to publish
                } label: {
                    Label("Proceed to Publishing", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .background(canPublish ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(canPublish ? Color.green : Color.red, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - QC Logic

    private func runQualityChecks() {
        isRunningQC = true
        qcProgress = 0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            qcProgress += 0.02
            if qcProgress >= 1.0 {
                timer.invalidate()
                isRunningQC = false
                generateQCIssues()
            }
        }
    }

    private func generateQCIssues() {
        issues = [
            // Video issues
            QCIssue(
                category: .video,
                severity: .warning,
                title: "Black Frame Detected",
                description: "Frame at 3.2s appears completely black",
                location: QCIssue.IssueLocation(timeRange: 3.2...3.2),
                autoFixable: true,
                isFixed: false
            ),
            QCIssue(
                category: .video,
                severity: .info,
                title: "Low Contrast Segment",
                description: "Contrast below optimal range from 10-15s",
                location: QCIssue.IssueLocation(timeRange: 10...15),
                autoFixable: true,
                isFixed: false
            ),

            // Audio issues
            QCIssue(
                category: .audio,
                severity: .warning,
                title: "Audio Clipping Detected",
                description: "Peaks exceed -3dB at 22s",
                location: QCIssue.IssueLocation(timeRange: 22...23),
                autoFixable: true,
                isFixed: false
            ),
            QCIssue(
                category: .audio,
                severity: .error,
                title: "Loudness Too Low",
                description: "Audio loudness is -24 LUFS, target is -16 LUFS",
                location: nil,
                autoFixable: true,
                isFixed: false
            ),

            // Accessibility
            QCIssue(
                category: .accessibility,
                severity: .error,
                title: "Missing Captions",
                description: "Narration present but no captions provided",
                location: nil,
                autoFixable: false,
                isFixed: false
            ),
            QCIssue(
                category: .accessibility,
                severity: .warning,
                title: "Small Text in Annotation",
                description: "Text size below 18pt may be hard to read",
                location: QCIssue.IssueLocation(timeRange: 8...12),
                autoFixable: true,
                isFixed: false
            ),

            // Safety & PHI
            QCIssue(
                category: .safety,
                severity: .error,
                title: "PHI Not Cleared",
                description: "2 unresolved PHI findings remain",
                location: nil,
                autoFixable: false,
                isFixed: false
            ),

            // Metadata
            QCIssue(
                category: .metadata,
                severity: .warning,
                title: "Missing Tags",
                description: "Fewer than 3 tags added; consider adding more for discoverability",
                location: nil,
                autoFixable: false,
                isFixed: false
            ),

            // Clinical Integrity
            QCIssue(
                category: .clinical,
                severity: .info,
                title: "Excessive Sharpening",
                description: "Sharpening exceeds recommended clinical fidelity limits",
                location: QCIssue.IssueLocation(timeRange: 5...8),
                autoFixable: true,
                isFixed: false
            )
        ]
    }

    private func autoFixIssues() {
        for i in issues.indices where issues[i].autoFixable && !issues[i].isFixed {
            issues[i].isFixed = true
        }
    }

    private func fixIssue(_ issue: QCIssue) {
        if let index = issues.firstIndex(where: { $0.id == issue.id }) {
            issues[index].isFixed = true
        }
    }
}

private struct QCIssueRow: View {
    @Binding var issue: QCIssue
    let onFix: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.severity.systemImage)
                .foregroundStyle(issue.severity.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))

                Text(issue.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let location = issue.location, let range = location.timeRange {
                    Label("At \(range.lowerBound, specifier: "%.1f")s", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(issue.category.rawValue, systemImage: issue.category.systemImage)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(issue.category.color.opacity(0.2))
                        .clipShape(Capsule())

                    if issue.autoFixable {
                        Label("Auto-fixable", systemImage: "wand.and.stars")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if issue.isFixed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if issue.autoFixable {
                Button(action: onFix) {
                    Text("Fix")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(issue.severity.color)
            }
        }
        .padding()
        .background(issue.isFixed ? Color.green.opacity(0.05) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(issue.isFixed ? Color.green : issue.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct ChecklistItemRow: View {
    @Binding var item: PublishChecklist.ChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(item.isCompleted)

                    if item.isRequired {
                        Text("REQUIRED")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(item.isCompleted ? Color.green.opacity(0.05) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    QualityControlView(
        issues: .constant([]),
        checklist: .constant(PublishChecklist.standard()),
        videoURL: nil,
        narrations: [],
        steps: []
    )
}
