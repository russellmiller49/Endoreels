import SwiftUI

struct KnowledgeHubView: View {
    @EnvironmentObject private var store: DemoDataStore
    @State private var searchText: String = ""
    @State private var selectedFacet: String? = nil

    private var tags: [String] {
        Array(Set(store.reels.flatMap { $0.tags + [$0.procedure, $0.anatomy, $0.pathology] })).sorted()
    }

    private var searchResults: [Reel] {
        guard !searchText.isEmpty else { return store.reels }
        return store.reels.filter { reel in
            [reel.title, reel.abstract, reel.procedure, reel.anatomy, reel.pathology]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredResults: [Reel] {
        guard let facet = selectedFacet else { return searchResults }
        return searchResults.filter { reel in
            reel.tags.contains(facet) || reel.procedure == facet || reel.anatomy == facet || reel.pathology == facet
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Discover cases by specialty, anatomy, and curated collections.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    facetScroller
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Featured Collections")) {
                ForEach(store.collections) { collection in
                    NavigationLink(destination: CollectionDetailView(collection: collection)) {
                        CollectionCard(collection: collection)
                    }
                }
            }

            Section(header: resultHeader) {
                ForEach(filteredResults) { reel in
                    NavigationLink(destination: ReelDetailView(reel: reel)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reel.title)
                                .font(.headline)
                            Text(reel.abstract)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                Label(reel.procedure, systemImage: "scalpel")
                                Label(reel.anatomy, systemImage: "lungs")
                                Label(reel.difficulty, systemImage: "chart.line.uptrend.xyaxis")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Knowledge Hub")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    selectedFacet = nil
                    searchText = ""
                }
            }
        }
    }

    private var resultHeader: some View {
        HStack {
            Text(selectedFacet.map { "Aligned to \($0)" } ?? "All Reels")
            Spacer()
            Text("\(filteredResults.count) items")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var facetScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFacet = nil
                } label: {
                    Text("All")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(selectedFacet == nil ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }

                ForEach(tags, id: \.self) { tag in
                    Button {
                        selectedFacet = tag
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(selectedFacet == tag ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct CollectionCard: View {
    let collection: KnowledgeCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(collection.title)
                    .font(.headline)
                Spacer()
            }
            Text(collection.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(collection.reels.count) reels • Specialty: \(collection.specialty)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let endorser = collection.endorsedBy {
                Label("Endorsed by \(endorser)", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CollectionDetailView: View {
    let collection: KnowledgeCollection

    var body: some View {
        List {
            Section("Overview") {
                Text(collection.description)
            }
            Section("Reels") {
                ForEach(collection.reels) { reel in
                    NavigationLink(destination: ReelDetailView(reel: reel)) {
                        Text(reel.title)
                    }
                }
            }
        }
        .navigationTitle(collection.title)
    }
}

#Preview {
    NavigationStack {
        KnowledgeHubView()
    }
    .environmentObject(DemoDataStore())
}
