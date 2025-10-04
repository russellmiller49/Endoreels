import Foundation
import Combine

/// Root application state shared across major features.
@MainActor
final class AppState: ObservableObject {
    enum PendingNavigationAction: Equatable {
        case openSampleCase
        case openCreator(ServiceLine)
    }

    private enum Keys {
        static let onboardingCompleted = "com.endoreels.onboardingCompleted"
        static let preferredServiceLine = "com.endoreels.preferredServiceLine"
    }

    private lazy var draftStore: DraftStore? = {
        do {
            return try DraftStore()
        } catch {
            #if DEBUG
            print("DraftStore initialization failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }()

    private var isRestoringDraft = false
    private let mediaPipeline = MediaProcessingPipeline()

    @Published var currentUser: CurrentUser
    @Published var creditsStore: CreditsStore
    @Published var onboardingCompleted: Bool
    @Published var pendingNavigation: PendingNavigationAction?
    @Published var activeDraft: Draft? {
        didSet {
            guard !isRestoringDraft, let draft = activeDraft else { return }
            persistDraftSnapshot(draft)
        }
    }
    @Published var draftPersistenceError: String?

    init(currentUser: CurrentUser? = nil, creditsStore: CreditsStore? = nil) {
        let storedRole = UserDefaults.standard.string(forKey: Keys.preferredServiceLine).flatMap(ServiceLine.init(rawValue:))
        let user = currentUser ?? CurrentUser.demoUser(role: storedRole)
        self.currentUser = user

        if let creditsStore {
            self.creditsStore = creditsStore
        } else {
            self.creditsStore = CreditsStore()
        }

        self.onboardingCompleted = UserDefaults.standard.bool(forKey: Keys.onboardingCompleted)
    }

    func beginDraft(for asset: MediaAsset, title: String, difficulty: String) {
        let timeline = Timeline(title: title, difficulty: difficulty, segmentOrder: [])
        let draft = Draft(asset: asset, segments: [:], timeline: timeline, updatedAt: .now)
        activeDraft = draft
    }

    func prepareDraftForImportedVideo(_ importedAsset: ImportedMediaAsset, title: String, difficulty: String, store: DemoDataStore) {
        guard importedAsset.kind == .video else { return }
        let mediaAsset = MediaAsset(id: importedAsset.id,
                                    uri: importedAsset.url,
                                    duration: importedAsset.duration ?? 0,
                                    frameRate: defaultFrameRate,
                                    createdAt: importedAsset.createdAt)
        if activeDraft == nil {
            beginDraft(for: mediaAsset, title: title, difficulty: difficulty)
        } else {
            applyDraftMutation { draft in
                draft.asset = mediaAsset
            }
        }
        if let draftID = activeDraft?.id {
            scheduleMediaProcessing(for: draftID, asset: mediaAsset, importedAssetID: importedAsset.id, store: store)
        }
    }

    func loadDraft(id: UUID) async {
        guard let store = draftStore else { return }
        do {
            if let draft = try await store.loadDraft(id: id) {
                isRestoringDraft = true
                activeDraft = draft
                isRestoringDraft = false
            }
        } catch {
            #if DEBUG
            print("Failed to load draft: \(error.localizedDescription)")
            #endif
            draftPersistenceError = "Unable to load draft."
        }
    }

    func applyDraftMutation(_ update: (inout Draft) -> Void) {
        guard var draft = activeDraft else { return }
        update(&draft)
        draft.updatedAt = .now
        activeDraft = draft
    }

    func deleteDraft(id: UUID) async {
        guard let store = draftStore else { return }
        do {
            try await store.deleteDraft(id: id)
        } catch {
            #if DEBUG
            print("Failed to delete draft: \(error.localizedDescription)")
            #endif
            draftPersistenceError = "Unable to delete draft."
        }
    }

    private func persistDraftSnapshot(_ draft: Draft) {
        guard let store = draftStore else { return }
        Task {
            do {
                try await store.saveSnapshot(draft)
                await MainActor.run {
                    draftPersistenceError = nil
                }
            } catch {
                #if DEBUG
                print("Failed to save draft: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    draftPersistenceError = "Unable to save draft."
                }
            }
        }
    }

    private func scheduleMediaProcessing(for draftID: Draft.ID, asset: MediaAsset, importedAssetID: UUID, store: DemoDataStore) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            
            // Process proxy generation with timeout and fallback
            do {
                let proxyURL = try await self.mediaPipeline.generateProxy(for: asset.uri)
                await self.updateDraftAsset(draftID: draftID, assetID: asset.id) { $0.proxyURL = proxyURL }
                await self.updateImportedAsset(importedAssetID, store: store) { $0.proxyURL = proxyURL }
                print("✅ Proxy generation completed for draft \(draftID)")
            } catch {
                print("❌ Proxy generation failed for draft \(draftID): \(error.localizedDescription)")
                await self.logMediaPipelineError(stage: "proxy", error: error)
                // Set original URL as fallback
                await self.updateDraftAsset(draftID: draftID, assetID: asset.id) { $0.proxyURL = asset.uri }
            }

            // Process thumbnail generation with timeout and fallback
            do {
                let spriteURL = try await self.mediaPipeline.generateThumbnailSprite(for: asset.uri)
                await self.updateDraftAsset(draftID: draftID, assetID: asset.id) { $0.thumbnailSpriteURL = spriteURL }
                await self.updateImportedAsset(importedAssetID, store: store) { $0.thumbnailSpriteURL = spriteURL }
                print("✅ Thumbnail generation completed for draft \(draftID)")
            } catch {
                print("❌ Thumbnail generation failed for draft \(draftID): \(error.localizedDescription)")
                await self.logMediaPipelineError(stage: "thumbnail", error: error)
            }

            // Process waveform generation with timeout and fallback
            do {
                let waveformURL = try await self.mediaPipeline.generateWaveform(for: asset.uri)
                await self.updateDraftAsset(draftID: draftID, assetID: asset.id) { $0.waveformURL = waveformURL }
                await self.updateImportedAsset(importedAssetID, store: store) { $0.waveformURL = waveformURL }
                print("✅ Waveform generation completed for draft \(draftID)")
            } catch {
                print("❌ Waveform generation failed for draft \(draftID): \(error.localizedDescription)")
                await self.logMediaPipelineError(stage: "waveform", error: error)
            }
        }
    }

    private func updateDraftAsset(draftID: Draft.ID, assetID: UUID, mutate: @escaping (inout MediaAsset) -> Void) async {
        await MainActor.run {
            guard self.activeDraft?.id == draftID else { return }
            self.applyDraftMutation { draft in
                guard draft.id == draftID, draft.asset.id == assetID else { return }
                mutate(&draft.asset)
            }
        }
    }

    private func updateImportedAsset(_ assetID: UUID, store: DemoDataStore, mutate: @escaping (inout ImportedMediaAsset) -> Void) async {
        await MainActor.run {
            guard let index = store.importedAssets.firstIndex(where: { $0.id == assetID }) else { return }
            var asset = store.importedAssets[index]
            mutate(&asset)
            store.updateImportedAsset(asset)
        }
    }

    private var defaultFrameRate: Double { 30 } // TODO: derive actual frame rate from imported asset metadata

    private func logMediaPipelineError(stage: String, error: Error) {
        #if DEBUG
        print("[MediaProcessingPipeline] \(stage) stage failed: \(error.localizedDescription)")
        #endif
    }

    func completeOnboarding(with role: ServiceLine, navigation: PendingNavigationAction?) {
        currentUser.role = role
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: Keys.onboardingCompleted)
        UserDefaults.standard.set(role.rawValue, forKey: Keys.preferredServiceLine)
        pendingNavigation = nil
        if let navigation {
            pendingNavigation = navigation
        }
    }

    func resetPendingNavigation() {
        pendingNavigation = nil
    }
}

struct CurrentUser: Identifiable {
    let id = UUID()
    var name: String
    var role: ServiceLine?
    var isAdmin: Bool

    static func demoUser(role: ServiceLine? = .pulmonary) -> CurrentUser {
        CurrentUser(name: "Dr. Demo User", role: role, isAdmin: true)
    }
}
