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
    @State private var showOnboarding = false
    @State private var stepDrafts: [StepDraft] = StepDraft.sample
    @State private var selectedStepID: UUID?
    @State private var editingStepDraft: StepDraft?
    @State private var stepPendingDeletion: StepDraft?
    @State private var hasAppliedUserRole = false
    @State private var draftNotes: String = """
    Focus on demonstrating balloon dilation, instrument handling tips, and immediate airway reassessment.
    """.trimmingCharacters(in: .whitespacesAndNewlines)
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isImportingFiles = false
    @State private var importError: String?
    @State private var editingAssetIdentifier: AssetIdentifier?
    @State private var isProcessingImport = false
    @State private var selectedTemplate: StoryboardTemplate = .demo
    @State private var selectedCasePreset: CasePreset = .demoPulmonary

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        scrollContainer
        .navigationTitle("Creator Studio")
        .toolbar { creatorToolbar }
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
        .task {
            guard !hasAppliedUserRole, let role = appState.currentUser.role else { return }
            serviceLine = role
            hasAppliedUserRole = true
            if role == .gastroenterology {
                applyCasePreset(.demoGastro)
            } else {
                applyCasePreset(.demoPulmonary)
            }
        }
        .onChange(of: appState.currentUser.role, initial: false) { oldValue, newValue in
            guard let newValue else { return }
            serviceLine = newValue
        }
        .onChange(of: store.importedAssets) { _, newAssets in
            if newAssets.isEmpty {
                editingAssetIdentifier = nil
            } else if let currentID = editingAssetIdentifier?.id,
                      !newAssets.contains(where: { $0.id == currentID }) {
                editingAssetIdentifier = AssetIdentifier(id: newAssets.first!.id)
            } else if editingAssetIdentifier == nil, let first = newAssets.first {
                editingAssetIdentifier = AssetIdentifier(id: first.id)
            }
        }
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
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
                    onCancel: { editingStepDraft = nil },
                    openMediaEditor: { assetID in
                        openMediaEditor(for: assetID)
                    }
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

    private var templateSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start from template")
                .font(.subheadline.weight(.semibold))
            Picker("Storyboard Template", selection: $selectedTemplate) {
                ForEach(StoryboardTemplate.allCases) { template in
                    Text(template.displayName).tag(template)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTemplate) { _, newValue in
                applyTemplate(newValue)
            }
            Button("Reset to Selected Template") {
                applyTemplate(selectedTemplate)
            }
            .buttonStyle(.bordered)
            Button {
                showOnboarding = true
            } label: {
                Label("View Demo Tour", systemImage: "sparkles.tv")
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var presetSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build setup")
                .font(.subheadline.weight(.semibold))
            Picker("Case preset", selection: $selectedCasePreset) {
                ForEach(CasePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCasePreset) { _, newValue in
                applyCasePreset(newValue)
            }
            Button("Reset Case Details") {
                applyCasePreset(selectedCasePreset)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            creditsBanner
            presetSwitcher
            caseOutline
            templateSwitcher
            mediaLibrary
            storyboard
            privacyChecklist
            publishingCard
        }
    }

    private var scrollContainer: some View {
        ScrollViewReader { proxy in
            ScrollView {
                contentSections
                    .padding()
            }
            .onChange(of: editingAssetIdentifier) { _, newValue in
                guard newValue != nil else { return }
                withAnimation {
                    proxy.scrollTo(ScrollTarget.mediaEditor, anchor: .top)
                }
            }
        }
    }

    private var creatorToolbar: some ToolbarContent {
        ContentToolbar(onClose: onClose)
    }

    private struct ContentToolbar: ToolbarContent {
        let onClose: (() -> Void)?

        var body: some ToolbarContent {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                if let onClose {
                    Button("Cancel") { onClose() }
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let onClose {
                    Button("Home") { onClose() }
                }
            }
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
                Button(action: { addStep() }) {
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
            VStack(alignment: .leading, spacing: 16) {
                if let identifier = editingAssetIdentifier,
                   let index = store.importedAssets.firstIndex(where: { $0.id == identifier.id }) {
                    MediaAssetEditorView(asset: $store.importedAssets[index], onClose: { editingAssetIdentifier = nil })
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.15))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if !store.importedAssets.isEmpty {
                    Text("Select a media item below to open it in the editor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if editingAssetIdentifier != nil || !store.importedAssets.isEmpty {
                    Divider()
                }

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
                            editAction: { openMediaEditor(for: asset.id) }
                        )
                        .contextMenu {
                            let contextLabel = asset.kind == .audio ? (isAttached ? "Remove audio" : "Attach audio") : (isAttached ? "Remove from selected step" : "Attach to selected step")
                            Button(contextLabel, action: { attachAsset(asset) })
                                .disabled(selectedStepID == nil)
                            Button("Edit media", action: { openMediaEditor(for: asset.id) })
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .id(ScrollTarget.mediaEditor)
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
                Label("Collections: Airway Emergencies Sprint", systemImage: "books.vertical")
                Label("Trust tier: Clinician (Blue)", systemImage: "checkmark.seal")
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

    private func addStep(triggerTemplateUpdate: Bool = true) {
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
        if triggerTemplateUpdate {
            selectedTemplate = .blank
        }
    }

    private func applyUpdatedStep(_ updated: StepDraft) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == updated.id }) else { return }
        stepDrafts[index] = updated
        selectedStepID = updated.id
        renumberSteps()
    }

    private func duplicateStep(_ id: UUID) {
        guard let source = stepDrafts.first(where: { $0.id == id }) else { return }
        guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        let newOrder = min(stepDrafts.count + 1, source.order + 1)
        let clone = source.duplicated(withOrder: newOrder)
        stepDrafts.insert(clone, at: index + 1)
        selectedStepID = clone.id
        selectedTemplate = .blank
        renumberSteps()
    }

    private func deleteStep(_ id: UUID) {
        stepDrafts.removeAll { $0.id == id }
        if selectedStepID == id {
            selectedStepID = stepDrafts.first?.id
        }
        selectedTemplate = .blank
        renumberSteps()
    }

    private func moveStep(_ id: UUID, direction: Int) {
        guard let index = stepDrafts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + direction
        guard target >= 0 && target < stepDrafts.count else { return }
        let step = stepDrafts.remove(at: index)
        stepDrafts.insert(step, at: target)
        selectedStepID = step.id
        selectedTemplate = .blank
        renumberSteps()
    }

    private func renumberSteps() {
        for idx in stepDrafts.indices {
            stepDrafts[idx].order = idx + 1
        }
    }

    private func applyTemplate(_ template: StoryboardTemplate) {
        selectedTemplate = template
        switch template {
        case .demo:
            stepDrafts = StepDraft.sample
        case .blank:
            stepDrafts = []
            addStep(triggerTemplateUpdate: false)
        }
        selectedStepID = stepDrafts.first?.id
    }

    private func applyCasePreset(_ preset: CasePreset) {
        selectedCasePreset = preset
        switch preset {
        case .demoPulmonary:
            title = "Stent Rescue Run-through"
            abstract = "Teaching reel for airway granulation rescue with privacy checklist."
            serviceLine = .pulmonary
            procedure = "Diagnostic Bronchoscopy"
            detailedProcedure = "Bronchial stent rescue with balloon dilation"
            anatomy = "Left Main Bronchus"
            pathology = "Granulation Tissue"
            device = "Boston Scientific Ultraflex Stent"
            difficulty = "Advanced"
            enableCME = true
            includeVoiceover = true
            draftNotes = """
            Focus on demonstrating balloon dilation, instrument handling tips, and immediate airway reassessment.
            """.trimmingCharacters(in: .whitespacesAndNewlines)
            stepDrafts = StepDraft.sample
        case .demoGastro:
            title = "Cold EMR of Right Colon Lesion"
            abstract = "Technique breakdown for a 35mm LST treated with cold EMR and traction clips."
            serviceLine = .gastroenterology
            procedure = "Endoscopic Mucosal Resection"
            detailedProcedure = "Cold piecemeal EMR of large right colon LST"
            anatomy = "Ascending Colon"
            pathology = "LST-G Tumor"
            device = "Olympus EndoTherapy Snare"
            difficulty = "Advanced"
            enableCME = true
            includeVoiceover = true
            draftNotes = """
            Highlight submucosal lift technique, traction clip placement, and closure strategy.
            """.trimmingCharacters(in: .whitespacesAndNewlines)
            stepDrafts = StepDraft.demoGastro
        case .blank:
            title = "Untitled Case"
            abstract = ""
            serviceLine = appState.currentUser.role ?? .pulmonary
            procedure = ""
            detailedProcedure = ""
            anatomy = ""
            pathology = ""
            device = ""
            difficulty = "Intro"
            enableCME = false
            includeVoiceover = false
            draftNotes = ""
            stepDrafts = []
            addStep(triggerTemplateUpdate: false)
        }
        selectedStepID = stepDrafts.first?.id
        if preset != .blank {
            selectedTemplate = .demo
        } else {
            selectedTemplate = .blank
        }
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
    }

    private func openMediaEditor(for assetID: ImportedMediaAsset.ID) {
        editingAssetIdentifier = AssetIdentifier(id: assetID)
    }

    private func attachAsset(_ asset: ImportedMediaAsset) {
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
                if asset.kind == .video {
                    updatedStep.videoEdits.removeValue(forKey: asset.id)
                }
            } else {
                if updatedStep.mediaAssetIDs.count >= 2 {
                    let removedID = updatedStep.mediaAssetIDs.removeFirst()
                    if let removed = store.importedAssets.first(where: { $0.id == removedID && $0.kind == .video }) {
                        updatedStep.videoEdits.removeValue(forKey: removed.id)
                    }
                }
                updatedStep.mediaAssetIDs.append(asset.id)
                if asset.kind == .video {
                    updatedStep.videoEdits[asset.id] = updatedStep.videoEdits[asset.id] ?? StepDraft.VideoEditing()
                }
            }

            let attachedAssets = updatedStep.mediaAssetIDs.compactMap { id in
                store.importedAssets.first(where: { $0.id == id })
            }

            if attachedAssets.contains(where: { $0.kind == .video }) {
                for video in attachedAssets where video.kind == .video {
                    if updatedStep.videoEdits[video.id] == nil {
                        updatedStep.videoEdits[video.id] = StepDraft.VideoEditing()
                    }
                }
            } else {
                updatedStep.videoEdits = [:]
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

    private func sampleTranscript(for asset: ImportedMediaAsset) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Manual transcript captured \(formatter.string(from: .now)). Highlights key narration for review."
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
                    await MainActor.run {
                        store.addImportedAsset(asset)
                        appState.prepareDraftForImportedVideo(asset, title: title, difficulty: difficulty, store: store)
                        openMediaEditor(for: asset.id)
                    }
                }
            } catch {
                await MainActor.run { importError = error.localizedDescription }
            }
        }
    }

    private func importPhotoItem(_ item: PhotosPickerItem) async throws -> ImportedMediaAsset? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            if let movie = try await item.loadTransferable(type: MovieFile.self) {
                return try await ImportedMediaAsset.make(from: movie.url, source: .photoLibrary)
            }
        }

        if let data = try await item.loadTransferable(type: Data.self) {
            let imageContentType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) })
            let fileExtension = imageContentType?.preferredFilenameExtension ?? "jpg"
            let tempURL = tempURL(for: "\(UUID().uuidString).\(fileExtension)")
            try data.write(to: tempURL)
            return try await ImportedMediaAsset.make(from: tempURL, source: .photoLibrary)
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
                let asset = try await ImportedMediaAsset.make(from: destination, source: .filesProvider)
                await MainActor.run {
                    store.addImportedAsset(asset)
                    appState.prepareDraftForImportedVideo(asset, title: title, difficulty: difficulty, store: store)
                    openMediaEditor(for: asset.id)
                }
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

