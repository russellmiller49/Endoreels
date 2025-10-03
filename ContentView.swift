import SwiftUI

enum RootTab: Hashable {
    case feed
    case creator
    case knowledge
    case operations
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = DemoDataStore()
    @State private var selectedTab: RootTab = .feed
    @State private var showOnboarding = false
    @State private var feedPath: [UUID] = []
    @State private var selectedReelID: UUID? = nil
    @State private var hasInitializedOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $feedPath) {
                FeedView(selectedReelID: $selectedReelID)
                    .navigationDestination(for: UUID.self) { reelID in
                        if let reel = store.reels.first(where: { $0.id == reelID }) {
                            ReelDetailView(reel: reel)
                                .environmentObject(store)
                                .environmentObject(appState)
                        } else {
                            Text("Reel unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "play.rectangle.on.rectangle")
            }
            .tag(RootTab.feed)

            NavigationStack {
                CreatorView(onClose: { selectedTab = .feed })
            }
            .tabItem {
                Label("Creator", systemImage: "wand.and.stars")
            }
            .tag(RootTab.creator)

            NavigationStack {
                KnowledgeHubView()
            }
            .tabItem {
                Label("Knowledge", systemImage: "books.vertical")
            }
            .tag(RootTab.knowledge)

            NavigationStack {
                OperationsView()
            }
            .tabItem {
                Label("Ops", systemImage: "checkmark.shield")
            }
            .tag(RootTab.operations)
        }
        .environmentObject(store)
        .environmentObject(appState)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
        .onAppear {
            if !hasInitializedOnboarding {
                hasInitializedOnboarding = true
                showOnboarding = !appState.onboardingCompleted
            }
        }
        .onChange(of: appState.onboardingCompleted) { oldValue, newValue in
            if newValue {
                showOnboarding = false
            } else {
                showOnboarding = true
            }
        }
        .onChange(of: appState.pendingNavigation) { oldValue, newValue in
            guard let action = newValue else { return }
            handleNavigation(action)
            appState.resetPendingNavigation()
        }
        .onChange(of: selectedReelID) { oldValue, newValue in
            guard let reelID = newValue else { return }
            feedPath = [reelID]
            Task { @MainActor in
                // Reset after navigation so future requests trigger again
                try? await Task.sleep(nanoseconds: 10_000_000)
                selectedReelID = nil
            }
        }
    }

    private func handleNavigation(_ action: AppState.PendingNavigationAction) {
        switch action {
        case .openSampleCase:
            let preferredRole = appState.currentUser.role
            let reel = store.reels.first(where: { preferredRole == nil || $0.serviceLine == preferredRole }) ?? store.reels.first
            if let reel {
                selectedTab = .feed
                selectedReelID = reel.id
            }
        case .openCreator(let role):
            selectedTab = .creator
            appState.currentUser.role = role
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(DemoDataStore())
}
