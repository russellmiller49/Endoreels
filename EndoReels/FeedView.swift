import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: DemoDataStore
    @State private var selectedSpecialty: String? = nil
    @State private var showingSettings = false

    private var specialties: [String] {
        let values = store.reels.flatMap { [$0.procedure, $0.anatomy, $0.pathology] }
        return Array(Set(values)).sorted()
    }

    private var filteredReels: [Reel] {
        guard let specialty = selectedSpecialty, !specialty.isEmpty else {
            return store.reels
        }
        return store.reels.filter { reel in
            reel.procedure == specialty || reel.anatomy == specialty || reel.pathology == specialty
        }
    }

    var body: some View {
        List {
            if let hero = store.reels.first {
                heroSection(hero)
            }

            Section(header: Text("Latest Reels")) {
                ForEach(filteredReels) { reel in
                    NavigationLink(value: reel.id) {
                        ReelCardView(reel: reel)
                    }
                }
            }
        }
        .navigationTitle("EndoReels Demo")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Demo Setup") {
                    showingSettings = true
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Clear Filter") { selectedSpecialty = nil }
                    Divider()
                    ForEach(specialties, id: \.self) { specialty in
                        Button(specialty) { selectedSpecialty = specialty }
                    }
                } label: {
                    Label("Filter", systemImage: selectedSpecialty == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            DemoSetupSheet()
        }
        .navigationDestination(for: UUID.self) { reelID in
            if let reel = store.reels.first(where: { $0.id == reelID }) {
                ReelDetailView(reel: reel)
            } else {
                Text("Reel unavailable")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func heroSection(_ reel: Reel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Featured Case")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.secondary)

                Text(reel.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(reel.abstract)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label("\(reel.engagement.views) views", systemImage: "play.circle")
                    Label("\(Int(reel.engagement.completionRate * 100))% completion", systemImage: "percent")
                    Label("\(reel.engagement.saves) saves", systemImage: "bookmark")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reel.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                NavigationLink("Open Reel") {
                    ReelDetailView(reel: reel)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical)
        }
    }
}

struct ReelCardView: View {
    let reel: Reel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reel.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(reel.abstract)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            HStack(alignment: .center, spacing: 12) {
                authorBadge
                Divider()
                    .frame(height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reel.procedure)
                    Text(reel.anatomy)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            EngagementRow(engagement: reel.engagement)
        }
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        Text(reel.status.displayName)
            .font(.caption.bold())
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch reel.status {
        case .draft:
            return .gray
        case .review:
            return .orange
        case .published:
            return .green
        }
    }

    private var authorBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reel.author.name)
                .font(.subheadline.weight(.medium))
            Text("\(reel.author.role) • \(reel.author.institution)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct EngagementRow: View {
    let engagement: EngagementSignals

    var body: some View {
        HStack(spacing: 16) {
            Label("\(engagement.views)", systemImage: "eye")
            Label("\(engagement.saves)", systemImage: "bookmark")
            Label("\(engagement.reactions.values.reduce(0, +))", systemImage: "hands.clap")
            Label("\(Int(engagement.completionRate * 100))%", systemImage: "percent")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct DemoSetupSheet: View {
    @State private var enableBetaUI = true
    @State private var useSyntheticAssets = true
    @State private var showCMETracks = true
    @State private var anonymizeAuthors = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feature Flags") {
                    Toggle("Enable beta UI", isOn: $enableBetaUI)
                    Toggle("Show CME surfaces", isOn: $showCMETracks)
                    Toggle("Use synthetic demo assets", isOn: $useSyntheticAssets)
                }
                Section("Privacy Controls") {
                    Toggle("Anonymize author names", isOn: $anonymizeAuthors)
                    Label("Audit logging enforced", systemImage: "lock.shield")
                }
                Section("Environment") {
                    Label("Mode: Local-only demo", systemImage: "desktopcomputer")
                    Label("PHI handling: disabled", systemImage: "nosign")
                }
            }
            .navigationTitle("Demo Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    NavigationStack {
        FeedView()
    }
    .environmentObject(DemoDataStore())
}
