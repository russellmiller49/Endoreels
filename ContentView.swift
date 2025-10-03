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
    @State private var showLogin = false
    private let loginPublisher = NotificationCenter.default.publisher(for: .requestLoginPresentation)

    var body: some View {
        TabView(selection: $selectedTab) {
            feedTab
            creatorTab
            knowledgeTab
            operationsTab
        }
        .environmentObject(store)
        .environmentObject(appState)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(appState)
        }
        .onAppear {
            if !hasInitializedOnboarding {
                hasInitializedOnboarding = true
                showOnboarding = !appState.onboardingCompleted
                showLogin = appState.authSession == nil
            }
        }
        .onChange(of: appState.onboardingCompleted) { _, newValue in
            showOnboarding = !newValue
        }
        .onChange(of: appState.authSession == nil) { _, isNil in
            showLogin = isNil
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
        .onReceive(loginPublisher) { _ in
            showLogin = true
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

    private var creatorTab: some View {
        NavigationStack {
            CreatorView(onClose: { selectedTab = .feed })
        }
        .tabItem {
            Label("Creator", systemImage: "wand.and.stars")
        }
        .tag(RootTab.creator)
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

    private var operationsTab: some View {
        NavigationStack {
            OperationsView()
        }
        .tabItem {
            Label("Ops", systemImage: "checkmark.shield")
        }
        .tag(RootTab.operations)
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
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(DemoDataStore())
}
