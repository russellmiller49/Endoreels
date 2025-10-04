EndoReels — VS Code AI Coding Assistant Brief (working_v1)
Project Context (for the AI)

App: iOS SwiftUI app to author & review endoscopic teaching reels (Pulmonary & GI).

Key recent features (already in repo):

“Review Full Reel” sheet before submit, with real playback and PiP overlay when a step has two assets.

Robust Creator Studio (service‑line presets, procedure pickers, blank/demo templates), storyboard editor with step editor sheet, audio ingestion + simple editing, comments on reels, cancel/return‑home, and onboarding demo tour.

Client stubs for Auth + Credits using .env‑driven config; Feed & Search v1 (client local) with specialty‑aware defaults.

Pivot: No AI scene detection for now. We’re building a Manual Editing MVP (non‑destructive timeline editor) and keeping AI only for PHI review later.

Secrets: Never ship service‑role keys or OpenAI keys in the client. .env.example exists; Xcode Scheme must provide env vars for simulator.

Global Standards & Constraints

Targets: iOS 17+, Swift 5.9+, SwiftUI, Combine, AVFoundation, Accelerate/vDSP.

Concurrency: Use @MainActor for UI/state types, use actor or nonisolated correctly for stores & pipelines.

SwiftUI: Use iOS 17 onChange(of:initial:_:) (avoid deprecated overloads). Use confirmationDialog with isPresented + presenting for optionals.

Data: Non‑destructive edits. Original media untouched. Drafts journaled to disk for crash‑safety.

Files: Prefer small, testable files. Add unit tests where feasible (XCTest).

Security: No PHI leaves device during editing; all local until export/publish. Do not embed secrets.

Milestones Overview

M0. Repo hygiene & branch prep (remove AI scene‑detect UI safely, keep PHI hooks).

M1. Data model & draft storage (Timeline/Segment/Draft + journaling + undo/redo).

M2. Media pipeline (proxy transcode, thumbnail sprites, waveform sampling).

M3. Timeline Editor UI (Clipper) (I/O selection, segment lane, snap + haptics, ripple, split/merge, speed presets, markers, undo/redo, autosave).

M4. Review → Steps (convert segments to pedagogic steps used by existing storyboard).

M5. Export (AVComposition + ExportSession with frame alignment, background completion).

M6. Server wiring (credits/search/feed) — later, after MVP compiles & runs.

M7. PHI Review & Publish Gate — once MVP stable.

Work in order. Each milestone below includes Tasks, Files, and Definition of Done (DoD).

M0 — Repo Hygiene & Branch Prep (No AI Scene Detect UI)

Goal: Remove/hide any “AI scene detection / Process with AI / AI Suggested” UI so users aren’t confused. Leave PHI plumbing for later.

Tasks

Search & Remove/Hide

Find strings: "Process with AI", "AI Suggested", "Enhanced", "AISuggestionReviewView".

Remove related buttons/labels and conditional views in Creator and Preview.

Remove credit deduction triggers tied to AI scene processing. Keep credits domain for future PHI.

Keep PHI hooks

Leave any PHI review types, but ensure no PHI network calls are reachable in UI for now.

Update copy

Preview/publish cards: ensure no “AI” wording remains. Replace with “Manual Review” language.

Files

CreatorView.swift (remove AI process button & suggestion handling)

APIClient.swift (retain types; you may comment client stubs for process‑video)

CreditsStore.swift (ensure no AI deduction path remains; credits will later be used for PHI only)

README.md (reflect pivot to Manual Editing MVP)

DoD

Build succeeds. No UI mentions of AI scene detect or “Process with AI.” Credits unchanged by editing operations.

Copilot Chat prompt (paste):

Search the repo for “Process with AI”, “AI Suggested”, and “AISuggestionReviewView”. Remove UI and logic that triggers AI scene detection. Keep PHI plumbing intact for future use. Update any strings that imply AI auto‑cutting to manual wording. Ensure build passes.

M1 — Data Model & Draft Storage (Non‑Destructive)

Goal: Introduce a minimal, non‑destructive timeline graph with journaling & undo/redo.

Create Files

EndoReels/TimelineModels.swift

import Foundation

public enum TimelineError: Error {
  case invalidRange
  case missingAsset
  case exportInProgress
}

