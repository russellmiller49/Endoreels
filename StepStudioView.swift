import SwiftUI
import AVFoundation
import AVFAudio

struct StepStudioView: View {
    enum Tool: Hashable {
        case trim
        case crop
        case annotate
        case voiceover
        case blur
    }

    @Binding var step: StepDraft

    @FocusState private var focusedField: FocusedField?
    @State private var activeTool: Tool?
    @State private var selectedAnnotationType: AnnotationType = .arrow
    @State private var selectedAnnotationColor: AnnotationColor = .red
    @State private var selectedAnnotationID: UUID?

    @State private var player: AVPlayer?
    @State private var playerSourceURL: URL?
    @State private var isPlaying = false
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0

    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?

    @State private var blurDragStart: [UUID: NormalizedRect] = [:]
    @State private var blurResizeStart: [UUID: NormalizedRect] = [:]
    @State private var selectedBlurID: UUID?
    @State private var cropGestureStartScale: Double?
    @State private var cropGestureStartOffset: (x: Double, y: Double)?
    @State private var didRecordCropUndo = false
    @State private var didRecordTrimUndo = false
    @State private var editingTextAnnotationID: UUID?
    @State private var draftAnnotationText: String = ""
    @State private var undoStack: [StepEditState] = []
    @State private var redoStack: [StepEditState] = []

    private var resolvedVideoURL: URL { step.media.proxyURL ?? step.media.url }