private struct VideoAttachmentDetailEditor: View {
    let asset: ImportedMediaAsset
    @Binding var edit: StepDraft.VideoEditing
    let maximumDuration: Double

    @State private var showAnnotationSheet = false
    @State private var selectedFreezeIndex: Int?
    @State private var freezeSnapshots: [UUID: UIImage] = [:]
    @State private var generatingSnapshotIDs: Set<UUID> = []

    private var safeDuration: Double { max(maximumDuration, 30) }

    var body: some View {
        Form {
            Section("Preview") {
                MediaPlaybackView(asset: asset, height: 200, editing: edit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(cropDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Crop") {
                Toggle("Enable crop", isOn: $edit.crop.isEnabled.animation())
                if edit.crop.isEnabled {
                    cropSliders
                }
            }

            Section("Freeze Frames") {
                if edit.freezeFrames.isEmpty {
                    Text("No freeze frames yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(edit.freezeFrames.enumerated()), id: \.element.id) { index, _ in
                    FreezeFrameRow(
                        freeze: $edit.freezeFrames[index],
                        maxDuration: safeDuration,
                        onAnnotate: {
                            selectFreeze(at: index)
                        },
                        onRemove: {
                            let removed = edit.freezeFrames.remove(at: index)
                            freezeSnapshots.removeValue(forKey: removed.id)
                            generatingSnapshotIDs.remove(removed.id)
                            if let current = selectedFreezeIndex {
                                if current == index {
                                    selectedFreezeIndex = nil
                                } else if current > index {
                                    selectedFreezeIndex = current - 1
                                }
                            }
                        }
                    )
                }

                Button {
                    var newFrame = StepDraft.VideoEditing.FreezeFrame(
                        time: min(2, safeDuration - 0.5),
                        duration: min(2, safeDuration)
                    )
                    newFrame.clamp(maxDuration: safeDuration)
                    edit.freezeFrames.append(newFrame)
                    edit.freezeFrames.sort(by: { $0.time < $1.time })
                    if let newIndex = edit.freezeFrames.firstIndex(where: { $0.id == newFrame.id }) {
                        selectFreeze(at: newIndex, autoPresent: false)
                    }
                } label: {
                    Label("Add Freeze Frame", systemImage: "snowflake")
                }
            }
        }
        .navigationTitle(asset.filename)
        .onAppear { edit.crop.clamp() }
        .sheet(isPresented: $showAnnotationSheet, onDismiss: { selectedFreezeIndex = nil }) {
            NavigationStack {
                if let annotationBinding = annotationBindingForSelected(),
                   let freeze = selectedFreezeIndex.flatMap({ edit.freezeFrames.indices.contains($0) ? edit.freezeFrames[$0] : nil }) {
                    AnnotationDrawingCanvas(
                        annotation: annotationBinding,
                        background: freezeSnapshots[freeze.id]
                    )
                        .navigationTitle("Annotate Frame")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showAnnotationSheet = false }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Clear") { annotationBinding.wrappedValue.strokes.removeAll() }
                            }
                        }
                } else {
                    Text("Select a freeze frame to annotate")
                        .padding()
                        .navigationTitle("Annotate Frame")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Close") { showAnnotationSheet = false }
                            }
                        }
                }
            }
        }
        .onChange(of: edit.crop) { _, _ in
            freezeSnapshots.removeAll()
            generatingSnapshotIDs.removeAll()
            if let index = selectedFreezeIndex,
               edit.freezeFrames.indices.contains(index) {
                let freeze = edit.freezeFrames[index]
                ensureSnapshot(for: freeze, force: true)
            }
        }
        .onChange(of: edit.freezeFrames) { _, newValue in
            let ids = Set(newValue.map(\.id))
            freezeSnapshots = freezeSnapshots.filter { ids.contains($0.key) }
            generatingSnapshotIDs = Set(generatingSnapshotIDs.filter { ids.contains($0) })
            if let index = selectedFreezeIndex, !newValue.indices.contains(index) {
                selectedFreezeIndex = nil
            }
        }
    }

    private var cropSliders: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text("Width: \(edit.crop.width, format: .percent.precision(.fractionLength(0)))")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { edit.crop.width },
                        set: { newValue in
                            edit.crop.width = newValue
                            edit.crop.clamp()
                        }
                    ),
                    in: 0.2...1
                )
            }

            VStack(alignment: .leading) {
                Text("Height: \(edit.crop.height, format: .percent.precision(.fractionLength(0)))")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { edit.crop.height },
                        set: { newValue in
                            edit.crop.height = newValue
                            edit.crop.clamp()
                        }
                    ),
                    in: 0.2...1
                )
            }

            VStack(alignment: .leading) {
                Text("Horizontal offset")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { edit.crop.originX },
                        set: { newValue in
                            edit.crop.originX = newValue
                            edit.crop.clamp()
                        }
                    ),
                    in: 0...(1 - edit.crop.width)
                )
            }

            VStack(alignment: .leading) {
                Text("Vertical offset")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { edit.crop.originY },
                        set: { newValue in
                            edit.crop.originY = newValue
                            edit.crop.clamp()
                        }
                    ),
                    in: 0...(1 - edit.crop.height)
                )
            }
        }
    }

    private var cropDescription: String {
        guard edit.crop.isEnabled else { return "Cropping disabled" }
        return "Crop area: x \(Int(edit.crop.originX * 100))%, y \(Int(edit.crop.originY * 100))%, width \(Int(edit.crop.width * 100))%, height \(Int(edit.crop.height * 100))%"
    }

    private func annotationBindingForSelected() -> Binding<StepDraft.VideoEditing.FrameAnnotation>? {
        guard let index = selectedFreezeIndex,
              edit.freezeFrames.indices.contains(index) else { return nil }
        return Binding(
            get: { edit.freezeFrames[index].annotation },
            set: { edit.freezeFrames[index].annotation = $0 }
        )
    }

    private func selectFreeze(at index: Int, autoPresent: Bool = true) {
        guard edit.freezeFrames.indices.contains(index) else { return }
        selectedFreezeIndex = index
        let freeze = edit.freezeFrames[index]
        ensureSnapshot(for: freeze, force: true)
        if autoPresent {
            showAnnotationSheet = true
        }
    }

    private func ensureSnapshot(for freeze: StepDraft.VideoEditing.FreezeFrame, force: Bool) {
        if !force, freezeSnapshots[freeze.id] != nil { return }
        if generatingSnapshotIDs.contains(freeze.id) { return }
        generatingSnapshotIDs.insert(freeze.id)
        let cropSetting = edit.crop.isEnabled ? edit.crop : nil
        let url = asset.url
        Task.detached(priority: .userInitiated) {
            let image = await captureFreezeFrameImage(url: url, time: freeze.time, crop: cropSetting)
            await MainActor.run {
                generatingSnapshotIDs.remove(freeze.id)
                if let image {
                    freezeSnapshots[freeze.id] = image
                } else {
                    freezeSnapshots.removeValue(forKey: freeze.id)
                }
            }
        }
    }
}