public struct MediaAsset: Identifiable, Codable, Hashable {
  public var id: UUID
  public var uri: URL              // original local asset URL
  public var duration: TimeInterval
  public var frameRate: Double
  public var createdAt: Date
  public var proxyURL: URL?        // generated M2
  public var thumbnailSpriteURL: URL? // generated M2
  public var waveformURL: URL?     // generated M2
}

public struct Marker: Identifiable, Codable, Hashable {
  public var id: UUID
  public var time_s: TimeInterval
  public var label: String
}

public struct Segment: Identifiable, Codable, Hashable {
  public var id: UUID
  public var assetID: UUID
  public var start_s: TimeInterval
  public var end_s: TimeInterval
  public var speed: Double // 0.5, 1.0, 1.25, 2.0
  public var label: String
  public var markers: [Marker]
}

public struct Timeline: Identifiable, Codable {
  public var id: UUID
  public var title: String
  public var difficulty: String
  public var segmentOrder: [UUID] // Segment IDs in order
}

public struct Draft: Identifiable, Codable {
  public var id: UUID
  public var asset: MediaAsset
  public var segments: [UUID: Segment]
  public var timeline: Timeline
  // UI state (not for export)
  public var playhead_s: TimeInterval
  public var zoomLevel: Double
  public var selectedSegmentID: UUID?
  public var updatedAt: Date
}

// Undo/Redo entries
public struct DraftDelta: Codable {
  public var timestamp: Date
  public var description: String
  public var patchData: Data // opaque patch; implement as full Draft snapshot initially (simpler)
}


EndoReels/DraftStore.swift

import Foundation

// Persist drafts under Application Support; journal deltas for crash-safety.
public actor DraftStore {
  public enum Location {
    case applicationSupport
  }

  private let baseURL: URL
  private let fileManager = FileManager()

  public init(location: Location = .applicationSupport) throws {
    let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    baseURL = appSupport.appendingPathComponent("EndoReelsDrafts", isDirectory: true)
    if !fileManager.fileExists(atPath: baseURL.path) {
      try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
  }

  public func saveSnapshot(_ draft: Draft) throws {
    let draftURL = baseURL.appendingPathComponent("\(draft.id.uuidString).json")
    let data = try JSONEncoder().encode(draft)
    try data.write(to: draftURL, options: [.atomic])
  }

  public func loadDraft(id: UUID) throws -> Draft? {
    let url = baseURL.appendingPathComponent("\(id.uuidString).json")
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Draft.self, from: data)
  }

  public func deleteDraft(id: UUID) throws {
    let url = baseURL.appendingPathComponent("\(id.uuidString).json")
    if fileManager.fileExists(atPath: url.path) {
      try fileManager.removeItem(at: url)
    }
  }
}


Integrate DraftStore into AppState.swift (create a property, initialize lazily under @MainActor, call saveSnapshot on significant edits).

Modify

Where Creator currently manages steps, add a parallel “Manual Edit Draft” route (will be used by the Clipper in M3). This can live side‑by‑side with existing storyboard until M4.

DoD

Can create a Draft in memory, save/load snapshots through DraftStore.

Basic @MainActor plumbing present in AppState for holding a current Draft.

Copilot Chat prompt

Create TimelineModels.swift and DraftStore.swift as specified above. Add an @MainActor draftStore to AppState that can save/load a Draft. Ensure Application Support directory is created on first run.

M2 — Media Pipeline (Proxy, Thumbnails, Waveform)

Goal: Smooth editing on mobile via lightweight proxies, sprite thumbnails, and waveform RMS.

Create
EndoReels/MediaProcessingPipeline.swift

import AVFoundation
import Accelerate
import UIKit

public struct MediaProxy {
  public var proxyURL: URL
  public var thumbnailSpriteURL: URL
  public var waveformURL: URL
}

public final class MediaProcessingPipeline {
  public init() {}

  // 1) Generate ~540p H.264 proxy (fast transcode)
  public func generateProxy(for original: URL) async throws -> URL {
    // Use AVAssetExportSession with presetMediumQuality; write to /tmp/EndoReelsMediaProxy
    // Return URL to proxy file
    throw NSError(domain: "TODO", code: -1)
  }

