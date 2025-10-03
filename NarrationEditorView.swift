import SwiftUI
import AVFoundation
import AVFAudio
import Speech

// MARK: - Narration Models

struct NarrationSegment: Identifiable, Codable {
    let id: UUID
    var startTime: Double
    var endTime: Double
    var audioURL: URL?
    var transcript: String
    var isProcessed: Bool
    var phiDetected: Bool
    var phiTerms: [String]

    init(id: UUID = UUID(), startTime: Double, endTime: Double, audioURL: URL? = nil, transcript: String = "", isProcessed: Bool = false, phiDetected: Bool = false, phiTerms: [String] = []) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.audioURL = audioURL
        self.transcript = transcript
        self.isProcessed = isProcessed
        self.phiDetected = phiDetected
        self.phiTerms = phiTerms
    }

    var duration: Double {
        endTime - startTime
    }
}

enum AudioProcessing: String, CaseIterable, Codable {
    case noiseReduction = "Noise Reduction"
    case deEss = "De-Ess"
    case loudnessNormalization = "Loudness Normalization"
    case compressor = "Compressor"

    var systemImage: String {
        switch self {
        case .noiseReduction: return "waveform.path.ecg"
        case .deEss: return "waveform.path.badge.minus"
        case .loudnessNormalization: return "speaker.wave.2"
        case .compressor: return "waveform.and.magnifyingglass"
        }
    }
}

// MARK: - Narration Editor View

struct NarrationEditorView: View {
    @Binding var narrations: [NarrationSegment]
    let videoDuration: Double
    @State private var currentTime: Double = 0
    @State private var isRecording = false
    @State private var recordingStartTime: Double = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioEngine = AVAudioEngine()
    @State private var selectedProcessing: Set<AudioProcessing> = []
    @State private var showTranscriptEditor = false
    @State private var selectedSegmentID: UUID?
    @State private var targetLoudness: Double = -16.0
    @State private var showPHIWarning = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Recording Controls
                    recordingSection

                    // Audio Processing
                    audioProcessingSection

                    // Timeline
                    timelineSection

                    // Narration List
                    narrationListSection