private struct FreezeFrameRow: View {
    @Binding var freeze: StepDraft.VideoEditing.FreezeFrame
    let maxDuration: Double
    let onAnnotate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Start: \(freeze.time, format: .number.precision(.fractionLength(1))) s")
                Spacer()
                Text("Duration: \(freeze.duration, format: .number.precision(.fractionLength(1))) s")
            }
            .font(.caption)

            Slider(
                value: Binding(
                    get: { freeze.time },
                    set: { newValue in
                        freeze.time = newValue
                        freeze.clamp(maxDuration: maxDuration)
                    }
                ),
                in: 0...maxDuration,
                step: 0.1
            )

            let durationUpperBound = max(0.1, maxDuration - freeze.time)
            Slider(
                value: Binding(
                    get: { freeze.duration },
                    set: { newValue in
                        freeze.duration = newValue
                        freeze.clamp(maxDuration: maxDuration)
                    }
                ),
                in: 0.1...durationUpperBound,
                step: 0.1
            )

            HStack {
                Button(action: onAnnotate) {
                    Label("Annotate", systemImage: "pencil.and.outline")
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

private struct CropOverlay: View {
    let crop: StepDraft.VideoEditing.Crop

    var body: some View {
        GeometryReader { proxy in
            if crop.isEnabled {
                let rect = CGRect(
                    x: crop.originX * proxy.size.width,
                    y: crop.originY * proxy.size.height,
                    width: crop.width * proxy.size.width,
                    height: crop.height * proxy.size.height
                )
                Path { path in
                    path.addRect(rect)
                }
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [6]))
            }
        }
    }
}