    private var duration: Double {
        let duration = step.media.duration ?? 0
        return duration.isFinite ? max(duration, 0) : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                preview
                    .padding(.top, 12)

                toolBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                if activeTool == .trim {
                    trimControls
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                if activeTool == .crop {
                    cropHelp
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                if activeTool == .annotate {
                    annotationControls
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                if activeTool == .voiceover {
                    voiceoverControls
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                if activeTool == .blur {
                    blurHelp
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Step Title", text: $step.stepTitle)
                        .focused($focusedField, equals: .stepTitle)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .textFieldStyle(.roundedBorder)

                    TextField("Key Learning Point", text: $step.keyLearningPoint, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .focused($focusedField, equals: .keyLearningPoint)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            configurePlayerIfNeeded()
            syncTrimStateFromDraft()
        }
        .onChange(of: step.media.url) { _, _ in
            configurePlayerIfNeeded()
            syncTrimStateFromDraft()
        }
        .onChange(of: step.id) { _, _ in
            focusedField = nil
            selectedAnnotationID = nil
            editingTextAnnotationID = nil
            selectedBlurID = nil
            undoStack.removeAll()
            redoStack.removeAll()
            blurDragStart.removeAll()
            blurResizeStart.removeAll()
            cropGestureStartScale = nil
            cropGestureStartOffset = nil
            didRecordCropUndo = false
            didRecordTrimUndo = false
            configurePlayerIfNeeded()
            syncTrimStateFromDraft()
        }
        .onChange(of: step.media.proxyURL) { _, _ in
            configurePlayerIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { editingTextAnnotationID != nil },
            set: { if !$0 { focusedField = nil; editingTextAnnotationID = nil } }
        )) {
            if let annotationID = editingTextAnnotationID {
                NavigationStack {
                    Form {
                        Section("Text") {
                            TextField("Annotation text", text: $draftAnnotationText, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .focused($focusedField, equals: .annotationText)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                        }
                        Section {
                            Button(role: .destructive) {
                                deleteAnnotation(annotationID)
                                focusedField = nil
                                editingTextAnnotationID = nil
                            } label: {
                                Label("Delete Annotation", systemImage: "trash")
                            }
                        }
                    }
                    .navigationTitle("Edit Annotation")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                focusedField = nil
                                editingTextAnnotationID = nil
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("Save") {
                                updateAnnotationText(annotationID, text: draftAnnotationText)
                                focusedField = nil
                                editingTextAnnotationID = nil
                            }
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focusedField = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            } else {
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onDisappear {
            stopRecordingIfNeeded()
            player?.pause()
            isPlaying = false
        }
    }

    // MARK: - Preview

    private var preview: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                mediaCanvas(in: size)
                    .scaleEffect(step.cropScale)
                    .offset(
                        x: step.cropOffsetX * size.width,
                        y: step.cropOffsetY * size.height
                    )
                    .frame(width: size.width, height: size.height)
                    .clipped()

                if activeTool == .annotate || activeTool == .blur {
                    overlayTapLayer(in: size)
                }

                overlayCanvas(in: size)
                    .scaleEffect(step.cropScale)
                    .offset(
                        x: step.cropOffsetX * size.width,
                        y: step.cropOffsetY * size.height
                    )
                    .allowsHitTesting(activeTool != .crop)
                    .frame(width: size.width, height: size.height)
                    .clipped()

                if activeTool == .crop {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(cropGesture(in: size))
                }

                if focusedField != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { focusedField = nil }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if step.media.kind == .video, player != nil {
                    playbackButton
                        .padding(12)
                }
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var playbackButton: some View {
        Button {
            togglePlayback()
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 8)
        }
        .buttonStyle(.plain)
    }

    private func canvas(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            mediaCanvas(in: size)
            blurOverlays(in: size)
            annotationOverlays(in: size)
        }
    }

    @ViewBuilder
    private func mediaCanvas(in size: CGSize) -> some View {
        switch step.media.kind {
        case .video:
            if let player {
                AspectFillPlayerView(player: player)
                    .frame(width: size.width, height: size.height)
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay { ProgressView() }
            }

        case .image:
            if let image = step.media.editedImage ?? step.media.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                    }
            }

        case .audio:
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Audio-only step")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    private func overlayCanvas(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            blurOverlays(in: size)
            annotationOverlays(in: size)
        }
    }

    @ViewBuilder
    private func overlayTapLayer(in size: CGSize) -> some View {
        let hitSide: CGFloat = 96
        let excludesPlaybackButton = step.media.kind == .video && player != nil

        if excludesPlaybackButton {
            let topHeight = max(0, size.height - hitSide)
            let leftWidth = max(0, size.width - hitSide)
            let bottomOriginY = topHeight

            VStack(spacing: 0) {
                overlayTapRegion(origin: .zero, regionSize: CGSize(width: size.width, height: topHeight), fullSize: size)

                HStack(spacing: 0) {
                    overlayTapRegion(
                        origin: CGPoint(x: 0, y: bottomOriginY),
                        regionSize: CGSize(width: leftWidth, height: hitSide),
                        fullSize: size
                    )

                    Color.clear
                        .frame(width: hitSide, height: hitSide)
                }
                .frame(height: hitSide)
            }
            .frame(width: size.width, height: size.height)
        } else {
            overlayTapRegion(origin: .zero, regionSize: size, fullSize: size)
        }
    }

    @ViewBuilder
    private func overlayTapRegion(origin: CGPoint, regionSize: CGSize, fullSize: CGSize) -> some View {
        if #available(iOS 16.0, *) {
            Color.clear
                .frame(width: regionSize.width, height: regionSize.height)
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let location = CGPoint(x: value.location.x + origin.x, y: value.location.y + origin.y)
                            handleOverlayTap(at: location, in: fullSize)
                        }
                )
        } else {
            Color.clear
                .frame(width: regionSize.width, height: regionSize.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let location = CGPoint(x: value.location.x + origin.x, y: value.location.y + origin.y)
                            handleOverlayTap(at: location, in: fullSize)
                        }
                )
        }
    }

    private func handleOverlayTap(at location: CGPoint, in size: CGSize) {
        if focusedField != nil {
            focusedField = nil
            return
        }

        if step.media.kind == .video, player != nil, isInPlaybackButtonHitArea(location, in: size) {
            return
        }

        let contentPoint = contentPoint(location, in: size)
        switch activeTool {
        case .annotate:
            addAnnotation(at: contentPoint)
        case .blur:
            addBlurMask(center: contentPoint)
        case .trim, .crop, .voiceover, .none:
            break
        }
    }