                    // PHI Detection
                    if narrations.contains(where: { $0.phiDetected }) {
                        phiWarningSection
                    }
                }
                .padding()
            }
            .navigationTitle("Narration & Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        processAllAudio()
                    } label: {
                        Label("Process All", systemImage: "wand.and.stars")
                    }
                }
            }
            .alert("PHI Detected in Audio", isPresented: $showPHIWarning) {
                Button("Review", role: .cancel) {}
            } message: {
                Text("Patient-identifying information detected in narration. Please review and re-record or use synthetic voice.")
            }
            .onAppear { requestMicrophonePermission() }
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Record Narration")
                    .font(.headline)
                Spacer()
                Text("Position: \(currentTime, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $currentTime, in: 0...max(videoDuration, 1))

            HStack(spacing: 12) {
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Label(isRecording ? "Stop Recording" : "Start Recording", systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .blue)

                if isRecording {
                    Text("Recording... \(currentTime - recordingStartTime, specifier: "%.1f")s")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if !narrations.isEmpty {
                Button {
                    showTranscriptEditor = true
                } label: {
                    Label("Edit Transcripts & Captions", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var audioProcessingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Processing (DSP)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(AudioProcessing.allCases, id: \.self) { processing in
                    Toggle(isOn: Binding(
                        get: { selectedProcessing.contains(processing) },
                        set: { isSelected in
                            if isSelected {
                                selectedProcessing.insert(processing)
                            } else {
                                selectedProcessing.remove(processing)
                            }
                        }
                    )) {
                        Label(processing.rawValue, systemImage: processing.systemImage)
                    }
                    .tint(.blue)
                }

                if selectedProcessing.contains(.loudnessNormalization) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Loudness: \(Int(targetLoudness)) LUFS")
                            .font(.caption)
                        Slider(value: $targetLoudness, in: -24...(-12))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Timeline")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 60)

                    ForEach(narrations) { segment in
                        narrationTimelineBar(segment, containerWidth: geometry.size.width)
                    }

                    let offset = (currentTime / max(videoDuration, 1)) * geometry.size.width * 0.85
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 60)
                        .offset(x: offset)
                }
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func narrationTimelineBar(_ segment: NarrationSegment, containerWidth: CGFloat) -> some View {
        let startOffset = (segment.startTime / max(videoDuration, 1)) * containerWidth * 0.85
        let width = (segment.duration / max(videoDuration, 1)) * containerWidth * 0.85

        return RoundedRectangle(cornerRadius: 4)
            .fill(segment.phiDetected ? Color.red.opacity(0.7) : Color.blue.opacity(0.7))
            .frame(width: max(width, 4), height: 40)
            .offset(x: startOffset)
            .overlay(
                Image(systemName: segment.isProcessed ? "checkmark" : "waveform")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .offset(x: startOffset)
            )
    }

    private var narrationListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Narration Segments (\(narrations.count))")
                .font(.headline)

            if narrations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No narration recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(narrations.sorted(by: { $0.startTime < $1.startTime })) { segment in
                    NarrationSegmentRow(
                        segment: segment,
                        isSelected: selectedSegmentID == segment.id,
                        onSelect: { selectedSegmentID = segment.id },
                        onDelete: { deleteSegment(segment) },
                        onTranscribe: { transcribeSegment(segment) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var phiWarningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("PHI Detected in Audio")
                    .font(.headline)
            }

            Text("Some narration segments contain potential patient-identifying information. Review and re-record, or use synthetic TTS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(narrations.filter { $0.phiDetected }) { segment in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Segment at \(segment.startTime, specifier: "%.1f")s")
                        .font(.caption.weight(.semibold))
                    Text("Terms: \(segment.phiTerms.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button {
                // Placeholder for synthetic TTS
            } label: {
                Label("Generate Synthetic Voice", systemImage: "waveform.badge.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recording Functions

    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted {
                    print("Microphone permission denied")
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    print("Microphone permission denied")
                }
            }
        }
    }

    private func startRecording() {
        recordingStartTime = currentTime

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndoReelsNarration", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).m4a")

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            if !FileManager.default.fileExists(atPath: tempURL.deletingLastPathComponent().path) {
                try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            }

            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        guard let recorder = audioRecorder else { return }

        recorder.stop()
        let endTime = currentTime
        let url = recorder.url

        let segment = NarrationSegment(
            startTime: recordingStartTime,
            endTime: endTime,
            audioURL: url,
            transcript: "",
            isProcessed: false
        )

        narrations.append(segment)
        isRecording = false
        audioRecorder = nil

        // Auto-transcribe
        transcribeSegment(segment)
    }

    private func transcribeSegment(_ segment: NarrationSegment) {
        guard segment.audioURL != nil,
              let index = narrations.firstIndex(where: { $0.id == segment.id }) else { return }

        // Simulate transcription and PHI detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let mockTranscript = "This is a sample narration for the procedure at \(segment.startTime) seconds."
            let phiTerms = detectPHI(in: mockTranscript)

            narrations[index].transcript = mockTranscript
            narrations[index].isProcessed = true
            narrations[index].phiDetected = !phiTerms.isEmpty
            narrations[index].phiTerms = phiTerms

            if !phiTerms.isEmpty {
                showPHIWarning = true
            }
        }
    }

    private func detectPHI(in text: String) -> [String] {
        // Simplified PHI detection (in production, use NLP/NER)
        let phiPatterns = ["patient", "mr.", "mrs.", "john", "jane", "smith", "initials"]
        let lowercased = text.lowercased()
        return phiPatterns.filter { lowercased.contains($0) }
    }

    private func deleteSegment(_ segment: NarrationSegment) {
        narrations.removeAll { $0.id == segment.id }
        if let audioURL = segment.audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    private func processAllAudio() {
        // Placeholder for batch audio processing with selected DSP effects
        for i in narrations.indices {
            narrations[i].isProcessed = true
        }
    }
}

private struct NarrationSegmentRow: View {
    let segment: NarrationSegment
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTranscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(segment.phiDetected ? .red : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(segment.startTime, specifier: "%.1f")s → \(segment.endTime, specifier: "%.1f")s")
                        .font(.subheadline.weight(.semibold))
                    if !segment.transcript.isEmpty {
                        Text(segment.transcript)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("No transcript")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                Spacer()

                if segment.isProcessed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if segment.phiDetected {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 8) {
                if !segment.isProcessed && segment.audioURL != nil {
                    Button(action: onTranscribe) {
                        Label("Transcribe", systemImage: "text.viewfinder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(segment.phiDetected ? Color.orange : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
    }
}

#Preview {
    NarrationEditorView(narrations: .constant([]), videoDuration: 60)
}