private struct AnnotationDrawingCanvas: View {
    @Binding var annotation: StepDraft.VideoEditing.FrameAnnotation
    let background: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var currentStroke: StepDraft.VideoEditing.AnnotationStroke?
    @State private var selectedColor: StepDraft.VideoEditing.AnnotationColor = .red
    @State private var lineWidth: Double = 4

    var body: some View {
        VStack(spacing: 16) {
            colorPalette
            Text("Drag to draw annotations on this freeze frame.")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                ZStack {
                    if let bg = background {
                        Image(uiImage: bg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        Color.black.opacity(0.85)
                    }
                    Canvas { context, size in
                        for stroke in annotation.strokes {
                            draw(stroke: stroke, in: &context, size: size)
                        }
                        if let stroke = currentStroke {
                            draw(stroke: stroke, in: &context, size: size)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let normalized = normalizedPoint(value.location, in: proxy.size)
                                if currentStroke == nil {
                                    var stroke = StepDraft.VideoEditing.AnnotationStroke()
                                    stroke.colorName = selectedColor
                                    stroke.lineWidth = lineWidth
                                    stroke.points = [normalized]
                                    currentStroke = stroke
                                } else {
                                    currentStroke?.points.append(normalized)
                                }
                            }
                            .onEnded { _ in
                                if var stroke = currentStroke, stroke.points.count > 1 {
                                    stroke.lineWidth = lineWidth
                                    annotation.strokes.append(stroke)
                                }
                                currentStroke = nil
                            }
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(height: 280)

            VStack(alignment: .leading) {
                Text("Line width: \(lineWidth, format: .number.precision(.fractionLength(0)))")
                    .font(.caption)
                Slider(value: $lineWidth, in: 2...20)
            }

            HStack {
                Button("Undo Stroke") {
                    _ = annotation.strokes.popLast()
                }
                .disabled(annotation.strokes.isEmpty)

                Button("Clear All", role: .destructive) {
                    annotation.strokes.removeAll()
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .font(.caption)
        }
        .padding()
    }

    private var colorPalette: some View {
        HStack {
            ForEach(StepDraft.VideoEditing.AnnotationColor.allCases) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 1)
                    )
                    .onTapGesture { selectedColor = color }
            }
        }
    }

    private func normalizedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        let x = max(0, min(1, point.x / size.width))
        let y = max(0, min(1, point.y / size.height))
        return CGPoint(x: x, y: y)
    }

    private func draw(stroke: StepDraft.VideoEditing.AnnotationStroke, in context: inout GraphicsContext, size: CGSize) {
        guard stroke.points.count > 1 else { return }
        var path = Path()
        let first = stroke.points[0]
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
        for point in stroke.points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
        }
        context.stroke(
            path,
            with: .color(stroke.colorName.color),
            lineWidth: stroke.lineWidth
        )
    }
}