  // 2) Generate thumbnail sprite (e.g., every ~2–3 s)
  public func generateThumbnailSprite(for assetURL: URL, frameIntervalSeconds: Double = 2.0) async throws -> URL {
    // Use AVAssetImageGenerator; composite into a grid PNG; return file URL
    throw NSError(domain: "TODO", code: -1)
  }

  // 3) Generate waveform RMS samples
  public func generateWaveform(for assetURL: URL, sampleWindow: Int = 1024) async throws -> URL {
    // Use AVAssetReader to pull audio samples; compute RMS via vDSP; write JSON/CSV of RMS values; return URL
    throw NSError(domain: "TODO", code: -1)
  }
}


Integrate

When importing a video into a new Draft, kick off MediaProcessingPipeline tasks in the background:

Set MediaAsset.proxyURL, thumbnailSpriteURL, waveformURL as they become available.

Display progressively (UI will use these in M3).

Store proxies under /tmp/EndoReelsMediaProxy and exclude from backups.

DoD

Importing a video schedules proxy/thumbnail/waveform generation.

URLs are saved into the Draft.asset as tasks complete.

Copilot Chat prompt

Implement MediaProcessingPipeline functions with AVFoundation and vDSP as stubs now (throw), then wire the calls from Creator import flow. Add TODOs where actual export and sampling will go. Ensure generated files are placed under a dedicated temp directory and excluded from backups.

M3 — Timeline Editor UI (Clipper)

Goal: A performant, thumb‑reachable Clipper with I/O selection, segment lane, snap + haptics, ripple delete, split/merge, speed presets, markers, waveform + thumbnails, undo/redo, autosave.

Create

EndoReels/TimelineEditorView.swift (SwiftUI shell embedding a performant lane)

import SwiftUI
import AVKit

public struct TimelineEditorView: View {
  @Binding var draft: Draft        // From AppState
  let onClose: () -> Void          // Return to storyboard

  @State private var inPoint: TimeInterval?
  @State private var outPoint: TimeInterval?
  @State private var isRippleDelete: Bool = true

  public init(draft: Binding<Draft>, onClose: @escaping () -> Void) {
    _draft = draft
    self.onClose = onClose
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Top: Player + scrub bar using proxy if available
      VideoPlayer(player: AVPlayer(url: draft.asset.proxyURL ?? draft.asset.uri))
        .frame(height: 220)

      // Thumbnails + waveform strips (custom views that read sprite/waveform URLs)
      ThumbnailStripView(spriteURL: draft.asset.thumbnailSpriteURL)
      WaveformView(waveformURL: draft.asset.waveformURL)

      // Middle controls
      HStack {
        Button("Set In") { setIn() }.buttonStyle(.borderedProminent)
        Button("Set Out") { setOut() }.buttonStyle(.borderedProminent)
        Button("Add Segment") { addSegment() }.buttonStyle(.bordered)
      }.padding(.vertical, 8)

      // Segment lane
      SegmentLaneView(draft: $draft, isRippleDelete: $isRippleDelete)

      // Toolbar
      ToolbarView(
        onSplit: splitAtPlayhead,
        onMerge: mergeSelected,
        onRippleToggle: { isRippleDelete.toggle() },
        onRemoveSilence: removeSilence,
        onSpeed: cycleSpeedPreset,
        onMarker: addMarker,
        onUndo: undo,
        onRedo: redo
      )
    }
    .navigationTitle("Clipper")
    .toolbar { Button("Close", action: onClose) }
    .onDisappear { autosave() }
  }

  // MARK: - Intent

  private func setIn() { /* set inPoint = current playhead */ }
  private func setOut() { /* set outPoint = current playhead */ }
  private func addSegment() { /* validate I/O & append; push undo; autosave */ }
  private func splitAtPlayhead() { /* split selected segment */ }
  private func mergeSelected() { /* merge two adjacent */ }
  private func removeSilence() { /* deterministic RMS/luma sweep → create suggested cuts or trim */ }
  private func cycleSpeedPreset() { /* 0.5x → 1.0x → 1.25x → 2.0x */ }
  private func addMarker() { /* add marker to selected segment at playhead */ }
  private func undo() { /* pop undo stack */ }
  private func redo() { /* pop redo stack */ }
  private func autosave() { /* DraftStore.saveSnapshot(draft) */ }
}


