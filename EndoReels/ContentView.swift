import SwiftUI

struct ContentView: View {
    @StateObject private var store = DemoDataStore()

    var body: some View {
        TabView {
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "play.rectangle.on.rectangle")
            }

            NavigationStack {
                CreatorView()
            }
            .tabItem {
                Label("Creator", systemImage: "wand.and.stars")
            }

            NavigationStack {
                KnowledgeHubView()
            }
            .tabItem {
                Label("Knowledge", systemImage: "books.vertical")
            }

            NavigationStack {
                OperationsView()
            }
            .tabItem {
                Label("Ops", systemImage: "checkmark.shield")
            }
        }
        .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