private enum StoryboardTemplate: String, CaseIterable, Identifiable {
    case demo
    case blank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demo: return "Demo"
        case .blank: return "Blank"
        }
    }
}

private enum CasePreset: String, CaseIterable, Identifiable {
    case demoPulmonary
    case demoGastro
    case blank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demoPulmonary: return "Demo Pulmonary"
        case .demoGastro: return "Demo GI"
        case .blank: return "Blank"
        }
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
    var mediaAssetIDs: [ImportedMediaAsset.ID]
    var audioAssetIDs: [ImportedMediaAsset.ID]
    var prefersAutoTranscript: Bool
    var videoEdits: [ImportedMediaAsset.ID: VideoEditing] = [:]

    func duplicated(withOrder order: Int) -> StepDraft {
        StepDraft(
            order: order,
            title: title + " Copy",
            focus: focus,
            captureType: captureType,
            overlays: overlays,
            mediaAssetIDs: mediaAssetIDs,
            audioAssetIDs: audioAssetIDs,
            prefersAutoTranscript: prefersAutoTranscript,
            videoEdits: videoEdits
        )
    }

    static let sample: [StepDraft] = [
        StepDraft(order: 1, title: "Airway Inspection", focus: "Identify granulation tissue and stent margins.", captureType: .video, overlays: ["Arrow on obstruction", "Text: keep suction ready"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:]),
        StepDraft(order: 2, title: "Balloon Dilation", focus: "12mm balloon inflation with visual cues.", captureType: .video, overlays: ["Timer overlay", "Callout for pressure"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:]),
        StepDraft(order: 3, title: "Post-Procedure Review", focus: "Show restored lumen and mucosal perfusion.", captureType: .image, overlays: ["Before/after split"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:])
    ]

    static let demoGastro: [StepDraft] = [
        StepDraft(order: 1, title: "Lesion Inspection", focus: "Paris IIa+Is lesion with NICE type 2 pattern.", captureType: .video, overlays: ["NICE classification overlay", "Tattoo marker"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:]),
        StepDraft(order: 2, title: "Submucosal Lift", focus: "Orise gel injection elevated lesion without fibrosis.", captureType: .video, overlays: ["Injection plane arc", "Needle entry point"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:]),
        StepDraft(order: 3, title: "Cold Resection", focus: "Traction clip improved visualization; all pieces retrieved.", captureType: .video, overlays: ["Clip traction direction", "Specimen bucket"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:]),
        StepDraft(order: 4, title: "Defect Assessment", focus: "No bleeding; prophylactic clips placed.", captureType: .image, overlays: ["Closure pattern diagram"], mediaAssetIDs: [], audioAssetIDs: [], prefersAutoTranscript: false, videoEdits: [:])
    ]

    struct VideoEditing: Equatable {
        struct Crop: Equatable {
            var isEnabled: Bool = false
            var originX: Double = 0
            var originY: Double = 0
            var width: Double = 1
            var height: Double = 1

            mutating func clamp() {
                width = min(max(width, 0.1), 1)
                height = min(max(height, 0.1), 1)
                originX = min(max(originX, 0), 1 - width)
                originY = min(max(originY, 0), 1 - height)
            }
        }

        struct AnnotationStroke: Identifiable, Equatable {
            var id = UUID()
            var points: [CGPoint] = [] // normalized 0…1
            var colorName: AnnotationColor = .red
            var lineWidth: Double = 4
        }

        struct FrameAnnotation: Equatable {
            var strokes: [AnnotationStroke] = []
        }

        struct FreezeFrame: Identifiable, Equatable {
            var id = UUID()
            var time: Double
            var duration: Double
            var annotation: FrameAnnotation = FrameAnnotation()

            mutating func clamp(maxDuration: Double) {
                time = min(max(time, 0), maxDuration)
                duration = min(max(duration, 0.1), maxDuration - time)
            }
        }

        enum AnnotationColor: String, CaseIterable, Identifiable {
            case red
            case orange
            case yellow
            case green
            case cyan
            case blue
            case purple
            case white

            var id: String { rawValue }

            var color: Color {
                switch self {
                case .red: return .red
                case .orange: return .orange
                case .yellow: return .yellow
                case .green: return .green
                case .cyan: return .cyan
                case .blue: return .blue
                case .purple: return .purple
                case .white: return .white
                }
            }
        }

        var crop: Crop = Crop()
        var freezeFrames: [FreezeFrame] = []

        static func color(for name: AnnotationColor) -> Color { name.color }
    }
}