EndoReels/TimelineSubViews/ThumbnailStripView.swift

EndoReels/TimelineSubViews/WaveformView.swift

EndoReels/TimelineSubViews/SegmentLaneView.swift (chips UI with reorder, swipe delete)

EndoReels/TimelineSubViews/ToolbarView.swift (split/merge/ripple/speed/markers/undo/redo toggles)

EndoReels/Haptics.swift (wrap UIImpactFeedbackGenerator; fire when snapping to ticks/edges)

Modify

Add a “Edit Video (Manual)” entry point in Creator (e.g., inside media card or a new “Manual Edit” button) to open TimelineEditorView with the selected asset → returns to Creator on close.

Selection model: when the user long‑presses on the video, set In/Out; double‑tap → drop Marker.

Behavior & Rules

Snap: Snap playhead/handles to 1 s grid, segment edges, and markers. Provide haptic on snap.

Ripple delete: Default true. Toggle in toolbar. When deleting a segment with ripple on, adjust downstream segments’ start times in the timeline order.

Undo/redo: Keep an in‑memory stack (cap ~100). Each timeline mutation pushes a description and snapshot (or minimal patch).

Autosave: After each mutation (throttle), write snapshot via DraftStore.

DoD

Clipper compiles and displays: player + thumb strip + waveform placeholders.

Can set I/O and “Add Segment,” see segments appear as chips; reorder and delete segments; ripple toggle works (logic stub acceptable if tested in code).

Haptics fire on snap points (stub ok if device not available).

Undo/redo stack operates on add/delete/reorder.

Autosave writes draft to disk; reload draft on reopen.

Copilot Chat prompt

Create TimelineEditorView and subviews for thumbnails, waveform, segment lane, and toolbar as specified. Wire I/O selection, add segment, reorder, delete with ripple toggle, undo/redo, autosave via DraftStore. Implement snap targets (1 s ticks, segment edges, markers) and call Haptics.shared.snap() on snap events.

M4 — Review → Steps (Integrate with Creator Storyboard)

Goal: Convert selected Segments into Steps for the current case, preserving the clean pedagogic structure already supported by Creator/Preview.

Tasks

Add a “Convert to Steps” button in TimelineEditorView or a separate Review screen.

Map each Segment to a storyboard Step with: title (default from label or “Segment N”), start/end metadata, and attach the corresponding media (the original asset or a range reference depending on export flow).

Update CreatorView to display the newly added steps in the existing storyboard list and in the Reel preview sheet.

DoD

After editing, user taps Convert to Steps, returns to Creator with new steps populated.

Reel Preview plays the selected sub‑ranges in order (until export exists, playback can use time‑offsets on the original asset).

Copilot Chat prompt

Add a “Convert to Steps” action that maps Timeline Segments into storyboard Steps in CreatorView. Use the segment label or “Segment N” for step titles. Ensure the Reel Preview sheet plays these steps in the right order using time-ranged playback when possible.

M5 — Export (Zero Re‑encode Editing → Export Only)

Goal: Compose an export from the graph using AVMutableComposition and AVAssetExportSession, rounding cuts to the nearest frame.

Create
EndoReels/Exporter.swift

import AVFoundation

public final class Exporter {
  public enum ExportError: Error { case compositionFailed, exportFailed }

  public func makeComposition(from draft: Draft) throws -> AVMutableComposition {
    // Build tracks from draft.timeline and draft.segments
    // Insert time ranges using CMTime aligned to asset's timescale
    // Apply per-segment speed (time scaling)
    throw ExportError.compositionFailed
  }

  public func export(_ composition: AVMutableComposition, to url: URL, preset: String = AVAssetExportPresetHighestQuality) async throws {
    // Configure AVAssetExportSession, monitor progress, await completion
    throw ExportError.exportFailed
  }
}


Integrate

Add Export button in the Review screen to render the clip; show progress and local save result; post a local notification when complete (background).

DoD

Export produces a playable file (even if composed from a subset of features at first).

Frame alignment logic exists (round to frame via asset timescale, avoid A/V drift).

Copilot Chat prompt

Implement Exporter.makeComposition to stitch segments with frame-aligned ranges and per-segment speed. Add an “Export” action in the Review view that writes the file to a temporary location and shows progress.

M6 — Server Wiring (after MVP compiles)

