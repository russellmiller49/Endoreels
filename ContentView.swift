import SwiftUI

enum RootTab: Hashable {
    case feed
    case knowledge
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = DemoDataStore()
    @State private var selectedTab: RootTab = .feed
    @State private var showCreator = false
    @State private var showOnboarding = false
    @State private var feedPath: [UUID] = []
    @State private var selectedReelID: UUID? = nil
    @State private var hasInitializedOnboarding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                feedTab
                knowledgeTab
            }
            createButton
        }
        .environmentObject(store)
        .environmentObject(appState)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showCreator) {
            CreatorView(onClose: { showCreator = false })
                .environmentObject(store)
                .environmentObject(appState)
        }
        .onAppear {
            if !hasInitializedOnboarding {
                hasInitializedOnboarding = true
                showOnboarding = !appState.onboardingCompleted
            }
        }
        .onChange(of: appState.onboardingCompleted) { _, newValue in
            showOnboarding = !newValue
        }
        .onChange(of: appState.pendingNavigation) { _, action in
            guard let action else { return }
            handleNavigation(action)
            appState.resetPendingNavigation()
        }
        .onChange(of: selectedReelID) { _, reelID in
            guard let reelID else { return }
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
            appState.currentUser.role = role
            showCreator = true
        }
    }

    private var feedTab: some View {
        NavigationStack(path: $feedPath) {
            FeedView(selectedReelID: $selectedReelID)
                .navigationDestination(for: UUID.self, destination: destinationForReel)
        }
        .tabItem {
            Label("Feed", systemImage: "play.rectangle.on.rectangle")
        }
        .tag(RootTab.feed)
    }

    private var knowledgeTab: some View {
        NavigationStack {
            KnowledgeHubView()
        }
        .tabItem {
            Label("Knowledge", systemImage: "books.vertical")
        }
        .tag(RootTab.knowledge)
    }

    private func destinationForReel(_ reelID: UUID) -> some View {
        if let reel = store.reels.first(where: { $0.id == reelID }) {
            return AnyView(
                ReelDetailView(reel: reel)
                    .environmentObject(store)
                    .environmentObject(appState)
            )
        } else {
            return AnyView(
                Text("Reel unavailable")
                    .foregroundStyle(.secondary)
            )
        }
    }

    private var createButton: some View {
        Button {
            showCreator = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue, in: Circle())
                .shadow(radius: 8, y: 3)
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(DemoDataStore())
}