private struct TimelineStepCard: View {
    let step: StepDraft
    let isSelected: Bool
    let linkedAssets: [ImportedMediaAsset]
    let audioAssets: [ImportedMediaAsset]
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
            if let summary = videoEditSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let primaryAsset = linkedAssets.first {
                MediaAssetPreview(asset: primaryAsset, videoEdit: step.videoEdits[primaryAsset.id])
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

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let fraction = Int((time - floor(time)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, fraction)
    }

    private var videoEditSummary: String? {
        let edits = step.videoEdits.values
        guard !edits.isEmpty else { return nil }
        var parts: [String] = []
        if edits.contains(where: { $0.crop.isEnabled }) {
            parts.append("Crop enabled")
        }
        let freezeCount = edits.reduce(0) { $0 + $1.freezeFrames.count }
        if freezeCount > 0 {
            parts.append("\(freezeCount) freeze frame" + (freezeCount == 1 ? "" : "s"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private struct StepEditorSheet: View {
    @State private var workingStep: StepDraft
    @State private var newOverlayText: String = ""
    let availableAssets: [ImportedMediaAsset]
    let onSave: (StepDraft) -> Void
    let onCancel: () -> Void
    let openMediaEditor: (ImportedMediaAsset.ID) -> Void

    @Environment(\.dismiss) private var dismiss

    init(step: StepDraft,
         availableAssets: [ImportedMediaAsset],
         onSave: @escaping (StepDraft) -> Void,
         onCancel: @escaping () -> Void,
         openMediaEditor: @escaping (ImportedMediaAsset.ID) -> Void) {
        _workingStep = State(initialValue: step)
        self.availableAssets = availableAssets
        self.onSave = onSave
        self.onCancel = onCancel
        self.openMediaEditor = openMediaEditor
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

            if !videoAttachments.isEmpty {
                Section("Video Enhancements") {
                    ForEach(videoAttachments, id: \.id) { asset in
                        videoEnhancementRow(for: asset)
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

    private var visualAttachments: [ImportedMediaAsset] {
        workingStep.mediaAssetIDs.compactMap { id in
            availableAssets.first(where: { $0.id == id })
        }
    }

    private var audioAttachments: [ImportedMediaAsset] {
        workingStep.audioAssetIDs.compactMap { id in
            availableAssets.first(where: { $0.id == id })
        }
    }

    private var videoAttachments: [ImportedMediaAsset] {
        visualAttachments.filter { $0.kind == .video }
    }

    private func videoEditSummary(for edit: StepDraft.VideoEditing) -> String {
        var parts: [String] = []
        if edit.crop.isEnabled {
            parts.append("Crop enabled")
        }
        let freezeCount = edit.freezeFrames.count
        if freezeCount > 0 {
            parts.append("\(freezeCount) freeze frame" + (freezeCount == 1 ? "" : "s"))
        }
        return parts.isEmpty ? "No adjustments yet" : parts.joined(separator: " • ")
    }

    private func videoEnhancementRow(for asset: ImportedMediaAsset) -> some View {
        if workingStep.videoEdits[asset.id] == nil {
            workingStep.videoEdits[asset.id] = StepDraft.VideoEditing()
        }
        let binding = Binding(
            get: { workingStep.videoEdits[asset.id] ?? StepDraft.VideoEditing() },
            set: { workingStep.videoEdits[asset.id] = $0 }
        )
        let summary = videoEditSummary(for: binding.wrappedValue)

        return VStack(alignment: .leading, spacing: 8) {
            VideoAttachmentSummaryRow(asset: asset, summary: summary)
            Button {
                onSave(workingStep)
                openMediaEditor(asset.id)
                dismiss()
            } label: {
                Label("Open Media Editor", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    private struct AttachmentRow: View {
        let asset: ImportedMediaAsset
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

private struct VideoAttachmentSummaryRow: View {
    let asset: ImportedMediaAsset
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(asset.filename, systemImage: "slider.horizontal.3")
                .font(.subheadline)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AudioAttachmentSummary: View {
    let assets: [ImportedMediaAsset]
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
    let asset: ImportedMediaAsset
    var videoEdit: StepDraft.VideoEditing? = nil

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
                if let edit = videoEdit {
                    MediaPlaybackView(asset: asset, height: 160, editing: edit)
                } else if let proxy = asset.proxyURL {
                    VideoPlayer(player: AVPlayer(url: proxy))
                        .frame(height: 160)
                        .cornerRadius(12)
                } else if let preview = asset.thumbnail {
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
                AudioPreviewWaveform(duration: asset.duration.sanitizedNonNegative ?? 0)
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

            if asset.kind == .video, asset.thumbnailSpriteURL != nil {
                Label("Sprite ready", systemImage: "square.grid.2x2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

private struct ProcessingStatusRow: View {
    let title: String
    let isReady: Bool
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isReady ? .green : .secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: isReady ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(isReady ? .green : .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

private struct MediaAssetRow: View {
    let asset: ImportedMediaAsset
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
    let assets: [ImportedMediaAsset]

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

    private func assets(for step: StepDraft) -> [ImportedMediaAsset] {
        step.mediaAssetIDs.compactMap { id in
            assets.first { $0.id == id }
        }
    }

    private func audioAssets(for step: StepDraft) -> [ImportedMediaAsset] {
        step.audioAssetIDs.compactMap { id in
            assets.first { $0.id == id }
        }
    }
}

private struct PreviewStepCard: View {
    let step: StepDraft
    let assets: [ImportedMediaAsset]
    let audioAssets: [ImportedMediaAsset]

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
            MediaPlaybackView(asset: primary, height: 200, editing: step.videoEdits[primary.id])
        } else if assets.count >= 2 {
            PictureInPicturePreview(
                primary: assets[0],
                secondary: assets[1],
                primaryEdit: step.videoEdits[assets[0].id],
                secondaryEdit: step.videoEdits[assets[1].id]
            )
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
    let asset: ImportedMediaAsset
    var height: CGFloat
    var fillsHorizontally: Bool = true
    var editing: StepDraft.VideoEditing? = nil

    @StateObject private var playback = VideoPlaybackCoordinator()
    @State private var errorMessage: String?
    @State private var freezeOverlay: UIImage?
    @State private var activeFreezeID: UUID?
    @State private var completedFreezeIDs: Set<UUID> = []
    @State private var freezeSnapshots: [UUID: UIImage] = [:]
    @State private var freezeResumeWorkItem: DispatchWorkItem?
    @State private var timeObserver: Any?

    var body: some View {
        ZStack {
            if asset.kind == .video {
                videoBody
            } else if let image = asset.editedImage ?? asset.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        Image(systemName: asset.kind == .audio ? "waveform" : "photo")
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
        .onAppear { preparePlayback() }
        .onDisappear { teardown() }
        .onChange(of: asset.id) { _, _ in
            teardown()
            preparePlayback()
        }
        .onChange(of: editing?.crop) { _, _ in
            freezeSnapshots = [:]
        }
        .onChange(of: editing?.freezeFrames ?? []) { _, _ in
            resetFreezeState()
            preloadFreezeSnapshots()
        }
    }

    private var videoBody: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.85)
                switch playback.state {
                case .ready:
                    if let player = playback.player {
                        croppedPlayerView(player: player, size: proxy.size)
                            .transition(.opacity)
                    }
                case .failed(let message):
                    errorView(message: message)
                default:
                    ProgressView()
                        .tint(.white)
                }

                if let overlay = freezeOverlay {
                    Image(uiImage: overlay)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func croppedPlayerView(player: AVPlayer, size: CGSize) -> some View {
        if let crop = editing?.crop, crop.isEnabled {
            let safeWidth = max(crop.width, 0.001)
            let safeHeight = max(crop.height, 0.001)
            let scale = max(1 / safeWidth, 1 / safeHeight)
            let scaledWidth = size.width * scale
            let scaledHeight = size.height * scale
            let offsetX = -crop.originX * scaledWidth
            let offsetY = -crop.originY * scaledHeight

            ZStack(alignment: .topLeading) {
                VideoPlayer(player: player)
                    .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
                    .offset(x: offsetX, y: offsetY)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipped()
        } else {
            VideoPlayer(player: player)
                .frame(width: size.width, height: size.height)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.white)
            Text(errorMessage ?? message)
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding()
    }

    private func preparePlayback() {
        guard asset.kind == .video else { return }
        errorMessage = nil
        resetFreezeState()
        playback.prepare(url: asset.url, autoPlay: false, onReady: {
            playback.player?.pause()
            playback.player?.seek(to: .zero)
            setupTimeObserver()
            preloadFreezeSnapshots()
        }, onFailure: { error in
            errorMessage = error.localizedDescription
        })
    }

    private func preloadFreezeSnapshots() {
        guard let editing = editing else { return }
        for freeze in editing.freezeFrames {
            ensureFreezeSnapshot(for: freeze, force: false)
        }
    }

    private func ensureFreezeSnapshot(for freeze: StepDraft.VideoEditing.FreezeFrame, force: Bool) {
        if !force, freezeSnapshots[freeze.id] != nil { return }
        let url = asset.url
        let crop = editing?.crop
        Task.detached(priority: .userInitiated) {
            let image = await captureFreezeFrameImage(url: url,
                                                      time: freeze.time,
                                                      crop: crop?.isEnabled == true ? crop : nil)
            await MainActor.run {
                if let image {
                    freezeSnapshots[freeze.id] = image
                    if activeFreezeID == freeze.id {
                        freezeOverlay = image
                    }
                }
            }
        }
    }

    private func setupTimeObserver() {
        removeTimeObserver()
        guard let player = playback.player else { return }
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            handleFreezeFrames(at: time.seconds)
        }
    }

    private func handleFreezeFrames(at seconds: Double) {
        guard let editing = editing else { return }
        if let active = activeFreezeID,
           let freeze = editing.freezeFrames.first(where: { $0.id == active }) {
            if seconds >= freeze.time + freeze.duration {
                endFreeze()
            }
            return
        }

        guard freezeOverlay == nil else { return }

        for freeze in editing.freezeFrames.sorted(by: { $0.time < $1.time }) {
            if completedFreezeIDs.contains(freeze.id) { continue }
            if seconds >= freeze.time {
                beginFreeze(freeze)
                break
            }
        }
    }

    private func beginFreeze(_ freeze: StepDraft.VideoEditing.FreezeFrame) {
        guard let player = playback.player else { return }
        completedFreezeIDs.insert(freeze.id)
        activeFreezeID = freeze.id
        player.pause()
        freezeResumeWorkItem?.cancel()

        Task(priority: .userInitiated) {
            let currentImage: UIImage?
            if let cached = freezeSnapshots[freeze.id] {
                currentImage = cached
            } else {
                let cropSetting = (editing?.crop.isEnabled == true) ? editing?.crop : nil
                let captured = await captureFreezeFrameImage(url: asset.url,
                                                              time: freeze.time,
                                                              crop: cropSetting)
                await MainActor.run {
                    if let captured {
                        freezeSnapshots[freeze.id] = captured
                    }
                }
                currentImage = captured
            }

            await MainActor.run {
                freezeOverlay = currentImage
                let workItem = DispatchWorkItem {
                    endFreeze()
                    player.play()
                }
                freezeResumeWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + freeze.duration, execute: workItem)
            }
        }
    }

    private func endFreeze() {
        freezeResumeWorkItem?.cancel()
        freezeResumeWorkItem = nil
        freezeOverlay = nil
        activeFreezeID = nil
    }

    private func resetFreezeState() {
        freezeResumeWorkItem?.cancel()
        freezeResumeWorkItem = nil
        freezeOverlay = nil
        activeFreezeID = nil
        completedFreezeIDs.removeAll()
    }

    private func removeTimeObserver() {
        if let token = timeObserver, let player = playback.player {
            player.removeTimeObserver(token)
        }
        timeObserver = nil
    }

    private func teardown() {
        removeTimeObserver()
        resetFreezeState()
        playback.teardown()
    }
}

private struct PictureInPicturePreview: View {
    let primary: ImportedMediaAsset
    let secondary: ImportedMediaAsset
    var primaryEdit: StepDraft.VideoEditing? = nil
    var secondaryEdit: StepDraft.VideoEditing? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MediaPlaybackView(asset: primary, height: 200, editing: primaryEdit)
            MediaPlaybackView(asset: secondary, height: 100, fillsHorizontally: false, editing: secondaryEdit)
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
    .environmentObject(AppState())
}

private struct AssetIdentifier: Identifiable, Equatable {
    let id: ImportedMediaAsset.ID
}

private enum ScrollTarget {
    static let mediaEditor = "media-editor-section"
}

private extension CreatorView {
}

private nonisolated func captureFreezeFrameImage(url: URL, time: Double, crop: StepDraft.VideoEditing.Crop?) async -> UIImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1920, height: 1920)
    let targetTime = CMTime(seconds: time, preferredTimescale: 600)

    do {
        let cgImage: CGImage = try await withCheckedThrowingContinuation { continuation in
            let values = [NSValue(time: targetTime)]
            generator.generateCGImagesAsynchronously(forTimes: values) { _, image, _, result, error in
                if result == .succeeded, let image {
                    continuation.resume(returning: image)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NSError(domain: "FreezeFrame", code: -1, userInfo: nil))
                }
            }
        }

        var uiImage = UIImage(cgImage: cgImage)
        if let crop, crop.isEnabled, let cropped = cropImage(uiImage, crop: crop) {
            uiImage = cropped
        }
        return uiImage
    } catch {
        return nil
    }
}

private nonisolated func cropImage(_ image: UIImage, crop: StepDraft.VideoEditing.Crop) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let rect = CGRect(x: CGFloat(crop.originX) * width,
                      y: CGFloat(crop.originY) * height,
                      width: CGFloat(crop.width) * width,
                      height: CGFloat(crop.height) * height)
    guard let cropped = cgImage.cropping(to: rect) else { return nil }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
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