Goal: Replace stubs with real calls.

Tasks

Hook CreditsStore to live endpoints (idempotency key header + audit log).

Replace client search/feed stubs with /api/search, /api/autocomplete, /api/feed?cursor=….

Persist continue‑watching with /api/progress.

DoD

Credits reflect real server balance; searching and feed pagination are live.

Copilot Chat prompt

Replace client stubs for credits and search/feed with real endpoints. Preserve bearer injection from AppState.authSession. Add an idempotency key header to credit mutations and verify balance refresh after mutation.

M7 — PHI Review & Publish Gate (post‑MVP)

Goal: Enforce PHI checks at publish.

Tasks

Build a PHI queue view (confidence chips, before/after slider).

Block publish if unresolved; client shows error with actions to resolve.

DoD

Attempting to publish runs PHI gate; unresolved findings stop publish.

Copilot Chat prompt

Implement a PHI Review screen that lists findings with confidence chips and a before/after slider. Wire publish to refuse when unresolved issues remain, and show actionable guidance.

QA & Manual Test Plan (Simulator)

Import → Proxy: Import a 10‑minute clip; proxy/thumbnail/waveform generate; UI loads progressively.

Clipper Basics: Set In/Out; Add segment; reorder; delete with ripple ON/OFF; haptics on snap.

Assist Tools: Remove Silence (deterministic rule); add markers; speed preset 0.5× / 1.25× / 2×.

Undo/Redo: Perform 10+ edits and walk back/forward.

Autosave/Crash‑safety: Background/kill app; re‑open → draft restored.

Convert to Steps: Steps appear in Creator storyboard; Preview plays in order with PiP when present.

Export: Composition renders and file plays.

VS Code Setup (optional but recommended)

Create /.vscode/extensions.json:

{
  "recommendations": [
    "github.copilot-chat",
    "sswg.swift-lang",
    "streetsidesoftware.code-spell-checker"
  ]
}


Create /.vscode/settings.json:

{
  "files.associations": { "*.swift": "swift" },
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "sswg.swift-lang"
}

Git Workflow
# Ensure you’re on your manual-editing branch
git checkout -b feature/manual-editing-mvp

# Commit small, logical changes
git add -A
git commit -m "M1: Add non-destructive timeline models and DraftStore (journaled snapshots)"

# Push and open PR when M3 compiles
git push -u origin feature/manual-editing-mvp


Commit style: M{n}: <short summary> (e.g., M3: Clipper UI skeleton with I/O and segment lane)

Environment Variables (recap)

.env.example → copy to .env.

Xcode → Scheme → Run → Environment Variables must include:

API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_JWT_SECRET, (server‑side only: SUPABASE_SERVICE_ROLE_KEY — never bundle in client).

Using new Supabase key/JWT format is fine—names unchanged.

Known Good Areas (context for AI)

CreatorView.swift: Reel preview sheet, PiP overlay rendering, storyboard editor with step sheet, templates (Demo Pulmonary / Demo GI / Blank), Home/Cancel navigation.

FeedView.swift: Specialty‑aware feed & search stubs; “View Demo Tour” card.

AuthService.swift, CreditsStore.swift, APIClient.swift, AppState.swift: Auth + credits stubs with bearer injection and .env‑driven config.

MediaAssetEditorView.swift, MediaLibrary.swift: Audio ingestion/editing scaffolding.

ReelDetailView.swift: Commenting.

.env.example, AppConfig.swift: Secrets wiring.

Backlog After MVP

Infinite scroll feed, Quick Peek long‑press previews.

Player enhancements: step rail, pearls drawer, integrity banner (if speed ≠ 1×).

Sign‑up flow (in‑app) or hosted form.

More deterministic assists: motion spike markers, overlay HUD detector, compress pauses.

Final AI Reminder

Do not introduce third‑party dependencies for core editing unless necessary.

Preserve non‑destructive editing; export is the only encode step.

Keep PHI processing server‑side & gated at publish in later milestones.

Respect iOS 17 APIs (onChange signature, etc.) and Combine/@Published patterns.

Start here:
“Follow M0 and M1 in this file. Create the new Swift files as specified, integrate DraftStore into AppState, and add a ‘Manual Edit’ entry point to open TimelineEditorView. Stop after the project compiles.”