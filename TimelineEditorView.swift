import SwiftUI
import AVKit

struct TimelineEditorView: View {
    @Binding var draft: Draft
    let onClose: (Draft) -> Void

    @State private var inPoint: TimeInterval?
    @State private var outPoint: TimeInterval?
    @State private var isRippleDelete = true
    @State private var undoStack: [DraftDelta] = []
    @State private var redoStack: [DraftDelta] = []
    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var sliderValue: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var message: String?
    @State private var messageWorkItem: DispatchWorkItem?
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var timeObserver: Any?
    @State private var showHelp = false
    @AppStorage("TimelineEditorHasShownHelp") private var hasShownHelp = false
    @State private var didSendClose = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let speedPresets: [Double] = [0.5, 1.0, 1.25, 2.0]
    private let snapThreshold: TimeInterval = 0.18
    private let autosaveDelay: TimeInterval = 0.6

    init(draft: Binding<Draft>, onClose: @escaping (Draft) -> Void) {
        self._draft = draft
        self.onClose = onClose
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: player)
                .frame(height: 220)
                .onAppear { configurePlayer() }
                .onChange(of: draft.asset.proxyURL) { _, _ in configurePlayer() }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .padding(.trailing, 6)
                    }
                    .buttonStyle(.plain)

                    Slider(value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            isScrubbing = true
                            sliderValue = newValue
                            draft.playhead_s = newValue
                            seekPlayer(to: newValue)
                        }
                    ), in: 0...maxDuration, onEditingChanged: { editing in
                        if !editing {
                            let snapped = snapValue(draft.playhead_s)
                            sliderValue = snapped
                            draft.playhead_s = snapped
                            seekPlayer(to: snapped)
                            isScrubbing = false
                        }
                    })
                    .accentColor(.accentColor.opacity(0.7))
                }

                if !canAddSegment {
                    Text("Tip: Set both In and Out points to enable Add Segment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(timecode(draft.playhead_s))
                    Spacer()
                    if let inPoint { Text("In " + timecode(inPoint)) }
                    if let outPoint { Text("Out " + timecode(outPoint)) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()

           ThumbnailStripView(
               spriteURL: draft.asset.thumbnailSpriteURL,
               duration: draft.asset.duration,
               playhead: draft.playhead_s,
               inPoint: inPoint,
               outPoint: outPoint
           )
           .frame(height: 80)
            .background(
                Group {
                    if draft.asset.thumbnailSpriteURL == nil {
                        Text("Thumbnail sprite pending…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            )

           WaveformView(
               waveformURL: draft.asset.waveformURL,
               duration: draft.asset.duration,
               playhead: draft.playhead_s,
               inPoint: inPoint,
               outPoint: outPoint
           )
           .frame(height: 80)
           .padding(.horizontal)
           .padding(.bottom, 8)

            HStack(spacing: 12) {
                Button("Set In") { setIn() }
                    .buttonStyle(.borderedProminent)
                Button("Set Out") { setOut() }
                    .buttonStyle(.borderedProminent)
                Button("Add Segment") { addSegment() }
                    .buttonStyle(.bordered)
                    .disabled(!canAddSegment)
            }
            .padding(.bottom, 8)

            SegmentLaneView(
                segments: segmentDisplays,
                selectedSegmentID: draft.selectedSegmentID,
                isRippleDelete: isRippleDelete,
                onSelect: { selectSegment(id: $0) },
                onMoveLeft: { moveSegmentLeft(index: $0) },
                onMoveRight: { moveSegmentRight(index: $0) },
                onDelete: { deleteSegment(id: $0) }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)

            ToolbarView(
                isRippleOn: isRippleDelete,
                canUndo: !undoStack.isEmpty,
                canRedo: !redoStack.isEmpty,
                onSplit: splitAtPlayhead,
                onMerge: mergeSelected,
                onRippleToggle: toggleRipple,
                onRemoveSilence: removeSilence,
                onSpeed: cycleSpeedPreset,
                onMarker: addMarker,
                onUndo: undo,
                onRedo: redo
            )
            .padding()

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Clipper")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    autosaveNow()
                    finishAndClose()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .onAppear {
            sliderValue = draft.playhead_s
            if !hasShownHelp {
                hasShownHelp = true
                showHelp = true
            }
        }
        .onDisappear {
            // Clean up player resources
            removeTimeObserver()
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        .onChange(of: draft.playhead_s) { _, newValue in
            if !isScrubbing {
                sliderValue = newValue
            }
        }
        .onDisappear { autosaveNow() }
        .onDisappear { messageWorkItem?.cancel() }
        .onDisappear {
            player.pause()
            isPlaying = false
            removeTimeObserver()
            player.replaceCurrentItem(with: nil)
            finishAndClose()
        }
        .sheet(isPresented: $showHelp) {
            TimelineEditorHelpView(onDismiss: { showHelp = false })
        }
    }

    private var maxDuration: TimeInterval {
        max(draft.asset.duration, 0.1)
    }

    private var canAddSegment: Bool {
        if let start = inPoint, let end = outPoint {
            return end - start >= 0.1
        }
        return false
    }

    private var segmentDisplays: [SegmentDisplay] {
        draft.timeline.segmentOrder.enumerated().compactMap { entry in
            let (index, id) = entry
            guard let segment = draft.segments[id] else { return nil }
            return SegmentDisplay(segment: segment, index: index)
        }
    }

    private func configurePlayer() {
        // Clean up existing player state
        removeTimeObserver()
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        let playbackURL: URL
        if let proxy = draft.asset.proxyURL, FileManager.default.fileExists(atPath: proxy.path) {
            playbackURL = proxy
        } else {
            playbackURL = draft.asset.uri
        }
        
        // Validate URL accessibility
        guard FileManager.default.fileExists(atPath: playbackURL.path) else {
            print("❌ Video file not found at: \(playbackURL.path)")
            return
        }
        
        let asset = AVURLAsset(url: playbackURL)
        
        // Set up resource loader with proper error handling
        let resourceLoaderQueue = DispatchQueue(label: "AssetLoader", qos: .userInitiated)
        asset.resourceLoader.setDelegate(nil, queue: resourceLoaderQueue)
        
        let item = AVPlayerItem(asset: asset)
        
        // Add error handling for the player item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Player item failed: \(error.localizedDescription)")
            }
        }
        
        // Replace current item and configure
        player.replaceCurrentItem(with: item)
        
        // Wait for item to be ready before seeking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.seekPlayer(to: self.draft.playhead_s)
            self.addTimeObserver()
        }
    }

    private func seekPlayer(to time: TimeInterval) {
        guard player.currentItem != nil else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if !completed {
                print("❌ Seek operation failed for time: \(time)")
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isScrubbing else { return }
            let seconds = time.seconds
            let clamped = seconds.clamped(to: 0...maxDuration)
            draft.playhead_s = clamped
            sliderValue = clamped
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func setIn() {
        let snapped = snapValue(draft.playhead_s)
        if let outPoint, snapped >= outPoint {
            showMessage("In point must be before Out point")
            return
        }
        inPoint = snapped
        Haptics.shared.snap()
    }

    private func setOut() {
        let snapped = snapValue(draft.playhead_s)
        if let inPoint, snapped <= inPoint {
            showMessage("Out point must be after In point")
            return
        }
        outPoint = snapped
        Haptics.shared.snap()
    }

    private func addSegment() {
        guard let start = inPoint, let end = outPoint, end > start else { return }
        let snappedStart = snapValue(start)
        let snappedEnd = snapValue(end)
        mutateDraft(description: "Add Segment") { draft in
            var segment = Segment(
                assetID: draft.asset.id,
                start_s: snappedStart,
                end_s: snappedEnd,
                speed: 1.0,
                label: "Segment \(draft.timeline.segmentOrder.count + 1)",
                markers: []
            )
            if segment.end_s <= segment.start_s { segment.end_s = segment.start_s + 0.1 }
            draft.segments[segment.id] = segment
            draft.timeline.segmentOrder.append(segment.id)
            draft.selectedSegmentID = segment.id
            draft.playhead_s = segment.end_s
        }
        inPoint = nil
        outPoint = nil
    }

    private func selectSegment(id: UUID) {
        draft.selectedSegmentID = id
        if let segment = draft.segments[id] {
            draft.playhead_s = segment.start_s
            sliderValue = segment.start_s
            seekPlayer(to: segment.start_s)
            inPoint = segment.start_s
            outPoint = segment.end_s
        }
    }

    private func moveSegmentLeft(index: Int) {
        guard index > 0 else { return }
        mutateDraft(description: "Move Segment") { draft in
            draft.timeline.segmentOrder.swapAt(index, index - 1)
        }
    }

    private func moveSegmentRight(index: Int) {
        guard index < draft.timeline.segmentOrder.count - 1 else { return }
        mutateDraft(description: "Move Segment") { draft in
            draft.timeline.segmentOrder.swapAt(index, index + 1)
        }
    }

    private func deleteSegment(id: UUID) {
        guard let index = draft.timeline.segmentOrder.firstIndex(of: id), let segment = draft.segments[id] else { return }
        let delta = segment.end_s - segment.start_s
        mutateDraft(description: "Delete Segment") { draft in
            draft.timeline.segmentOrder.removeAll { $0 == id }
            draft.segments.removeValue(forKey: id)
            if isRippleDelete {
                for position in index..<draft.timeline.segmentOrder.count {
                    let currentID = draft.timeline.segmentOrder[position]
                    guard var current = draft.segments[currentID] else { continue }
                    current.start_s = max(0, current.start_s - delta)
                    current.end_s = max(current.start_s + 0.1, current.end_s - delta)
                    draft.segments[currentID] = current
                }
            }
            if draft.selectedSegmentID == id {
                draft.selectedSegmentID = draft.timeline.segmentOrder.first
            }
        }
    }

    private func splitAtPlayhead() {
        guard let selected = draft.selectedSegmentID,
              let segment = draft.segments[selected] else { return }
        let splitPoint = snapValue(draft.playhead_s)
        guard splitPoint > segment.start_s + 0.1, splitPoint < segment.end_s - 0.1 else {
            showMessage("Playhead must be within segment to split")
            return
        }
        mutateDraft(description: "Split Segment") { draft in
            guard var original = draft.segments[selected], let index = draft.timeline.segmentOrder.firstIndex(of: selected) else { return }
            original.end_s = splitPoint
            draft.segments[selected] = original
            let newSegment = Segment(
                assetID: original.assetID,
                start_s: splitPoint,
                end_s: segment.end_s,
                speed: original.speed,
                label: original.label + " B",
                markers: []
            )
            draft.segments[newSegment.id] = newSegment
            draft.timeline.segmentOrder.insert(newSegment.id, at: index + 1)
            draft.selectedSegmentID = newSegment.id
            draft.playhead_s = splitPoint
        }
    }

    private func mergeSelected() {
        guard let selected = draft.selectedSegmentID,
              let index = draft.timeline.segmentOrder.firstIndex(of: selected),
              index < draft.timeline.segmentOrder.count - 1 else { return }
        let nextID = draft.timeline.segmentOrder[index + 1]
        guard draft.segments[selected] != nil, let next = draft.segments[nextID] else { return }
        mutateDraft(description: "Merge Segments") { draft in
            guard var base = draft.segments[selected] else { return }
            base.end_s = max(base.end_s, next.end_s)
            base.markers.append(contentsOf: next.markers)
            draft.segments[selected] = base
            draft.segments.removeValue(forKey: nextID)
            draft.timeline.segmentOrder.remove(at: index + 1)
        }
    }

    private func toggleRipple() {
        isRippleDelete.toggle()
        Haptics.shared.toggle()
    }

    private func removeSilence() {
        showMessage("Silence detection will arrive in a later milestone.")
    }

    private func cycleSpeedPreset() {
        guard let selected = draft.selectedSegmentID, var segment = draft.segments[selected] else { return }
        let currentIndex = speedPresets.firstIndex(of: segment.speed) ?? 1
        let nextIndex = (currentIndex + 1) % speedPresets.count
        segment.speed = speedPresets[nextIndex]
        mutateDraft(description: "Adjust Speed") { draft in
            draft.segments[selected] = segment
        }
    }

    private func addMarker() {
        guard let selected = draft.selectedSegmentID, var segment = draft.segments[selected] else { return }
        let markerTime = snapValue(draft.playhead_s)
        let label = "Marker \(segment.markers.count + 1)"
        let marker = Marker(time_s: markerTime, label: label)
        segment.markers.append(marker)
        mutateDraft(description: "Add Marker") { draft in
            draft.segments[selected] = segment
        }
    }

    private func undo() {
        guard let last = undoStack.popLast() else { return }
        if let data = try? encoder.encode(draft) {
            redoStack.append(DraftDelta(timestamp: Date(), description: "Redo", patchData: data))
        }
        if let restored = try? decoder.decode(Draft.self, from: last.patchData) {
            draft = restored
            sliderValue = draft.playhead_s
            scheduleAutosave()
        }
    }

    private func redo() {
        guard let last = redoStack.popLast() else { return }
        if let data = try? encoder.encode(draft) {
            undoStack.append(DraftDelta(timestamp: Date(), description: "Undo", patchData: data))
        }
        if let restored = try? decoder.decode(Draft.self, from: last.patchData) {
            draft = restored
            sliderValue = draft.playhead_s
            scheduleAutosave()
        }
    }

    private func mutateDraft(description: String, _ update: (inout Draft) -> Void) {
        if let data = try? encoder.encode(draft) {
            undoStack.append(DraftDelta(timestamp: Date(), description: description, patchData: data))
            if undoStack.count > 100 { undoStack.removeFirst(undoStack.count - 100) }
            redoStack.removeAll()
        }
        update(&draft)
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { autosaveNow() }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: workItem)
    }

    private func autosaveNow() {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        draft.updatedAt = Date()
    }

    private func showMessage(_ text: String) {
        message = text
        messageWorkItem?.cancel()
        let workItem = DispatchWorkItem { message = nil }
        messageWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func finishAndClose() {
        guard !didSendClose else { return }
        didSendClose = true
        onClose(draft)
    }

    private func snapValue(_ value: TimeInterval) -> TimeInterval {
        let targets = snapTargets
        guard !targets.isEmpty else { return value.clamped(to: 0...maxDuration) }
        var best = value
        var bestDistance = snapThreshold
        for target in targets {
            let distance = abs(target - value)
            if distance < bestDistance {
                bestDistance = distance
                best = target
            }
        }
        if best != value { Haptics.shared.snap() }
        return best.clamped(to: 0...maxDuration)
    }

    private var snapTargets: [TimeInterval] {
        var set = Set<TimeInterval>()
        let duration = maxDuration
        if duration.isFinite, duration > 0 {
            var tick: TimeInterval = 0
            while tick <= duration {
                set.insert(tick)
                tick += 1
            }
        }
        for id in draft.timeline.segmentOrder {
            if let segment = draft.segments[id] {
                set.insert(segment.start_s)
                set.insert(segment.end_s)
                for marker in segment.markers {
                    set.insert(marker.time_s)
                }
            }
        }
        return Array(set).sorted()
    }

    private func timecode(_ value: TimeInterval) -> String {
        let totalSeconds = max(value, 0)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let fraction = Int((totalSeconds - floor(totalSeconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, fraction)
    }
}

private extension TimeInterval {
    func clamped(to range: ClosedRange<TimeInterval>) -> TimeInterval {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct TimelineEditorHelpView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Get Started") {
                    Label("Scrub with the playhead, then tap Set In / Set Out to choose a clip.", systemImage: "cursorarrow.motionlines")
                    Label("Tap Add Segment to drop the selection into the timeline lane.", systemImage: "timeline.selection")
                    Label("Select a chip to adjust it, split, merge, or change speed.", systemImage: "rectangle.3.group")
                }

                Section("Pro Tips") {
                    Label("Ripple Delete shifts later segments forward when you delete.", systemImage: "waveform.path")
                    Label("Markers drop at the playhead; use them to call out key teaching beats.", systemImage: "bookmark")
                    Label("Undo/Redo captures each edit and auto-saves your progress.", systemImage: "arrow.uturn.backward")
                }

                Section("What’s Next") {
                    Label("Convert segments to storyboard steps from the Creator screen after trimming.", systemImage: "list.bullet.rectangle")
                }
            }
            .navigationTitle("Timeline Tips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
