import SwiftUI

enum RootTab: Hashable {
    case feed
    case creator
    case knowledge
    case operations
}

struct ContentView: View {
    @StateObject private var store = DemoDataStore()
    @State private var selectedTab: RootTab = .feed

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
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
    }
}

#Preview {
    ContentView()
}
