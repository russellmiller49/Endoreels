import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers

struct CreatorView: View {
    @EnvironmentObject private var store: DemoDataStore
    @EnvironmentObject private var appState: AppState
    let onClose: (() -> Void)?

    @State private var title: String = "Stent Rescue Run-through"
    @State private var abstract: String = "Teaching reel for airway granulation rescue with privacy checklist."
    @State private var serviceLine: ServiceLine = .pulmonary
    @State private var procedure: String = "Diagnostic Bronchoscopy"
    @State private var detailedProcedure: String = ""
    @State private var anatomy: String = "Left Main Bronchus"
    @State private var pathology: String = "Granulation Tissue"
    @State private var device: String = "Ultraflex Stent"
    @State private var difficulty: String = "Advanced"
    @State private var enableCME: Bool = true
    @State private var includeVoiceover: Bool = true
    @State private var showPrivacyReport = false
    @State private var showReelPreview = false
    @State private var showCreditsHistory = false
    @State private var stepDrafts: [StepDraft] = StepDraft.sample
    @State private var selectedStepID: UUID?
    @State private var editingStepDraft: StepDraft?
    @State private var stepPendingDeletion: StepDraft?
    @State private var draftNotes: String = """
    Focus on demonstrating balloon dilation, instrument handling tips, and immediate airway reassessment.
    """.trimmingCharacters(in: .whitespacesAndNewlines)
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isImportingFiles = false
    @State private var importError: String?
    @State private var editingAssetIdentifier: AssetIdentifier?
    @State private var isProcessingImport = false

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                creditsBanner
                caseOutline
                storyboard
                mediaLibrary
                privacyChecklist
                publishingCard
            }
            .padding()
        }
        .navigationTitle("Creator Studio")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let onClose {
                    Button("Cancel") { onClose() }
                }
            }
        }
        .sheet(isPresented: $showPrivacyReport) {
            PrivacyReviewSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreditsHistory) {
            NavigationStack {
                CreditsHistoryView(store: appState.creditsStore)
            }
        }
        .sheet(isPresented: $showReelPreview) {
            ReelPreviewSheet(
                title: title,
                abstract: abstract,
                serviceLine: serviceLine,
                procedure: procedure,
                detailedProcedure: detailedProcedure,
                anatomy: anatomy,
                pathology: pathology,
                device: device,
                difficulty: difficulty,
                enableCME: enableCME,
                includeVoiceover: includeVoiceover,
                draftNotes: draftNotes,
                steps: stepDrafts,
                assets: store.importedAssets
            )
        }
        .onChange(of: serviceLine, initial: false) { oldValue, newValue in
            let options = newValue.defaultProcedures
            if !options.contains(procedure) {
                procedure = options.first ?? ""
            }
        }
        .task { await appState.creditsStore.refresh() }
        .fileImporter(isPresented: $isImportingFiles, allowedContentTypes: [.movie, .image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task { await importFileURLs(urls) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { newValue in if !newValue { importError = nil } }
        )) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .sheet(item: $editingAssetIdentifier) { identifier in
            if let index = store.importedAssets.firstIndex(where: { $0.id == identifier.id }) {
                MediaAssetEditorView(asset: $store.importedAssets[index])
            } else {
                Text("Asset unavailable")
            }
        }
        .sheet(item: $editingStepDraft) { draft in
            NavigationStack {
                StepEditorSheet(
                    step: draft,
                    availableAssets: store.importedAssets,
                    onSave: { updated in
                        applyUpdatedStep(updated)
                        editingStepDraft = nil
                    },
                    onCancel: { editingStepDraft = nil }
                )
            }
        }
        .confirmationDialog("Remove Step?", isPresented: Binding(
            get: { stepPendingDeletion != nil },
            set: { newValue in if !newValue { stepPendingDeletion = nil } }
        ), presenting: stepPendingDeletion) { step in
            Button("Delete", role: .destructive) { deleteStep(step.id) }
            Button("Cancel", role: .cancel) {}
        } message: { step in
            Text("Deleting Step \(step.order) will remove its attachments.")
        }
    }

    private var creditsBanner: some View {
        CreditsBanner(store: appState.creditsStore) {
            showCreditsHistory = true
        }
    }

    private var caseOutline: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Case Outline")
            VStack(alignment: .leading, spacing: 12) {
                CaseTextField(title: "Title", text: $title)
                CaseTextField(title: "Abstract", text: $abstract, axis: .vertical)
                ServiceLinePicker(selection: $serviceLine)
                CasePicker(title: "Procedure", selection: $procedure, options: currentProcedureOptions)
                CaseTextField(title: "Detailed Procedure", text: $detailedProcedure, axis: .vertical)
                CaseTextField(title: "Anatomy", text: $anatomy)
                CaseTextField(title: "Pathology", text: $pathology)
                CaseTextField(title: "Device", text: $device)
                CasePicker(title: "Difficulty", selection: $difficulty, options: ["Intro", "Intermediate", "Advanced"])
                Toggle("Offer CME credit", isOn: $enableCME)
                Toggle("Include narration / voiceover", isOn: $includeVoiceover)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Production Notes")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $draftNotes)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var storyboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Storyboard Builder")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(stepDrafts) { step in
                    let linkedAssets = step.mediaAssetIDs.compactMap { id in
                        store.importedAssets.first(where: { $0.id == id })
                    }
                    let linkedAudioAssets = step.audioAssetIDs.compactMap { id in
                        store.importedAssets.first(where: { $0.id == id })
                    }
                    let isFirst = step.id == stepDrafts.first?.id
                    let isLast = step.id == stepDrafts.last?.id
                    TimelineStepCard(
                        step: step,
                        isSelected: step.id == selectedStepID,
                        linkedAssets: linkedAssets,
                        audioAssets: linkedAudioAssets,
                        onToggleTranscript: {
                            toggleTranscriptPreference(for: step.id)
                        },
                        onEdit: { editingStepDraft = step },
                        onDuplicate: { duplicateStep(step.id) },
                        onMoveUp: { moveStep(step.id, direction: -1) },
                        onMoveDown: { moveStep(step.id, direction: 1) },
                        onDelete: { stepPendingDeletion = step },
                        isFirst: isFirst,
                        isLast: isLast
                    )
                        .onTapGesture { selectedStepID = step.id }
                }
                Button(action: addStep) {
                    Label("Add storyboard step", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var mediaLibrary: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Media Library")
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker(selection: $photoSelections, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                    Label("Import from Photos", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .onChange(of: photoSelections, initial: false) { oldValue, newValue in
                    Task { await handlePhotoSelections(newValue) }
                }

                Button {
                    isImportingFiles = true
                } label: {
                    Label("Import from Files/Drive", systemImage: "externaldrive")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                if isProcessingImport {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Processing imports...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.importedAssets.isEmpty {
                    Text("No media imported yet. Use the buttons above to pull clips from Photos, iCloud, Google Drive, or OneDrive via the Files picker.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.importedAssets) { asset in
                        let isAttached = selectedStepID.flatMap { id in
                            guard let step = stepDrafts.first(where: { $0.id == id }) else { return false }
                            return step.mediaAssetIDs.contains(asset.id) || step.audioAssetIDs.contains(asset.id)
                        } ?? false
                        MediaAssetRow(
                            asset: asset,
                            canAttach: selectedStepID != nil,
                            isAttached: isAttached,
                            attachAction: { attachAsset(asset) },
                            editAction: { editingAssetIdentifier = AssetIdentifier(id: asset.id) }
                        )
                        .contextMenu {
                            let contextLabel = asset.kind == .audio ? (isAttached ? "Remove audio" : "Attach audio") : (isAttached ? "Remove from selected step" : "Attach to selected step")
                            Button(contextLabel, action: { attachAsset(asset) })
                                .disabled(selectedStepID == nil)
                            Button("Edit media", action: { editingAssetIdentifier = AssetIdentifier(id: asset.id) })
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var privacyChecklist: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Privacy & De-ID")
            VStack(alignment: .leading, spacing: 12) {
                Label("Quarantine upload bucket configured", systemImage: "checkmark.shield")
                    .foregroundStyle(.green)
                Label("Automated OCR & face scan queued", systemImage: "bolt.shield")
                    .foregroundStyle(.orange)
                Label("Human moderator assignment pending", systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(.secondary)
                Button {
                    showPrivacyReport = true
                } label: {
                    Label("Run PHI heatmap & checklist", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var publishingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Publishing")
            VStack(alignment: .leading, spacing: 12) {
                Label("Feed visibility: Specialists in Pulmonology", systemImage: "rectangle.stack.badge.play")
                Label("Collections: Airway Emergencies Sprint", systemImage: "bookmark.collection")
                Label("Trust tier: Clinician (Blue)", systemImage: "checkmark.seal")
                Button {
                    Task {
                        try? await appState.creditsStore.deductCredits(amount: 1, reelID: UUID(), reason: "Enhanced processing (placeholder)")
                    }
                } label: {
                    Label("Process with AI (1 credit)", systemImage: "bolt.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                if let onClose {
                    Button(role: .destructive) {
                        onClose()
                    } label: {
                        Label("Cancel & Return Home", systemImage: "house")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    showReelPreview = true
                } label: {
                    Label("Review Full Reel", systemImage: "rectangle.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    // simulate publish
                } label: {
                    Label("Submit for Review", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                Button(role: .cancel) {
                    // simulate saving draft
                } label: {
                    Label("Save Draft", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func options(from values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }

    private var currentProcedureOptions: [String] {
        serviceLine.defaultProcedures
    }

    private func addStep() {
        let newOrder = (stepDrafts.max(by: { $0.order < $1.order })?.order ?? 0) + 1
        let step = StepDraft(
            order: newOrder,
            title: "New Step \(newOrder)",
            focus: "Key point placeholder",
            captureType: .video,
            overlays: [],
            mediaAssetIDs: [],
            audioAssetIDs: [],
            prefersAutoTranscript: false
        )
        stepDrafts.append(step)
        selectedStepID = step.id
    }

    private func applyUpdatedStep(_ updated: StepDraft) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == updated.id }) else { return }
        stepDrafts[index] = updated
        renumberSteps()
    }

    private func duplicateStep(_ id: UUID) {
        guard let source = stepDrafts.first(where: { $0.id == id }) else { return }
        guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        let newOrder = min(stepDrafts.count + 1, source.order + 1)
        let clone = source.duplicated(withOrder: newOrder)
        stepDrafts.insert(clone, at: index + 1)
        selectedStepID = clone.id
        renumberSteps()
    }

    private func deleteStep(_ id: UUID) {
        stepDrafts.removeAll { $0.id == id }
        if selectedStepID == id {
            selectedStepID = stepDrafts.first?.id
        }
        renumberSteps()
    }

    private func moveStep(_ id: UUID, direction: Int) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard target >= 0 && target < stepDrafts.count else { return }
        let step = stepDrafts.remove(at: index)
        stepDrafts.insert(step, at: target)
        selectedStepID = step.id
        renumberSteps()
    }

    private func renumberSteps() {
        for idx in stepDrafts.indices {
            stepDrafts[idx].order = idx + 1
        }
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
    }

    private func attachAsset(_ asset: MediaAsset) {
        guard let selectedStepID, let index = stepDrafts.firstIndex(where: { $0.id == selectedStepID }) else { return }
        var updatedStep = stepDrafts[index]

        switch asset.kind {
        case .audio:
            if let existingIndex = updatedStep.audioAssetIDs.firstIndex(of: asset.id) {
                updatedStep.audioAssetIDs.remove(at: existingIndex)
            } else {
                if updatedStep.audioAssetIDs.count >= 1 {
                    updatedStep.audioAssetIDs.removeFirst()
                }
                updatedStep.audioAssetIDs.append(asset.id)
                if updatedStep.prefersAutoTranscript {
                    generateTranscripts(for: updatedStep)
                }
            }
        case .video, .image:
            if let existingIndex = updatedStep.mediaAssetIDs.firstIndex(of: asset.id) {
                updatedStep.mediaAssetIDs.remove(at: existingIndex)
            } else {
                if updatedStep.mediaAssetIDs.count >= 2 {
                    updatedStep.mediaAssetIDs.removeFirst()
                }
                updatedStep.mediaAssetIDs.append(asset.id)
            }

            let attachedAssets = updatedStep.mediaAssetIDs.compactMap { id in
                store.importedAssets.first(where: { $0.id == id })
            }

            if attachedAssets.contains(where: { $0.kind == .video }) {
                updatedStep.captureType = .video
            } else if attachedAssets.contains(where: { $0.kind == .image }) {
                updatedStep.captureType = .image
            }
        }

        stepDrafts[index] = updatedStep
    }

    private func toggleTranscriptPreference(for stepID: UUID) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == stepID }) else { return }
        stepDrafts[index].prefersAutoTranscript.toggle()
        if stepDrafts[index].prefersAutoTranscript {
            generateTranscripts(for: stepDrafts[index])
        }
    }

    private func generateTranscripts(for step: StepDraft) {
        for audioID in step.audioAssetIDs {
            guard let assetIndex = store.importedAssets.firstIndex(where: { $0.id == audioID }) else { continue }
            var asset = store.importedAssets[assetIndex]
            if asset.transcript == nil || asset.transcript?.isEmpty == true {
                asset.updateTranscript(sampleTranscript(for: asset))
                store.updateImportedAsset(asset)
            }
        }
    }

    private func sampleTranscript(for asset: MediaAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "AI transcript generated \(formatter.string(from: .now)). Highlights key narration for review."
    }

    private func handlePhotoSelections(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isProcessingImport = true }
        defer {
            Task { @MainActor in
                isProcessingImport = false
                photoSelections = []
            }
        }

        for item in items {
            do {
                if let asset = try await importPhotoItem(item) {
                    await MainActor.run { store.addImportedAsset(asset) }
                }
            } catch {
                await MainActor.run { importError = error.localizedDescription }
            }
        }
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async throws -> MediaAsset? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            if let movie = try await item.loadTransferable(type: MovieFile.self) {
                return try await MediaAsset.make(from: movie.url, source: .photoLibrary)
            }
        }

        if let data = try await item.loadTransferable(type: Data.self) {
            let tempURL = tempURL(for: UUID().uuidString + ".asset")
            try data.write(to: tempURL)
            return try await MediaAsset.make(from: tempURL, source: .photoLibrary)
        }

        return nil
    }

    private func importFileURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        await MainActor.run { isProcessingImport = true }
        defer {
            Task { @MainActor in isProcessingImport = false }
        }

        for url in urls {
            var didStartAccess = false
            if url.startAccessingSecurityScopedResource() {
                didStartAccess = true
            }
            defer {
                if didStartAccess { url.stopAccessingSecurityScopedResource() }
            }

            let destination = tempURL(for: url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
                let asset = try await MediaAsset.make(from: destination, source: .filesProvider)
                await MainActor.run { store.addImportedAsset(asset) }
            } catch {
                await MainActor.run { importError = error.localizedDescription }
            }
        }
    }

    private func tempURL(for filename: String) -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("EndoReelsMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(filename)
    }
}

private struct StepDraft: Identifiable {
    enum CaptureType: String, CaseIterable, Identifiable {
        case video
        case image
        case dicom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .video: return "Video"
            case .image: return "Image"
            case .dicom: return "DICOM"
            }
        }

        var systemImage: String {
            switch self {
            case .video: return "play.rectangle"
            case .image: return "photo"
            case .dicom: return "waveform" // illustrative icon
            }
        }
    }

    let id = UUID()
    var order: Int
    var title: String
    var focus: String
    var captureType: CaptureType
    var overlays: [String]
    var mediaAssetIDs: [MediaAsset.ID]
    var audioAssetIDs: [MediaAsset.ID]
    var prefersAutoTranscript: Bool

    func duplicated(withOrder order: Int) -> StepDraft {
        StepDraft(
            order: order,
            title: title + " Copy",
            focus: focus,
            captureType: captureType,
            overlays: overlays,
            mediaAssetIDs: mediaAssetIDs,
            audioAssetIDs: audioAssetIDs,
            prefersAutoTranscript: prefersAutoTranscript
        )
    }

    static let sample: [StepDraft] = [
        StepDraft(order: 1, title: "Airway Inspection", focus: "Identify granulation tissue and stent margins.", captureType: .video, overlays: ["Arrow on obstruction", "Text: keep suction ready"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false),
        StepDraft(order: 2, title: "Balloon Dilation", focus: "12mm balloon inflation with visual cues.", captureType: .video, overlays: ["Timer overlay", "Callout for pressure"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false),
        StepDraft(order: 3, title: "Post-Procedure Review", focus: "Show restored lumen and mucosal perfusion.", captureType: .image, overlays: ["Before/after split"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false)
    ]
}

private struct TimelineStepCard: View {
    let step: StepDraft
    let isSelected: Bool
    let linkedAssets: [MediaAsset]
    let audioAssets: [MediaAsset]
    let onToggleTranscript: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Step \(step.order)", systemImage: step.captureType.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isSelected {
                    Text("Editing")
                        .font(.caption.bold())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            Text(step.title)
                .font(.headline)
            Text(step.focus)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let primaryAsset = linkedAssets.first {
                MediaAssetPreview(asset: primaryAsset)
            }
            if linkedAssets.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional media attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(linkedAssets.dropFirst()), id: \.id) { asset in
                        Label(asset.filename, systemImage: asset.kind == .video ? "play.rectangle" : "photo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Label("Picture-in-picture will be used", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            if !audioAssets.isEmpty {
                AudioAttachmentSummary(
                    assets: audioAssets,
                    prefersTranscript: step.prefersAutoTranscript,
                    onToggleTranscript: onToggleTranscript
                )
            }
            if !step.overlays.isEmpty {
                AnnotationChips(annotations: step.overlays)
            }
            Divider()
            HStack {
                Button(action: onEdit) {
                    Label("Edit Details", systemImage: "slider.horizontal.3")
                }
                Spacer()
                Menu {
                    Button("Duplicate Step", action: onDuplicate)
                    Button("Move Up", action: onMoveUp)
                        .disabled(isFirst)
                    Button("Move Down", action: onMoveDown)
                        .disabled(isLast)
                    Button("Delete Step", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .font(.caption)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StepEditorSheet: View {
    @State private var workingStep: StepDraft
    @State private var newOverlayText: String = ""
    let availableAssets: [MediaAsset]
    let onSave: (StepDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(step: StepDraft, availableAssets: [MediaAsset], onSave: @escaping (StepDraft) -> Void, onCancel: @escaping () -> Void) {
        _workingStep = State(initialValue: step)
        self.availableAssets = availableAssets
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $workingStep.title)
                TextField("Focus", text: $workingStep.focus, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                Picker("Capture Type", selection: $workingStep.captureType) {
                    ForEach(StepDraft.CaptureType.allCases) { type in
                        Label(type.label, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
            }

            Section("Teaching Overlays") {
                if workingStep.overlays.isEmpty {
                    Text("No overlays yet. Use the field below to add annotations.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(workingStep.overlays.enumerated()), id: \.offset) { index, overlay in
                        HStack {
                            Text(overlay)
                            Spacer()
                            Button(role: .destructive) {
                                workingStep.overlays.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    TextField("Add overlay note", text: $newOverlayText)
                    Button("Add") {
                        let trimmed = newOverlayText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        workingStep.overlays.append(trimmed)
                        newOverlayText = ""
                    }
                    .disabled(newOverlayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if !visualAttachments.isEmpty {
                Section("Visual Attachments") {
                    ForEach(visualAttachments, id: \.id) { asset in
                        AttachmentRow(asset: asset) {
                            workingStep.mediaAssetIDs.removeAll { $0 == asset.id }
                        }
                    }
                }
            }

            if !audioAttachments.isEmpty {
                Section("Audio Overlays") {
                    Toggle("Generate transcript automatically", isOn: $workingStep.prefersAutoTranscript)
                    ForEach(audioAttachments, id: \.id) { asset in
                        AttachmentRow(asset: asset) {
                            workingStep.audioAssetIDs.removeAll { $0 == asset.id }
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Step \(workingStep.order)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(workingStep)
                    dismiss()
                }
            }
        }
    }

    private var visualAttachments: [MediaAsset] {
        workingStep.mediaAssetIDs.compactMap { id in
            availableAssets.first(where: { $0.id == id })
        }
    }

    private var audioAttachments: [MediaAsset] {
        workingStep.audioAssetIDs.compactMap { id in
            availableAssets.first(where: { $0.id == id })
        }
    }

    private struct AttachmentRow: View {
        let asset: MediaAsset
        let onRemove: () -> Void

        var body: some View {
            HStack {
                Label(asset.filename, systemImage: icon)
                Spacer()
                Button("Remove", role: .destructive, action: onRemove)
                    .buttonStyle(.bordered)
                    .font(.caption)
            }
        }

        private var icon: String {
            switch asset.kind {
            case .video: return "play.rectangle"
            case .image: return "photo"
            case .audio: return "speaker.wave.2.fill"
            }
        }
    }
}

private struct AudioAttachmentSummary: View {
    let assets: [MediaAsset]
    let prefersTranscript: Bool
    let onToggleTranscript: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Attached audio", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onToggleTranscript) {
                    Label(preferButtonTitle, systemImage: prefersTranscript ? "text.badge.checkmark" : "text.book.closed")
                }
                .buttonStyle(.bordered)
                .font(.caption2)
            }

            ForEach(assets, id: \.id) { asset in
                VStack(alignment: .leading, spacing: 4) {
                    Label(asset.filename, systemImage: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if prefersTranscript {
                        Text(asset.transcript ?? "Transcript will be generated once published.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var preferButtonTitle: String {
        prefersTranscript ? "Hide transcript" : "Auto transcript"
    }
}

private struct MediaAssetPreview: View {
    let asset: MediaAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(asset.filename, systemImage: headerIcon)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if let duration = asset.duration, asset.kind != .image {
                    Label("\(Int(duration.rounded())) s", systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            switch asset.kind {
            case .video:
                if let preview = asset.thumbnail {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    placeholder(height: 140)
                }
            case .image:
                if let image = asset.editedImage ?? asset.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    placeholder(height: 140)
                }
            case .audio:
                AudioPreviewWaveform(duration: asset.duration ?? 0)
                    .frame(height: 80)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
            }

            if let transcript = asset.transcript, !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Transcript", systemImage: "text.alignleft")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }

    @ViewBuilder
    private func placeholder(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1))
            .overlay {
                Image(systemName: placeholderIcon)
                    .font(.largeTitle)
                    .foregroundStyle(.gray)
            }
            .frame(height: height)
    }

    private var placeholderIcon: String {
        switch asset.kind {
        case .video: return "play.rectangle"
        case .image: return "photo"
        case .audio: return "waveform"
        }
    }

    private var headerIcon: String {
        switch asset.kind {
        case .video: return "play.rectangle"
        case .image: return "photo"
        case .audio: return "waveform.circle"
        }
    }
}

private struct AudioPreviewWaveform: View {
    let duration: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                let bars = 30
                let barWidth = size.width / CGFloat(bars)
                for index in 0..<bars {
                    let normalized = CGFloat((Double(index % 6) + 1) / 6.0)
                    let height = size.height * (0.3 + 0.7 * normalized)
                    let x = CGFloat(index) * barWidth
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth * 0.6, height: height)
                    context.fill(Path(rect), with: .color(.blue.opacity(0.6)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Label("Audio", systemImage: "waveform.circle")
                Spacer()
                if duration > 0 {
                    Text("\(Int(duration.rounded()))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct MediaAssetRow: View {
    let asset: MediaAsset
    let canAttach: Bool
    let isAttached: Bool
    let attachAction: () -> Void
    let editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Label(asset.filename, systemImage: headerIcon)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(asset.source == .photoLibrary ? "Photos" : "Files/Drive")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            MediaAssetPreview(asset: asset)

            HStack {
                Button(action: attachAction) {
                    Label(attachButtonTitle, systemImage: attachButtonIcon)
                }
                .buttonStyle(.bordered)
                .disabled(!canAttach)

                Button(action: editAction) {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .font(.caption)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
    }

    private var headerIcon: String {
        switch asset.kind {
        case .video: return "play.rectangle"
        case .image: return "photo"
        case .audio: return "speaker.wave.2.fill"
        }
    }

    private var attachButtonTitle: String {
        switch asset.kind {
        case .audio:
            return isAttached ? "Remove Audio" : "Attach Audio"
        default:
            return isAttached ? "Remove from Step" : "Attach to Step"
        }
    }

    private var attachButtonIcon: String {
        switch asset.kind {
        case .audio:
            return isAttached ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .video:
            return isAttached ? "link.slash" : "link"
        case .image:
            return isAttached ? "link.slash" : "link"
        }
    }
}

private struct CaseTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if axis == .vertical {
                TextEditor(text: $text)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2))
                    )
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

private struct CasePicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select" : selection)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
            }
        }
    }
}

private struct ServiceLinePicker: View {
    @Binding var selection: ServiceLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Service Line")
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                ForEach(ServiceLine.allCases) { line in
                    Button(line.displayName) { selection = line }
                }
            } label: {
                HStack {
                    Text(selection.displayName)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
            }
        }
    }
}

private struct ReelPreviewSheet: View {
    let title: String
    let abstract: String
    let serviceLine: ServiceLine
    let procedure: String
    let detailedProcedure: String
    let anatomy: String
    let pathology: String
    let device: String
    let difficulty: String
    let enableCME: Bool
    let includeVoiceover: Bool
    let draftNotes: String
    let steps: [StepDraft]
    let assets: [MediaAsset]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewSection
                    if hasNotes {
                        notesSection
                    }
                    storyboardSection
                }
                .padding()
            }
            .navigationTitle("Reel Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var hasNotes: Bool {
        !draftNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasDetailedProcedure: Bool {
        !detailedProcedure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(abstract)
                .font(.body)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Service line: \(serviceLine.displayName)", systemImage: "list.bullet.rectangle")
                Label(procedure, systemImage: "scalpel")
                if hasDetailedProcedure {
                    Label("Detailed: \(detailedProcedure)", systemImage: "doc.badge.ellipsis")
                }
                Label(anatomy, systemImage: "lungs.fill")
                Label(pathology, systemImage: "waveform.path.ecg")
                Label(device, systemImage: "stethoscope")
                Label("Difficulty: \(difficulty)", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(enableCME ? "CME enabled" : "CME disabled", systemImage: enableCME ? "checkmark.seal" : "xmark.seal")
                    .foregroundStyle(enableCME ? .blue : .secondary)
                Label(includeVoiceover ? "Narration included" : "Narration pending", systemImage: includeVoiceover ? "mic" : "mic.slash")
                    .foregroundStyle(includeVoiceover ? .orange : .secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Production Notes")
                .font(.title3.bold())
            Text(draftNotes)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var storyboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Storyboard Preview")
                    .font(.title3.bold())
                Spacer()
                Text("\(steps.count) step\(steps.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if steps.isEmpty {
                Label("No storyboard steps yet", systemImage: "rectangle.dashed.badge.record")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps) { step in
                        PreviewStepCard(
                            step: step,
                            assets: assets(for: step),
                            audioAssets: audioAssets(for: step)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func assets(for step: StepDraft) -> [MediaAsset] {
        step.mediaAssetIDs.compactMap { id in
            assets.first { $0.id == id }
        }
    }

    private func audioAssets(for step: StepDraft) -> [MediaAsset] {
        step.audioAssetIDs.compactMap { id in
            assets.first { $0.id == id }
        }
    }
}

private struct PreviewStepCard: View {
    let step: StepDraft
    let assets: [MediaAsset]
    let audioAssets: [MediaAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Step \(step.order)", systemImage: step.captureType.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(step.captureType.label)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            Text(step.title)
                .font(.headline)
            Text(step.focus)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            mediaSection
            if !step.overlays.isEmpty {
                AnnotationChips(annotations: step.overlays)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var mediaSection: some View {
        if assets.isEmpty {
            Label("No media attached", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        } else if assets.count == 1, let primary = assets.first {
            MediaPlaybackView(asset: primary, height: 200)
        } else if assets.count >= 2 {
            PictureInPicturePreview(primary: assets[0], secondary: assets[1])
        }

        if !assets.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Media attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if assets.count >= 2 {
                    Label("Picture-in-picture preview", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                ForEach(assets, id: \.id) { asset in
                    Label(asset.filename, systemImage: asset.kind == .video ? "play.rectangle" : "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if !audioAssets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Audio overlays")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(audioAssets, id: \.id) { asset in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(asset.filename, systemImage: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let transcript = asset.transcript, !transcript.isEmpty, step.prefersAutoTranscript {
                            Text(transcript)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        } else if step.prefersAutoTranscript {
                            Text("Transcript pending generation")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct MediaPlaybackView: View {
    let asset: MediaAsset
    var height: CGFloat
    var fillsHorizontally: Bool = true

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if asset.kind == .video {
                Color.black.opacity(0.85)
                if let player {
                    VideoPlayer(player: player)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            } else if let image = asset.editedImage ?? asset.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        Image(systemName: asset.kind == .video ? "play.rectangle" : "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(height: height)
        .frame(maxWidth: fillsHorizontally ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            guard asset.kind == .video, player == nil else { return }
            player = AVPlayer(url: asset.url)
            player?.seek(to: .zero)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

private struct PictureInPicturePreview: View {
    let primary: MediaAsset
    let secondary: MediaAsset

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MediaPlaybackView(asset: primary, height: 200)
            MediaPlaybackView(asset: secondary, height: 100, fillsHorizontally: false)
                .frame(width: 160, height: 100)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
                )
                .padding(12)
        }
    }
}

private struct PrivacyReviewSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Automated checks") {
                    Label("OCR flagged 2 overlays", systemImage: "eye.trianglebadge.exclamation")
                        .foregroundStyle(.orange)
                    Label("Face detector: no matches", systemImage: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.green)
                    Label("Audio scan: awaiting review", systemImage: "waveform")
                        .foregroundStyle(.orange)
                }
                Section("Action items") {
                    Text("Upload clean narration or enable synthetic TTS.")
                    Text("Confirm overlay masks on Step 2.")
                    Text("Complete privacy attestation prior to publish.")
                }
                Section("Audit trail") {
                    Label("Moderator assigned: Dr. Sun", systemImage: "person.2.wave.2")
                    Label("Last run: 4 minutes ago", systemImage: "clock")
                    Label("Trace ID: REEL-48219", systemImage: "number")
                }
            }
            .navigationTitle("Privacy Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    NavigationStack {
        CreatorView()
    }
    .environmentObject(DemoDataStore())
}

private struct AssetIdentifier: Identifiable {
    let id: MediaAsset.ID
}

private struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("EndoReelsMedia", isDirectory: true)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            }
            let fileURL = destination.appendingPathComponent("\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: fileURL)
            return MovieFile(url: fileURL)
        }
    }
}
