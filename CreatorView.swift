import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct CreatorView: View {
    enum CreatorStage {
        case mediaSelection
        case timelineEditor
        case publishing
    }

    @EnvironmentObject private var store: DemoDataStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let onClose: (() -> Void)?

    @State private var stage: CreatorStage = .mediaSelection
    @State private var photoSelections: [PhotosPickerItem] = []
    @State private var isProcessingImport = false
    @State private var importError: String?
    @State private var showPreview = false

    @State private var stepDrafts: [StepDraft] = []
    @State private var selectedStepID: StepDraft.ID?

    @State private var publishTitle: String = ""
    @State private var publishProcedure: String = ""
    @State private var publishAnatomy: String = ""
    @State private var publishTags: String = ""

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .mediaSelection:
                    mediaSelectionStage
                case .timelineEditor:
                    timelineEditorStage
                case .publishing:
                    publishingStage
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { creatorToolbar }
            .onChange(of: photoSelections) { _, newValue in
                Task { await handlePhotoSelections(newValue) }
            }
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .onAppear {
                if publishTitle.isEmpty {
                    publishTitle = "Untitled Reel"
                }
            }
        }
    }

    private var navigationTitle: String {
        switch stage {
        case .mediaSelection:
            return "Select Media"
        case .timelineEditor:
            return "Studio"
        case .publishing:
            return "Publish"
        }
    }

    @ToolbarContentBuilder
    private var creatorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { close() }
        }

        if stage == .timelineEditor {
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    stage = .publishing
                }
                .disabled(stepDrafts.isEmpty)
            }
        }

        if stage == .publishing {
            ToolbarItem(placement: .primaryAction) {
                Button("Back") {
                    stage = .timelineEditor
                }
            }
        }
    }

    private var mediaSelectionStage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Select Case Media")
                    .font(.title2.bold())
                Text("Pick videos or images. Each selection becomes a step you can trim, annotate, voiceover, and redact.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            PhotosPicker(selection: $photoSelections, maxSelectionCount: 25, matching: .any(of: [.images, .videos])) {
                Label("Select Case Media", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal)

            if isProcessingImport {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Importing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !stepDrafts.isEmpty {
                Button {
                    stage = .timelineEditor
                } label: {
                    Text("Continue Editing (\(stepDrafts.count) steps)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var timelineEditorStage: some View {
        VStack(spacing: 0) {
            if let selectedBinding = bindingForSelectedStep() {
                StepStudioView(step: selectedBinding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No steps yet", systemImage: "film", description: Text("Import media to start building your reel."))
            }

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stepDrafts) { step in
                        StepThumbnail(
                            step: step,
                            isSelected: step.id == selectedStepID
                        )
                        .onTapGesture {
                            selectedStepID = step.id
                        }
                    }

                    PhotosPicker(selection: $photoSelections, maxSelectionCount: 25, matching: .any(of: [.images, .videos])) {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                Image(systemName: "plus")
                                    .font(.title3.bold())
                                    .foregroundStyle(.blue)
                            }
                            .frame(width: 88, height: 64)

                            Text("Add")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 92)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color(.secondarySystemBackground))
        }
    }

    private var publishingStage: some View {
        PublishAttestationView(
            title: $publishTitle,
            procedure: $publishProcedure,
            anatomy: $publishAnatomy,
            tags: $publishTags,
            onPreview: { showPreview = true },
            onPublish: publishReel
        )
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                ReelDetailView(reel: buildReel(status: .draft))
                    .environmentObject(store)
            }
        }
    }

    private func bindingForSelectedStep() -> Binding<StepDraft>? {
        guard !stepDrafts.isEmpty else { return nil }
        let targetID = selectedStepID ?? stepDrafts.first?.id
        guard let targetID,
              let index = stepDrafts.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }
        if selectedStepID == nil { selectedStepID = targetID }
        return $stepDrafts[index]
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Import

    private func handlePhotoSelections(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isProcessingImport = true }
        defer {
            Task { @MainActor in
                isProcessingImport = false
                photoSelections = []
            }
        }

        var importedSteps: [StepDraft] = []

        for item in items {
            do {
                guard let asset = try await importPhotoItem(item) else { continue }
                let order = (stepDrafts.count + importedSteps.count) + 1
                importedSteps.append(StepDraft(order: order, media: asset))
            } catch {
                await MainActor.run { importError = error.localizedDescription }
            }
        }

        guard !importedSteps.isEmpty else { return }

        await MainActor.run {
            stepDrafts.append(contentsOf: importedSteps)
            if selectedStepID == nil {
                selectedStepID = stepDrafts.first?.id
            }
            stage = .timelineEditor
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

    private func tempURL(for filename: String) -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("EndoReelsMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(filename)
    }

    // MARK: - Publish

    private func publishReel() {
        let reel = buildReel(status: .review)
        store.reels.insert(reel, at: 0)
        close()
    }

    private func buildReel(status: ReelStatus) -> Reel {
        let tags = publishTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let serviceLine = appState.currentUser.role ?? .pulmonary
        let author = UserProfile(
            name: appState.currentUser.name,
            role: serviceLine.displayName,
            institution: "Independent",
            specialties: [serviceLine.displayName],
            verification: VerificationBadge(tier: .unverified, issuedAt: .now, notes: "Attested"),
            bio: "Created with EndoReels Studio."
        )

        let steps: [ReelStep] = stepDrafts.sorted(by: { $0.order < $1.order }).map { draft in
            let kind = draft.media.kind
            let mediaType: MediaType = (kind == .video) ? .video : .image
            let durationSeconds = Int((draft.media.duration ?? 0).rounded())
            let annotationStrings = draft.annotations.map { annotation in
                annotation.text.isEmpty ? annotation.type.displayName : annotation.text
            }
            let stepTitle = sanitizedStepTitle(draft.stepTitle, order: draft.order)
            return ReelStep(
                orderIndex: draft.order,
                title: stepTitle,
                keyPoint: draft.keyLearningPoint,
                mediaType: mediaType,
                durationSeconds: max(durationSeconds, 0),
                annotations: annotationStrings,
                mediaURL: draft.media.url,
                trimRange: draft.trimRange,
                cropScale: draft.cropScale,
                cropOffsetX: draft.cropOffsetX,
                cropOffsetY: draft.cropOffsetY,
                manualBlurRects: draft.manualBlurRects,
                timedAnnotations: draft.annotations
            )
        }

        return Reel(
            title: publishTitle.isEmpty ? "Untitled Reel" : publishTitle,
            abstract: "Created with EndoReels Studio.",
            serviceLine: serviceLine,
            procedure: publishProcedure,
            anatomy: publishAnatomy,
            pathology: "",
            device: "",
            difficulty: "Standard",
            createdAt: .now,
            status: status,
            author: author,
            steps: steps,
            tags: tags,
            cmeTrack: nil,
            engagement: EngagementSignals(views: 0, saves: 0, completionRate: 0, endorsements: 0, reactions: [:]),
            knowledgeHighlights: [],
            comments: []
        )
    }

    private func sanitizedStepTitle(_ title: String, order: Int) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Step \(order)" }
        if UUID(uuidString: trimmed) != nil { return "Step \(order)" }
        return trimmed
    }
}

private struct StepThumbnail: View {
    let step: StepDraft
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )

                if let image = step.media.editedImage ?? step.media.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: step.media.kind == .video ? "play.rectangle" : "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 64)

            Text(step.stepTitle.isEmpty ? "Step \(step.order)" : step.stepTitle)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: 92)
        }
    }
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

#Preview {
    CreatorView(onClose: {})
        .environmentObject(DemoDataStore())
        .environmentObject(AppState())
}