    private func isInPlaybackButtonHitArea(_ location: CGPoint, in size: CGSize) -> Bool {
        let hitSide: CGFloat = 96
        let rect = CGRect(
            x: max(0, size.width - hitSide),
            y: max(0, size.height - hitSide),
            width: hitSide,
            height: hitSide
        )
        return rect.contains(location)
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: 14) {
            ToolButton(systemImage: "scissors", isActive: activeTool == .trim) {
                toggle(.trim)
            }
            ToolButton(systemImage: "crop", isActive: activeTool == .crop) {
                toggle(.crop)
            }
            ToolButton(systemImage: "pencil.tip", isActive: activeTool == .annotate) {
                toggle(.annotate)
            }
            ToolButton(systemImage: "mic", isActive: activeTool == .voiceover) {
                toggle(.voiceover)
            }
            ToolButton(systemImage: "drop.fill", isActive: activeTool == .blur) {
                toggle(.blur)
            }

            Spacer()

            if activeTool == .annotate {
                Menu {
                    ForEach(AnnotationColor.allCases, id: \.self) { color in
                        Button {
                            selectedAnnotationColor = color
                        } label: {
                            Label(color.displayName, systemImage: "circle.fill")
                        }
                    }
                } label: {
                    Label("Color", systemImage: "paintpalette")
                        .font(.caption)
                }
            }

            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .disabled(undoStack.isEmpty)

            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.headline)
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .disabled(redoStack.isEmpty)
        }
    }

    private func toggle(_ tool: Tool) {
        focusedField = nil
        if activeTool == tool {
            activeTool = nil
        } else {
            activeTool = tool
        }
    }

    // MARK: - Trim

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trim")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    recordUndoPoint()
                    trimStart = 0
                    trimEnd = duration
                    step.trimRange = duration > 0 ? (trimStart...trimEnd) : nil
                }
                .font(.caption)
                .disabled(duration <= 0)
            }

            if step.media.kind != .video {
                Text("Trimming is only available for video steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if duration <= 0 {
                Text("Video duration unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Start: \(trimStart, specifier: "%.1f")s")
                    Spacer()
                    Text("End: \(trimEnd, specifier: "%.1f")s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { trimStart },
                        set: { newValue in
                            trimStart = min(newValue, trimEnd - 0.5)
                            persistTrimRange()
                            seek(to: trimStart)
                        }
                    ),
                    in: 0...max(trimEnd - 0.5, 0),
                    onEditingChanged: { isEditing in
                        if isEditing, !didRecordTrimUndo {
                            didRecordTrimUndo = true
                            recordUndoPoint()
                        }
                        if !isEditing {
                            didRecordTrimUndo = false
                        }
                    }
                )

                Slider(
                    value: Binding(
                        get: { trimEnd },
                        set: { newValue in
                            trimEnd = max(newValue, trimStart + 0.5)
                            persistTrimRange()
                        }
                    ),
                    in: (trimStart + 0.5)...duration,
                    onEditingChanged: { isEditing in
                        if isEditing, !didRecordTrimUndo {
                            didRecordTrimUndo = true
                            recordUndoPoint()
                        }
                        if !isEditing {
                            didRecordTrimUndo = false
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func persistTrimRange() {
        guard duration > 0 else { return }
        step.trimRange = trimStart...trimEnd
    }

    private func syncTrimStateFromDraft() {
        guard duration > 0 else {
            trimStart = 0
            trimEnd = 0
            return
        }
        if let range = step.trimRange {
            trimStart = min(max(range.lowerBound, 0), duration)
            trimEnd = min(max(range.upperBound, trimStart), duration)
        } else {
            trimStart = 0
            trimEnd = duration
        }
        if trimEnd <= trimStart {
            trimEnd = duration
        }
    }

    private func seek(to seconds: Double) {
        guard let player else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    // MARK: - Crop / Zoom

    private var cropHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Crop / Zoom")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    recordUndoPoint()
                    step.cropScale = 1
                    step.cropOffsetX = 0
                    step.cropOffsetY = 0
                }
                .font(.caption)
            }
            Text("Pinch to zoom. Drag to reposition.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func cropGesture(in size: CGSize) -> some Gesture {
        let magnification = MagnificationGesture()
            .onChanged { value in
                if !didRecordCropUndo {
                    didRecordCropUndo = true
                    recordUndoPoint()
                }
                if cropGestureStartScale == nil { cropGestureStartScale = step.cropScale }
                let startScale = cropGestureStartScale ?? step.cropScale
                let proposedScale = startScale * Double(value)
                applyCrop(scale: proposedScale, offsetX: step.cropOffsetX, offsetY: step.cropOffsetY)
            }
            .onEnded { _ in
                cropGestureStartScale = nil
                didRecordCropUndo = false
                applyCrop(scale: step.cropScale, offsetX: step.cropOffsetX, offsetY: step.cropOffsetY)
            }

        let drag = DragGesture()
            .onChanged { value in
                if !didRecordCropUndo {
                    didRecordCropUndo = true
                    recordUndoPoint()
                }
                if cropGestureStartOffset == nil { cropGestureStartOffset = (step.cropOffsetX, step.cropOffsetY) }
                let start = cropGestureStartOffset ?? (step.cropOffsetX, step.cropOffsetY)
                let dx = Double(value.translation.width / size.width)
                let dy = Double(value.translation.height / size.height)
                applyCrop(scale: step.cropScale, offsetX: start.x + dx, offsetY: start.y + dy)
            }
            .onEnded { _ in
                cropGestureStartOffset = nil
                didRecordCropUndo = false
                applyCrop(scale: step.cropScale, offsetX: step.cropOffsetX, offsetY: step.cropOffsetY)
            }

        return SimultaneousGesture(magnification, drag)
    }

    private func applyCrop(scale: Double, offsetX: Double, offsetY: Double) {
        let clampedScale = min(max(scale.isFinite ? scale : 1, 1), 6)
        let maxOffset = (clampedScale - 1) / 2
        step.cropScale = clampedScale
        step.cropOffsetX = min(max(offsetX.isFinite ? offsetX : 0, -maxOffset), maxOffset)
        step.cropOffsetY = min(max(offsetY.isFinite ? offsetY : 0, -maxOffset), maxOffset)
    }

    // MARK: - Annotations

    private var annotationControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Annotations")
                    .font(.headline)
                Spacer()
                Text("Tap on video to add")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                AnnotationTypeButton(type: .arrow, selectedType: $selectedAnnotationType)
                AnnotationTypeButton(type: .circle, selectedType: $selectedAnnotationType)
                AnnotationTypeButton(type: .text, selectedType: $selectedAnnotationType)
                Spacer()
                if let selectedAnnotationID {
                    Button(role: .destructive) {
                        deleteAnnotation(selectedAnnotationID)
                        self.selectedAnnotationID = nil
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func addAnnotation(at position: CGPoint) {
        recordUndoPoint()
        let endTime = max(duration, 1)
        var annotation = TimedAnnotation(
            type: selectedAnnotationType,
            startTime: 0,
            endTime: endTime,
            position: position,
            text: selectedAnnotationType == .text ? "Tap to edit" : "",
            color: selectedAnnotationColor,
            scale: 1.0,
            rotation: 0,
            opacity: 1.0,
            preset: nil
        )
        annotation.position = CGPoint(x: max(0, min(1, position.x)), y: max(0, min(1, position.y)))
        step.annotations.append(annotation)
        selectedAnnotationID = annotation.id
        if selectedAnnotationType == .text {
            beginEditingText(for: annotation.id)
        }
    }

    private func annotationOverlays(in size: CGSize) -> some View {
        ForEach(step.annotations) { annotation in
            let position = CGPoint(x: annotation.position.x * size.width, y: annotation.position.y * size.height)
            StudioAnnotationView(annotation: annotation, isSelected: selectedAnnotationID == annotation.id)
                .position(position)
                .allowsHitTesting(activeTool == .annotate)
                .onTapGesture {
                    selectedAnnotationID = annotation.id
                    if annotation.type == .text {
                        beginEditingText(for: annotation.id)
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteAnnotation(annotation.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    private func deleteAnnotation(_ id: UUID) {
        recordUndoPoint()
        step.annotations.removeAll { $0.id == id }
    }

    private func beginEditingText(for id: UUID) {
        editingTextAnnotationID = id
        draftAnnotationText = step.annotations.first(where: { $0.id == id })?.text ?? ""
    }

    private func updateAnnotationText(_ id: UUID, text: String) {
        recordUndoPoint()
        guard let index = step.annotations.firstIndex(where: { $0.id == id }) else { return }
        step.annotations[index].text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Voiceover

    private var voiceoverControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Voiceover")
                    .font(.headline)
                Spacer()
                if isRecording {
                    Text("Recording…")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let narrationPath = step.narrationPath {
                Text("Attached: \(URL(fileURLWithPath: narrationPath).lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No narration recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        requestMicrophonePermissionIfNeeded()
                        startRecording()
                    }
                } label: {
                    Label(isRecording ? "Stop" : "Record", systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .blue)

                if step.narrationPath != nil {
                    Button(role: .destructive) {
                        deleteVoiceover()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func requestMicrophonePermissionIfNeeded() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }

    private func startRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EndoReelsNarration", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = url

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            isRecording = false
            audioRecorder = nil
        }
    }

    private func stopRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
        isRecording = false
        audioRecorder = nil

        if let url = recordingURL {
            step.narrationPath = url.path
        }
    }

    private func stopRecordingIfNeeded() {
        if isRecording { stopRecording() }
    }

    private func deleteVoiceover() {
        if let narrationPath = step.narrationPath {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: narrationPath))
        }
        step.narrationPath = nil
    }

    // MARK: - Blur

    private var blurHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Blur")
                .font(.headline)
            Text("Tap to add a blur mask. Drag to reposition or resize.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func addBlurMask(center: CGPoint) {
        recordUndoPoint()
        let width = 0.25
        let height = 0.14
        let rect = NormalizedRect(
            x: Double(center.x) - width / 2,
            y: Double(center.y) - height / 2,
            width: width,
            height: height
        ).clamped()
        step.manualBlurRects.append(rect)
    }

    private func blurOverlays(in size: CGSize) -> some View {
        ForEach($step.manualBlurRects) { $rect in
            let frame = CGRect(
                x: rect.x * size.width,
                y: rect.y * size.height,
                width: rect.width * size.width,
                height: rect.height * size.height
            )
            let isSelected = activeTool == .blur && selectedBlurID == rect.id
            let maskWidth = max(frame.width, 20)
            let maskHeight = max(frame.height, 20)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue.opacity(0.9) : Color.white.opacity(0.7), lineWidth: isSelected ? 2 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture {
                        selectedBlurID = rect.id
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                selectedBlurID = rect.id
                                let start = blurDragStart[rect.id] ?? rect
                                if blurDragStart[rect.id] == nil {
                                    recordUndoPoint()
                                    blurDragStart[rect.id] = start
                                }
                                let scale = max(step.cropScale, 1)
                                let dx = Double(value.translation.width / (size.width * scale))
                                let dy = Double(value.translation.height / (size.height * scale))
                                rect.x = start.x + dx
                                rect.y = start.y + dy
                                rect = rect.clamped()
                            }
                            .onEnded { _ in
                                blurDragStart.removeValue(forKey: rect.id)
                            }
                    )

                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "arrow.up.left.and.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.6))
                        )
                        .padding(6)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    selectedBlurID = rect.id
                                    let start = blurResizeStart[rect.id] ?? rect
                                    if blurResizeStart[rect.id] == nil {
                                        recordUndoPoint()
                                        blurResizeStart[rect.id] = start
                                    }
                                    let scale = max(step.cropScale, 1)
                                    let dx = Double(value.translation.width / (size.width * scale))
                                    let dy = Double(value.translation.height / (size.height * scale))
                                    rect.width = start.width + dx
                                    rect.height = start.height + dy
                                    rect = rect.clamped()
                                }
                                .onEnded { _ in
                                    blurResizeStart.removeValue(forKey: rect.id)
                                }
                        )
                }
            }
            .frame(width: maskWidth, height: maskHeight)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(activeTool == .blur)
                .contextMenu {
                    Button(role: .destructive) {
                        recordUndoPoint()
                        step.manualBlurRects.removeAll { $0.id == rect.id }
                        if selectedBlurID == rect.id {
                            selectedBlurID = nil
                        }
                    } label: {
                        Label("Delete Blur Mask", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: - Helpers

    private func contentPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = CGFloat(max(step.cropScale, 1))
        let offsetX = CGFloat(step.cropOffsetX) * size.width
        let offsetY = CGFloat(step.cropOffsetY) * size.height

        let normalizedX = (((point.x - size.width / 2) - offsetX) / (scale * size.width)) + 0.5
        let normalizedY = (((point.y - size.height / 2) - offsetY) / (scale * size.height)) + 0.5

        return CGPoint(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY))
        )
    }

    private func configurePlayerIfNeeded() {
        guard step.media.kind == .video else {
            player = nil
            playerSourceURL = nil
            isPlaying = false
            return
        }
        let url = resolvedVideoURL
        if playerSourceURL != url || player == nil {
            player = AVPlayer(url: url)
            player?.pause()
            playerSourceURL = url
            isPlaying = false
        }
    }

    private func togglePlayback() {
        focusedField = nil
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if let range = step.trimRange {
                let start = CMTime(seconds: range.lowerBound, preferredTimescale: 600)
                player.seek(to: start)
            }
            player.play()
            isPlaying = true
        }
    }

    // MARK: - Undo / Redo

    private enum FocusedField: Hashable {
        case stepTitle
        case keyLearningPoint
        case annotationText
    }

    private struct StepEditState {
        var trimRange: ClosedRange<Double>?
        var cropScale: Double
        var cropOffsetX: Double
        var cropOffsetY: Double
        var annotations: [TimedAnnotation]
        var manualBlurRects: [NormalizedRect]
        var narrationPath: String?
    }

    private func currentEditState() -> StepEditState {
        StepEditState(
            trimRange: step.trimRange,
            cropScale: step.cropScale,
            cropOffsetX: step.cropOffsetX,
            cropOffsetY: step.cropOffsetY,
            annotations: step.annotations,
            manualBlurRects: step.manualBlurRects,
            narrationPath: step.narrationPath
        )
    }

    private func applyEditState(_ state: StepEditState) {
        step.trimRange = state.trimRange
        step.cropScale = state.cropScale
        step.cropOffsetX = state.cropOffsetX
        step.cropOffsetY = state.cropOffsetY
        step.annotations = state.annotations
        step.manualBlurRects = state.manualBlurRects
        step.narrationPath = state.narrationPath

        selectedAnnotationID = nil
        editingTextAnnotationID = nil
    }

    private func recordUndoPoint() {
        let snapshot = currentEditState()
        undoStack.append(snapshot)
        if undoStack.count > 50 {
            undoStack.removeFirst(undoStack.count - 50)
        }
        redoStack.removeAll()
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentEditState())
        applyEditState(previous)
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentEditState())
        applyEditState(next)
    }
}

private struct ToolButton: View {
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 40, height: 34)
                .background(isActive ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct AnnotationTypeButton: View {
    let type: AnnotationType
    @Binding var selectedType: AnnotationType

    var body: some View {
        Button {
            selectedType = type
        } label: {
            Image(systemName: type.systemImage)
                .font(.headline)
                .frame(width: 40, height: 34)
                .background(selectedType == type ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(selectedType == type ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct StudioAnnotationView: View {
    let annotation: TimedAnnotation
    let isSelected: Bool

    var body: some View {
        Group {
            switch annotation.type {
            case .arrow:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 28))
                    .foregroundStyle(annotation.color.swiftUIColor)
                    .shadow(radius: 1)

            case .circle:
                Circle()
                    .stroke(annotation.color.swiftUIColor, lineWidth: 4)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 1)

            case .text:
                Text(annotation.text.isEmpty ? "Text" : annotation.text)
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(annotation.color.swiftUIColor.opacity(0.8), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)

            default:
                Image(systemName: annotation.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(annotation.color.swiftUIColor)
            }
        }
        .scaleEffect(annotation.scale)
        .rotationEffect(.degrees(annotation.rotation))
        .opacity(annotation.opacity)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
